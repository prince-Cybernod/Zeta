/**
 * Controller for the Run Lottery LWC.
 *
 * Security model: Uses `with sharing` for row-level access control with
 * `SystemModeDatabaseRepo` for field-level reads/writes. This is intentional
 * because the lottery UI is admin-only and requires accessing records
 * that may have restrictive FLS for regular users.
 *
 * Provides methods to:
 * - Retrieve available lottery capacities (unrun)
 * - Execute the lottery for selected capacities
 * - Publish lottery results
 */
public with sharing class RunLotteryController {
  @TestVisible
  private static LotteryOrchestrationService orchestrationService = new LotteryOrchestrationServiceImpl();
  @TestVisible
  private static LotteryAuditLogService auditLogService = new LotteryAuditLogServiceImpl();
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @TestVisible
  private static LotteryLockService lockService = new LotteryLockServiceImpl();

  /**
   * Gets pre-run statistics for selected capacities, including application counts.
   * Used in the confirmation modal before running the lottery.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to get stats for
   * @param startDate Optional start date filter for applied date (Application_Submitted_Date__c)
   * @param endDate Optional end date filter for applied date (Application_Submitted_Date__c)
   */
  @AuraEnabled
  public static List<CapacityStats> getCapacityStats(
    List<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return new List<CapacityStats>();
    }

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);

    // Query capacity details
    String capacityQuery =
      'SELECT Id, Grade__c, Total_Available_Seats__c, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Zeta_School_Name__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds';

    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      capacityQuery,
      new Map<String, Object>{ 'capacityIds' => capacityIdSet }
    );

    // Build application count query with date filters
    String countQuery =
      'SELECT Lottery_Capacity__c, COUNT(Id) cnt ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds ' +
      'AND Status = :eligibleStatus';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIdSet,
      'eligibleStatus' => LotteryConstants.STATUS_ELIGIBLE
    };

    if (startDate != null) {
      countQuery += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      countQuery += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    countQuery += ' GROUP BY Lottery_Capacity__c';

    List<AggregateResult> countResults = (List<AggregateResult>) databaseRepo.queryWithBinds(
      countQuery,
      binds
    );

    // Map counts by capacity ID
    Map<Id, Integer> countByCapacity = new Map<Id, Integer>();
    for (AggregateResult ar : countResults) {
      Id capId = (Id) ar.get('Lottery_Capacity__c');
      Integer count = (Integer) ar.get('cnt');
      countByCapacity.put(capId, count);
    }

    // Build result list - only include capacities with applications
    List<CapacityStats> statsList = new List<CapacityStats>();
    for (Lottery_Capacity__c cap : capacities) {
      // Skip capacities with no eligible applications
      if (!countByCapacity.containsKey(cap.Id)) {
        continue;
      }

      CapacityStats stats = new CapacityStats();
      stats.capacityId = cap.Id;
      stats.schoolName = cap.Program_Term_Application_Timeline__r
        ?.LearningProgram
        ?.School__r
        ?.Zeta_School_Name__c;
      stats.grade = cap.Grade__c;
      stats.availableSeats = cap.Total_Available_Seats__c != null
        ? cap.Total_Available_Seats__c.intValue()
        : 0;
      stats.applicationCount = countByCapacity.get(cap.Id);
      statsList.add(stats);
    }

    // Sort by school name, then grade
    statsList.sort(new CapacityStatsComparator());

    return statsList;
  }

  /**
   * Gets lottery capacities that haven't been run yet for the given timeline.
   */
  @AuraEnabled(Cacheable=true)
  public static List<Lottery_Capacity__c> getUnrunCapacities(Id applicationTimelineId) {
    if (String.isBlank(applicationTimelineId)) {
      return new List<Lottery_Capacity__c>();
    }

    String query =
      'SELECT Id, Name, Grade__c, Total_Available_Seats__c, Remaining_Available_Seats__c, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__c, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Name, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Zeta_School_Name__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Program_Term_Application_Timeline__r.ApplicationTimelineId = :applicationTimelineId ' +
      'AND Lottery_Run_Log__c = null ' +
      'ORDER BY Program_Term_Application_Timeline__r.LearningProgram.School__r.Name ASC, Grade__c ASC';

    return (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationTimelineId' => applicationTimelineId }
    );
  }

  /**
   * Executes the lottery for the selected capacities.
   * Returns the run result including the run log ID for publishing.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param applicationTimelineId The ApplicationTimeline context
   * @param startDate Optional start date filter for applied date (Application_Submitted_Date__c)
   * @param endDate Optional end date filter for applied date (Application_Submitted_Date__c)
   */
  @AuraEnabled
  public static LotteryRunResponse runLottery(
    List<Id> capacityIds,
    Id applicationTimelineId,
    Date startDate,
    Date endDate
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(applicationTimelineId, 'Application Timeline ID is required');

    try {
      Set<Id> capacityIdSet = new Set<Id>(capacityIds);

      // Lock capacities with FOR UPDATE to prevent race conditions
      List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
        'SELECT Id, Name, Lottery_Run_Log__c FROM Lottery_Capacity__c WHERE Id IN :capacityIds FOR UPDATE',
        new Map<String, Object>{ 'capacityIds' => capacityIdSet }
      );

      List<String> alreadyRunNames = new List<String>();
      for (Lottery_Capacity__c cap : capacities) {
        if (cap.Lottery_Run_Log__c != null) {
          alreadyRunNames.add(cap.Name);
        }
      }
      if (!alreadyRunNames.isEmpty()) {
        throw new RunLotteryException(
          'The following capacities have already been run: ' +
            String.join(alreadyRunNames, ', ') +
            '. Please refresh the page to see updated data.'
        );
      }

      Id runLogId = auditLogService.createLotteryRunLog(applicationTimelineId);

      // Link capacities to run BEFORE lottery execution so Has_Lottery_Run__c = TRUE
      // when status updates occur (required by Status_Progression_Lottery_Validation)
      auditLogService.linkCapacitiesToRun(runLogId, capacityIdSet);

      LotteryRunResult lotteryResult = orchestrationService.runLottery(
        capacityIdSet,
        startDate,
        endDate
      );

      if (!lotteryResult.isSuccess) {
        throw new RunLotteryException('Lottery execution failed: ' + lotteryResult.errorMessage);
      }

      Integer resultCount = auditLogService.createLotteryRunResults(runLogId, lotteryResult);
      List<AcademicInterest> processedRecords = getProcessedRecords(capacityIdSet);
      List<AcademicInterest> offeredRecords = filterOfferedRecords(processedRecords);

      Lottery_Run_Log__c runLog = (Lottery_Run_Log__c) databaseRepo.queryWithBinds(
        'SELECT Id, Name FROM Lottery_Run_Log__c WHERE Id = :runLogId LIMIT 1',
        new Map<String, Object>{ 'runLogId' => runLogId }
      )[0];

      LotteryRunResponse response = new LotteryRunResponse();
      response.runLogId = runLogId;
      response.runLogName = runLog.Name;
      response.totalEligible = lotteryResult.totalEligible;
      response.preOffersAssigned = lotteryResult.preOffersAssigned;
      response.offersRescinded = lotteryResult.offersRescinded;
      response.waitlisted = lotteryResult.waitlisted;
      response.results = buildResultRows(offeredRecords);
      response.allResults = buildResultRows(processedRecords);

      return response;
    } catch (RunLotteryException e) {
      throw e;
    } catch (Exception e) {
      throw new RunLotteryException('Error running lottery: ' + e.getMessage());
    }
  }

  /**
   * Publishes (finalizes) the lottery run.
   */
  @AuraEnabled
  public static void publishLotteryRun(Id runLogId) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    auditLogService.publishLotteryRun(runLogId);
  }

  /**
   * Rolls back an unpublished lottery run, resetting all affected records.
   */
  @AuraEnabled
  public static LotteryRollbackResponse rollbackLotteryRun(Id runLogId) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');

    try {
      LotteryRollbackResult result = auditLogService.rollbackLotteryRun(runLogId);

      LotteryRollbackResponse response = new LotteryRollbackResponse();
      response.success = true;
      response.message = 'Lottery run rolled back successfully';
      response.recordsReset = result.getTotalRecordsAffected();
      return response;
    } catch (IllegalArgumentException e) {
      LotteryRollbackResponse response = new LotteryRollbackResponse();
      response.success = false;
      response.message = e.getMessage();
      response.recordsReset = 0;
      return response;
    } catch (Exception e) {
      throw new RunLotteryException('Error rolling back lottery: ' + e.getMessage());
    }
  }

  /**
   * Gets lottery results for display after sequential execution completes.
   * Queries processed records and builds result rows for the UI.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs that were processed
   * @return LotteryResultsResponse with results and allResults for display
   */
  @AuraEnabled
  public static LotteryResultsResponse getResults(List<Id> capacityIds) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be provided'
    );

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    List<AcademicInterest> processedRecords = getProcessedRecords(capacityIdSet);
    List<AcademicInterest> offeredRecords = filterOfferedRecords(processedRecords);

    LotteryResultsResponse response = new LotteryResultsResponse();
    response.results = buildResultRows(offeredRecords);
    response.allResults = buildResultRows(processedRecords);
    response.totalEligible = processedRecords.size();
    return response;
  }

  /**
   * Creates Lottery_Run_Result__c audit records from the final state of processed records.
   * Used by sequential execution flow after getResults().
   *
   * @param runLogId The Lottery_Run_Log__c ID
   * @param capacityIds List of Lottery_Capacity__c IDs that were processed
   * @return Number of audit records created
   */
  @AuraEnabled
  public static Integer createAuditRecords(Id runLogId, List<Id> capacityIds) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be provided'
    );

    return auditLogService.createAuditRecords(runLogId, new Set<Id>(capacityIds));
  }

  /**
   * Batched version of createAuditRecords using keyset pagination.
   * Creates audit records in chunks to avoid DML limits with large datasets.
   *
   * @param runLogId The Lottery_Run_Log__c ID
   * @param capacityIds List of Lottery_Capacity__c IDs that were processed
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return CreateAuditBatchResult with recordsCreated, cursor, and hasMore flag
   */
  @AuraEnabled
  public static CreateAuditBatchResult createAuditRecordsBatch(
    Id runLogId,
    List<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize,
    Integer startLotteryNumber
  ) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be provided'
    );
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    return auditLogService.createAuditRecordsBatch(
      runLogId,
      new Set<Id>(capacityIds),
      lastRecordId,
      batchSize,
      startLotteryNumber
    );
  }

  /**
   * Releases lock on lottery capacity records.
   * Used for error recovery when the LWC needs to clean up after a failed step.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to unlock
   * @param jobId The job ID that holds the lock
   */
  @AuraEnabled
  public static void releaseLotteryLock(List<Id> capacityIds, String jobId) {
    if (capacityIds == null || capacityIds.isEmpty() || String.isBlank(jobId)) {
      return; // Silently return - nothing to release
    }
    lockService.releaseLock(new Set<Id>(capacityIds), jobId);
  }

  /**
   * Step 1 of sequential lottery execution.
   * Acquires lock on capacities and creates the run log.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param applicationTimelineId The ApplicationTimeline context
   * @return Result containing jobId, runLogId, and runLogName
   */
  @AuraEnabled
  public static InitializeLotteryResult initializeLottery(
    List<Id> capacityIds,
    Id applicationTimelineId
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(applicationTimelineId, 'Application Timeline ID is required');

    InitializeLotteryResult result = new InitializeLotteryResult();
    try {
      Set<Id> capacityIdSet = new Set<Id>(capacityIds);
      result.jobId = lockService.acquireLock(capacityIdSet);
      result.runLogId = auditLogService.createLotteryRunLog(applicationTimelineId);

      // Sets Has_Lottery_Run__c = true, required by Status_Progression_Lottery_Validation
      auditLogService.linkCapacitiesToRun(result.runLogId, capacityIdSet);

      Lottery_Run_Log__c runLog = (Lottery_Run_Log__c) databaseRepo.queryWithBinds(
        'SELECT Id, Name FROM Lottery_Run_Log__c WHERE Id = :runLogId LIMIT 1',
        new Map<String, Object>{ 'runLogId' => result.runLogId }
      )[0];
      result.runLogName = runLog.Name;

      return result;
    } catch (LotteryLockException e) {
      result.isSuccess = false;
      result.errorMessage = 'Lock acquisition failed: ' + e.getMessage();
      return result;
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = 'Initialization failed: ' + e.getMessage();
      return result;
    }
  }

  /**
   * Step 2 of sequential lottery execution.
   * Assigns randomized sort keys to eligible applications.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID (for context)
   * @param jobId The job ID that holds the lock
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @return Count of applications that received sort keys
   */
  @AuraEnabled
  public static Integer randomizeApplications(
    List<Id> capacityIds,
    Id runLogId,
    String jobId,
    Date startDate,
    Date endDate
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(jobId, 'Job ID is required');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);

    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.randomizeApplications(capacityIdSet, startDate, endDate);
  }

  /**
   * Step 3 of sequential lottery execution.
   * Makes pre-offers to students within capacity.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID (for context)
   * @param jobId The job ID that holds the lock
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @return Result containing count of PRE_OFFER assignments
   */
  @AuraEnabled
  public static AssignPreOffersResult assignPreOffers(
    List<Id> capacityIds,
    Id runLogId,
    String jobId,
    Date startDate,
    Date endDate
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(jobId, 'Job ID is required');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);

    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.assignPreOffers(capacityIdSet, startDate, endDate);
  }

  /**
   * Step 4 of sequential lottery execution.
   * Optimizes offers by rescinding duplicates (one offer per student).
   *
   * @param runLogId The Lottery_Run_Log__c ID for this run
   * @param jobId The job ID that holds the lock
   * @param capacityIds List of Lottery_Capacity__c IDs (for lock verification)
   * @return Result containing count of rescinded offers
   */
  @AuraEnabled
  public static OptimizeOffersResult optimizeOffers(
    Id runLogId,
    String jobId,
    List<Id> capacityIds
  ) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkNotNull(jobId, 'Job ID is required');
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);

    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.optimizeOffers(runLogId);
  }

  /**
   * Step 5 of sequential lottery execution.
   * Transitions remaining eligible to waitlist, publishes events, and releases lock.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID for this run
   * @param jobId The job ID that holds the lock
   * @return Result containing waitlist count and event publication status
   */
  @AuraEnabled
  public static FinalizeResult finalizeLottery(List<Id> capacityIds, Id runLogId, String jobId) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkNotNull(jobId, 'Job ID is required');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    FinalizeResult result = new FinalizeResult();

    try {
      lockService.verifyLock(capacityIdSet, jobId);
      result = orchestrationService.finalizeLottery(capacityIdSet, runLogId);
      lockService.releaseLock(capacityIdSet, jobId);

      return result;
    } catch (LotteryLockException e) {
      result.isSuccess = false;
      result.errorMessage = 'Lock verification failed: ' + e.getMessage();
      return result;
    } catch (Exception e) {
      try {
        lockService.releaseLock(capacityIdSet, jobId);
      } catch (Exception lockEx) {
        // Don't mask original error
      }
      result.isSuccess = false;
      result.errorMessage = 'Finalization failed: ' + e.getMessage();
      return result;
    }
  }

  // ==================== Batched Methods (for large datasets) ====================

  /**
   * Batched version of randomizeApplications using keyset pagination.
   * Processes a batch of records and returns cursor for next batch.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID (for context)
   * @param jobId The job ID that holds the lock
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with processedCount, lastRecordId cursor, and hasMore flag
   */
  @AuraEnabled
  public static RandomizeBatchResult randomizeApplicationsBatch(
    List<Id> capacityIds,
    Id runLogId,
    String jobId,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(jobId, 'Job ID is required');
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.randomizeApplicationsBatch(
      capacityIdSet,
      startDate,
      endDate,
      lastRecordId,
      batchSize
    );
  }

  /**
   * Batched version of assignPreOffers using keyset pagination.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID (for context)
   * @param jobId The job ID that holds the lock
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with preOfferCount, lastRecordId cursor, and hasMore flag
   */
  @AuraEnabled
  public static AssignPreOffersResult assignPreOffersBatch(
    List<Id> capacityIds,
    Id runLogId,
    String jobId,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(jobId, 'Job ID is required');
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.assignPreOffersBatch(
      capacityIdSet,
      startDate,
      endDate,
      lastRecordId,
      batchSize
    );
  }

  /**
   * Batched version of optimizeOffers using keyset pagination.
   *
   * @param runLogId The Lottery_Run_Log__c ID for this run
   * @param jobId The job ID that holds the lock
   * @param capacityIds List of Lottery_Capacity__c IDs (for lock verification)
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with rescindedCount, lastRecordId cursor, and hasMore flag
   */
  @AuraEnabled
  public static OptimizeOffersResult optimizeOffersBatch(
    Id runLogId,
    String jobId,
    List<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  ) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkNotNull(jobId, 'Job ID is required');
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.optimizeOffersBatch(runLogId, lastRecordId, batchSize);
  }

  /**
   * Batched version of finalizeLottery using keyset pagination.
   * Does NOT release lock - caller should release after all batches complete.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to process
   * @param runLogId The Lottery_Run_Log__c ID for this run
   * @param jobId The job ID that holds the lock
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with waitlistCount, lastRecordId cursor, and hasMore flag
   */
  @AuraEnabled
  public static FinalizeResult finalizeLotteryBatch(
    List<Id> capacityIds,
    Id runLogId,
    String jobId,
    Id lastRecordId,
    Integer batchSize
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be selected'
    );
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');
    Preconditions.checkNotNull(jobId, 'Job ID is required');
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    lockService.verifyLock(capacityIdSet, jobId);

    return orchestrationService.finalizeLotteryBatch(
      capacityIdSet,
      runLogId,
      lastRecordId,
      batchSize
    );
  }

  // ==================== Batched Rollback Methods ====================

  /**
   * Prepares a rollback by unlinking capacities and deleting audit records.
   * Returns capacityIds for the batched AcademicInterest reset phase.
   *
   * @param runLogId The Lottery_Run_Log__c to rollback
   * @return RollbackPrepareResult with capacityIds for batched reset
   */
  @AuraEnabled
  public static RollbackPrepareResult prepareRollback(Id runLogId) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');

    try {
      return auditLogService.prepareRollback(runLogId);
    } catch (IllegalArgumentException e) {
      RollbackPrepareResult result = new RollbackPrepareResult();
      result.isSuccess = false;
      result.errorMessage = e.getMessage();
      return result;
    } catch (Exception e) {
      throw new RunLotteryException('Error preparing rollback: ' + e.getMessage());
    }
  }

  /**
   * Batched version of AcademicInterest reset using keyset pagination.
   *
   * @param capacityIds List of Lottery_Capacity__c IDs to filter records
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return RollbackBatchResult with resetCount, cursor, and hasMore flag
   */
  @AuraEnabled
  public static RollbackBatchResult rollbackAcademicInterestsBatch(
    List<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  ) {
    Preconditions.checkArgument(
      capacityIds != null && !capacityIds.isEmpty(),
      'At least one capacity must be provided'
    );
    Preconditions.checkArgument(batchSize != null && batchSize > 0, 'Batch size must be positive');

    return auditLogService.rollbackAcademicInterestsBatch(
      new Set<Id>(capacityIds),
      lastRecordId,
      batchSize
    );
  }

  private static List<AcademicInterest> getProcessedRecords(Set<Id> capacityIds) {
    Set<String> trackableStatuses = new Set<String>{
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.STATUS_WAITLISTED,
      LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
    };

    String query =
      'SELECT Id, Name, IndividualApplicationId, IndividualApplication.Name, ' +
      'Randomized_Sort_Key__c, Current_Priority_Group__c, Status, School_Rank__c, ' +
      'Lottery_Capacity__r.Grade__c, Lottery_Capacity__r.Remaining_Available_Seats__c, ' +
      'Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__c, ' +
      'Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__r.Zeta_School_Name__c ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds ' +
      'AND Status IN :statuses ' +
      'ORDER BY Current_Priority_Group__c ASC, Randomized_Sort_Key__c ASC';

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds, 'statuses' => trackableStatuses }
    );
  }

  private static List<AcademicInterest> filterOfferedRecords(List<AcademicInterest> records) {
    List<AcademicInterest> offered = new List<AcademicInterest>();
    for (AcademicInterest record : records) {
      if (record.Status == LotteryConstants.STATUS_PRE_OFFER) {
        offered.add(record);
      }
    }
    return offered;
  }

  private static List<ResultRow> buildResultRows(List<AcademicInterest> records) {
    List<ResultRow> rows = new List<ResultRow>();
    Integer lotteryNumber = 1;
    for (AcademicInterest record : records) {
      ResultRow row = new ResultRow();
      row.id = record.Id;
      row.applicationName = record.IndividualApplication?.Name;
      row.lotteryNumber = lotteryNumber++;
      row.priorityGroup = record.Current_Priority_Group__c != null
        ? record.Current_Priority_Group__c.intValue()
        : null;
      row.randomizedKey = record.Randomized_Sort_Key__c;
      row.schoolId = record.Lottery_Capacity__r
        ?.Program_Term_Application_Timeline__r
        ?.LearningProgram
        ?.School__c;
      row.schoolName = record.Lottery_Capacity__r
        ?.Program_Term_Application_Timeline__r
        ?.LearningProgram
        ?.School__r
        ?.Zeta_School_Name__c;
      row.grade = record.Lottery_Capacity__r?.Grade__c;
      row.status = record.Status;
      row.seatsAvailable = record.Lottery_Capacity__r?.Remaining_Available_Seats__c;
      rows.add(row);
    }
    return rows;
  }

  /**
   * Response wrapper for getResults() - lottery results for display.
   */
  public class LotteryResultsResponse {
    @AuraEnabled
    public List<ResultRow> results { get; set; }
    @AuraEnabled
    public List<ResultRow> allResults { get; set; }
    @AuraEnabled
    public Integer totalEligible { get; set; }
  }

  /**
   * Response wrapper for lottery run results.
   */
  public class LotteryRunResponse {
    @AuraEnabled
    public Id runLogId { get; set; }
    @AuraEnabled
    public String runLogName { get; set; }
    @AuraEnabled
    public Integer totalEligible = 0;
    @AuraEnabled
    public Integer preOffersAssigned = 0;
    @AuraEnabled
    public Integer offersRescinded = 0;
    @AuraEnabled
    public Integer waitlisted = 0;
    @AuraEnabled
    public List<ResultRow> results = new List<ResultRow>();
    @AuraEnabled
    public List<ResultRow> allResults = new List<ResultRow>();
  }

  /**
   * Individual result row for display.
   */
  public class ResultRow {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String applicationName { get; set; }
    @AuraEnabled
    public Integer lotteryNumber { get; set; }
    @AuraEnabled
    public Integer priorityGroup { get; set; }
    @AuraEnabled
    public Decimal randomizedKey { get; set; }
    @AuraEnabled
    public String schoolName { get; set; }
    @AuraEnabled
    public Id schoolId { get; set; }
    @AuraEnabled
    public String grade { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Decimal seatsAvailable { get; set; }
  }

  /**
   * Response wrapper for lottery rollback.
   */
  public class LotteryRollbackResponse {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public Integer recordsReset { get; set; }
  }

  /**
   * Pre-run statistics for a capacity.
   */
  public class CapacityStats {
    @AuraEnabled
    public Id capacityId { get; set; }
    @AuraEnabled
    public String schoolName { get; set; }
    @AuraEnabled
    public String grade { get; set; }
    @AuraEnabled
    public Integer availableSeats { get; set; }
    @AuraEnabled
    public Integer applicationCount { get; set; }
  }

  /**
   * Comparator for sorting CapacityStats by school name, then grade.
   * Grade order: PreK/Pre-K < K < numeric grades (1, 2, 3...)
   */
  private class CapacityStatsComparator implements Comparator<CapacityStats> {
    public Integer compare(CapacityStats a, CapacityStats b) {
      // Compare school names first
      String schoolA = a.schoolName != null ? a.schoolName : '';
      String schoolB = b.schoolName != null ? b.schoolName : '';
      Integer schoolCompare = schoolA.compareTo(schoolB);
      if (schoolCompare != 0) {
        return schoolCompare;
      }

      // Then compare grades
      return getGradeOrder(a.grade) - getGradeOrder(b.grade);
    }

    private Integer getGradeOrder(String grade) {
      if (grade == null) {
        return 999;
      }
      if (grade == 'PreK' || grade == 'Pre-K') {
        return -1;
      }
      if (grade == 'K') {
        return 0;
      }
      try {
        return Integer.valueOf(grade);
      } catch (Exception e) {
        return 999;
      }
    }
  }
}