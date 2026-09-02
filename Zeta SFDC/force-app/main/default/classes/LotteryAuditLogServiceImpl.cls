/**
 * Implementation of {@link LotteryAuditLogService}.
 *
 * Security model: Uses `with sharing` for row-level access control with
 * `SystemModeDatabaseRepo` for field-level writes. This is intentional because
 * audit log creation is admin-only and requires creating/updating custom objects
 * that may have restrictive FLS for regular users.
 *
 * Manages audit logging for lottery runs including:
 * - Creating run log records
 * - Recording results for each offer
 * - Linking capacities to runs
 * - Publishing runs
 */
public with sharing class LotteryAuditLogServiceImpl implements LotteryAuditLogService {
  private final DatabaseRepo databaseRepo;

  public LotteryAuditLogServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryAuditLogServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public Id createLotteryRunLog(Id applicationTimelineId) {
    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Application_Timeline__c = applicationTimelineId,
      Lottery_Run_Date__c = Datetime.now(),
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT
    );
    databaseRepo.insertSObjects(new List<Lottery_Run_Log__c>{ runLog });
    return runLog.Id;
  }

  public Integer createLotteryRunResults(Id runLogId, LotteryRunResult result) {
    if (result == null || result.transitions == null || result.transitions.isEmpty()) {
      return 0;
    }

    List<Lottery_Run_Result__c> records = new List<Lottery_Run_Result__c>();
    Set<Id> recordsWithLotteryNumber = new Set<Id>();
    Integer lotteryNumber = 1;

    for (LotteryStatusChange transition : result.transitions) {
      Lottery_Run_Result__c record = new Lottery_Run_Result__c(
        Lottery_Run__c = runLogId,
        School_Application__c = transition.recordId,
        Previous_Status__c = mapStatusForAuditLog(transition.fromStatus),
        Status__c = mapStatusForAuditLog(transition.toStatus),
        Transition_Timestamp__c = transition.timestamp,
        Priority_Group__c = transition.priorityGroup != null
          ? String.valueOf(transition.priorityGroup.intValue())
          : null
      );

      // Assign lottery number only on FIRST Pre-Offer transition per record
      if (
        transition.toStatus == LotteryConstants.STATUS_PRE_OFFER &&
        !recordsWithLotteryNumber.contains(transition.recordId)
      ) {
        record.Lottery_Number__c = lotteryNumber++;
        recordsWithLotteryNumber.add(transition.recordId);
      }

      records.add(record);
    }

    if (!records.isEmpty()) {
      databaseRepo.insertSObjects(records);
    }

    return records.size();
  }

  public void linkCapacitiesToRun(Id runLogId, Set<Id> capacityIds) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return;
    }

    String query = 'SELECT Id, Lottery_Run_Log__c FROM Lottery_Capacity__c WHERE Id IN :capacityIds';
    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );

    for (Lottery_Capacity__c capacity : capacities) {
      capacity.Lottery_Run_Log__c = runLogId;
    }

    if (!capacities.isEmpty()) {
      databaseRepo.updateSObjects(capacities);
    }
  }

  public void publishLotteryRun(Id runLogId) {
    if (runLogId == null) {
      return;
    }

    String query = 'SELECT Id, Status__c, Lottery_Publish_Date__c FROM Lottery_Run_Log__c WHERE Id = :runLogId';
    List<Lottery_Run_Log__c> runLogs = (List<Lottery_Run_Log__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );

    Preconditions.checkArgument(
      runLogs.size() == 1,
      'Expected exactly 1 Lottery_Run_Log__c record for Id ' +
        runLogId +
        '. Found ' +
        runLogs.size() +
        '.'
    );

    Datetime publishTime = Datetime.now();
    Date expirationDate = Date.today().addDays(LotteryConstants.OFFER_EXPIRATION_DAYS);

    Lottery_Run_Log__c runLog = runLogs[0];
    runLog.Status__c = LotteryConstants.LOTTERY_RUN_STATUS_PUBLISHED;
    runLog.Lottery_Publish_Date__c = publishTime;
    databaseRepo.updateSObjects(runLogs);

    System.enqueueJob(
      new LotteryPublishStampOffersQueueable(runLogId, publishTime, expirationDate)
    );
  }

  public LotteryRollbackResult rollbackLotteryRun(Id runLogId) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');

    String runLogQuery = 'SELECT Id, Status__c, Application_Timeline__c FROM Lottery_Run_Log__c WHERE Id = :runLogId';
    List<Lottery_Run_Log__c> runLogs = (List<Lottery_Run_Log__c>) databaseRepo.queryWithBinds(
      runLogQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );

    Preconditions.checkArgument(!runLogs.isEmpty(), 'Lottery Run Log not found');

    // Query ApplicationTimeline to check Test__c (defense in depth - LWC also validates)
    Id timelineId = runLogs[0].Application_Timeline__c;
    String timelineQuery = 'SELECT Id, Test__c FROM ApplicationTimeline WHERE Id = :timelineId';
    List<ApplicationTimeline> timelines = (List<ApplicationTimeline>) databaseRepo.queryWithBinds(
      timelineQuery,
      new Map<String, Object>{ 'timelineId' => timelineId }
    );
    Preconditions.checkArgument(
      !timelines.isEmpty() && timelines[0].Test__c == true,
      'Rollback is only available for test lottery runs'
    );
    Preconditions.checkArgument(
      runLogs[0].Status__c == LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      'Cannot rollback a published lottery run'
    );

    LotteryRollbackResult result = new LotteryRollbackResult();

    String capacityQuery = 'SELECT Id FROM Lottery_Capacity__c WHERE Lottery_Run_Log__c = :runLogId';
    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      capacityQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    Set<Id> capacityIds = new Set<Id>();
    for (Lottery_Capacity__c cap : capacities) {
      cap.Lottery_Run_Log__c = null;
      capacityIds.add(cap.Id);
    }
    if (!capacities.isEmpty()) {
      databaseRepo.updateSObjects(capacities);
      result.capacitiesUnlinked = capacities.size();
    }

    if (!capacityIds.isEmpty()) {
      Set<String> statusesToReset = new Set<String>{
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_WAITLISTED,
        LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
      };
      String aiQuery =
        'SELECT Id, Status, Randomized_Sort_Key__c, Waitlist_Position__c ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capacityIds ' +
        'AND Status IN :statusesToReset';
      List<AcademicInterest> academicInterests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
        aiQuery,
        new Map<String, Object>{
          'capacityIds' => capacityIds,
          'statusesToReset' => statusesToReset
        }
      );
      for (AcademicInterest ai : academicInterests) {
        ai.Status = LotteryConstants.STATUS_ELIGIBLE;
        ai.Randomized_Sort_Key__c = null;
        ai.Waitlist_Position__c = null;
      }
      if (!academicInterests.isEmpty()) {
        databaseRepo.updateSObjects(academicInterests);
        result.academicInterestsReset = academicInterests.size();
      }
    }

    String historyQuery = 'SELECT Id FROM Waitlist_Movement_History__c WHERE Lottery_Run_Log__c = :runLogId';
    List<Waitlist_Movement_History__c> histories = (List<Waitlist_Movement_History__c>) databaseRepo.queryWithBinds(
      historyQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    if (!histories.isEmpty()) {
      databaseRepo.deleteSObjects(histories);
      result.waitlistHistoryDeleted = histories.size();
    }

    String resultQuery = 'SELECT Id FROM Lottery_Run_Result__c WHERE Lottery_Run__c = :runLogId';
    List<Lottery_Run_Result__c> runResults = (List<Lottery_Run_Result__c>) databaseRepo.queryWithBinds(
      resultQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    if (!runResults.isEmpty()) {
      databaseRepo.deleteSObjects(runResults);
      result.runResultsDeleted = runResults.size();
    }

    databaseRepo.deleteSObjects(runLogs);

    return result;
  }

  public RollbackPrepareResult prepareRollback(Id runLogId) {
    Preconditions.checkNotNull(runLogId, 'Run Log ID is required');

    String runLogQuery = 'SELECT Id, Status__c, Application_Timeline__c FROM Lottery_Run_Log__c WHERE Id = :runLogId';
    List<Lottery_Run_Log__c> runLogs = (List<Lottery_Run_Log__c>) databaseRepo.queryWithBinds(
      runLogQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );

    Preconditions.checkArgument(!runLogs.isEmpty(), 'Lottery Run Log not found');

    // Query ApplicationTimeline to check Test__c (defense in depth - LWC also validates)
    Id timelineId = runLogs[0].Application_Timeline__c;
    String timelineQuery = 'SELECT Id, Test__c FROM ApplicationTimeline WHERE Id = :timelineId';
    List<ApplicationTimeline> timelines = (List<ApplicationTimeline>) databaseRepo.queryWithBinds(
      timelineQuery,
      new Map<String, Object>{ 'timelineId' => timelineId }
    );
    Preconditions.checkArgument(
      !timelines.isEmpty() && timelines[0].Test__c == true,
      'Rollback is only available for test lottery runs'
    );
    Preconditions.checkArgument(
      runLogs[0].Status__c == LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      'Cannot rollback a published lottery run'
    );

    RollbackPrepareResult result = new RollbackPrepareResult();

    // Unlink capacities from run log
    String capacityQuery = 'SELECT Id FROM Lottery_Capacity__c WHERE Lottery_Run_Log__c = :runLogId';
    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      capacityQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    for (Lottery_Capacity__c cap : capacities) {
      cap.Lottery_Run_Log__c = null;
      result.capacityIds.add(cap.Id);
    }
    if (!capacities.isEmpty()) {
      databaseRepo.updateSObjects(capacities);
      result.capacitiesUnlinked = capacities.size();
    }

    // Delete waitlist history
    String historyQuery = 'SELECT Id FROM Waitlist_Movement_History__c WHERE Lottery_Run_Log__c = :runLogId';
    List<Waitlist_Movement_History__c> histories = (List<Waitlist_Movement_History__c>) databaseRepo.queryWithBinds(
      historyQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    if (!histories.isEmpty()) {
      databaseRepo.deleteSObjects(histories);
      result.waitlistHistoryDeleted = histories.size();
    }

    // Delete run results
    String resultQuery = 'SELECT Id FROM Lottery_Run_Result__c WHERE Lottery_Run__c = :runLogId';
    List<Lottery_Run_Result__c> runResults = (List<Lottery_Run_Result__c>) databaseRepo.queryWithBinds(
      resultQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    if (!runResults.isEmpty()) {
      databaseRepo.deleteSObjects(runResults);
      result.runResultsDeleted = runResults.size();
    }

    // Delete run log
    databaseRepo.deleteSObjects(runLogs);

    // Count total records to reset (for progress display)
    if (!result.capacityIds.isEmpty()) {
      Set<Id> capIds = new Set<Id>(result.capacityIds);
      Set<String> statusesToReset = new Set<String>{
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_WAITLISTED,
        LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
      };
      String countQuery =
        'SELECT COUNT() FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capIds ' +
        'AND Status IN :statusesToReset';
      result.totalRecordsToReset = databaseRepo.countQueryWithBinds(
        countQuery,
        new Map<String, Object>{ 'capIds' => capIds, 'statusesToReset' => statusesToReset }
      );
    }

    return result;
  }

  public RollbackBatchResult rollbackAcademicInterestsBatch(
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  ) {
    RollbackBatchResult result = new RollbackBatchResult();

    if (capacityIds == null || capacityIds.isEmpty()) {
      return result;
    }

    try {
      Set<String> statusesToReset = new Set<String>{
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_WAITLISTED,
        LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
      };

      // Build query with keyset pagination
      String query =
        'SELECT Id, Status, Randomized_Sort_Key__c, Waitlist_Position__c, Original_Priority_Group__c ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capacityIds ' +
        'AND Status IN :statusesToReset';

      Map<String, Object> binds = new Map<String, Object>{
        'capacityIds' => capacityIds,
        'statusesToReset' => statusesToReset
      };

      if (lastRecordId != null) {
        query += ' AND Id > :lastRecordId';
        binds.put('lastRecordId', lastRecordId);
      }

      query += ' ORDER BY Id LIMIT :batchSize';
      binds.put('batchSize', batchSize + 1); // +1 to check for more records

      List<AcademicInterest> academicInterests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
        query,
        binds
      );

      // Check if there are more records
      if (academicInterests.size() > batchSize) {
        result.hasMore = true;
        academicInterests.remove(academicInterests.size() - 1);
      }

      // Reset the records
      for (AcademicInterest ai : academicInterests) {
        ai.Status = LotteryConstants.STATUS_ELIGIBLE;
        ai.Randomized_Sort_Key__c = null;
        ai.Waitlist_Position__c = null;
        ai.Original_Priority_Group__c = null;
      }

      if (!academicInterests.isEmpty()) {
        // Register records to prevent self-reference in cascade updates
        Set<Id> recordIds = new Set<Id>();
        for (AcademicInterest ai : academicInterests) {
          recordIds.add(ai.Id);
        }
        PreOfferCountRollupServiceImpl.registerProcessingRecords(recordIds);

        databaseRepo.updateSObjects(academicInterests);
        result.resetCount = academicInterests.size();
        result.lastRecordId = academicInterests[academicInterests.size() - 1].Id;
      }
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage();
    }

    return result;
  }

  public Integer createAuditRecords(Id runLogId, Set<Id> capacityIds) {
    if (runLogId == null || capacityIds == null || capacityIds.isEmpty()) {
      return 0;
    }

    // Query processed records in lottery number order
    Set<String> processedStatuses = new Set<String>{
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.STATUS_WAITLISTED,
      LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
    };

    String query =
      'SELECT Id, Current_Priority_Group__c, Status, Randomized_Sort_Key__c, School_Rank__c ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds ' +
      'AND Status IN :statuses ' +
      'ORDER BY Current_Priority_Group__c ASC, Randomized_Sort_Key__c ASC';

    List<AcademicInterest> records = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds, 'statuses' => processedStatuses }
    );

    if (records.isEmpty()) {
      return 0;
    }

    // Get run log timestamp for transition time
    String logQuery = 'SELECT Lottery_Run_Date__c FROM Lottery_Run_Log__c WHERE Id = :runLogId';
    List<Lottery_Run_Log__c> runLogs = (List<Lottery_Run_Log__c>) databaseRepo.queryWithBinds(
      logQuery,
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
    Datetime transitionTime = !runLogs.isEmpty() && runLogs[0].Lottery_Run_Date__c != null
      ? runLogs[0].Lottery_Run_Date__c
      : Datetime.now();

    // Create audit records
    List<Lottery_Run_Result__c> auditRecords = buildAuditRecords(
      records,
      runLogId,
      transitionTime,
      1
    );

    databaseRepo.insertSObjects(auditRecords);
    return auditRecords.size();
  }

  public CreateAuditBatchResult createAuditRecordsBatch(
    Id runLogId,
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize,
    Integer startLotteryNumber
  ) {
    CreateAuditBatchResult result = new CreateAuditBatchResult();

    if (runLogId == null || capacityIds == null || capacityIds.isEmpty()) {
      return result;
    }

    try {
      Set<String> processedStatuses = new Set<String>{
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_WAITLISTED,
        LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
      };

      // Build query with keyset pagination
      String query =
        'SELECT Id, Current_Priority_Group__c, Status, Randomized_Sort_Key__c, School_Rank__c ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capacityIds ' +
        'AND Status IN :statuses';

      Map<String, Object> binds = new Map<String, Object>{
        'capacityIds' => capacityIds,
        'statuses' => processedStatuses
      };

      if (lastRecordId != null) {
        query += ' AND Id > :lastRecordId';
        binds.put('lastRecordId', lastRecordId);
      }

      query += ' ORDER BY Id LIMIT :batchSize';
      binds.put('batchSize', batchSize + 1); // +1 to check for more records

      List<AcademicInterest> records = (List<AcademicInterest>) databaseRepo.queryWithBinds(
        query,
        binds
      );

      // Check if there are more records
      if (records.size() > batchSize) {
        result.hasMore = true;
        records.remove(records.size() - 1);
      }

      if (records.isEmpty()) {
        return result;
      }

      // Get run log timestamp for transition time
      String logQuery = 'SELECT Lottery_Run_Date__c FROM Lottery_Run_Log__c WHERE Id = :runLogId';
      List<Lottery_Run_Log__c> runLogs = (List<Lottery_Run_Log__c>) databaseRepo.queryWithBinds(
        logQuery,
        new Map<String, Object>{ 'runLogId' => runLogId }
      );
      Datetime transitionTime = !runLogs.isEmpty() && runLogs[0].Lottery_Run_Date__c != null
        ? runLogs[0].Lottery_Run_Date__c
        : Datetime.now();

      Integer lotteryStart = startLotteryNumber != null ? startLotteryNumber : 1;
      List<Lottery_Run_Result__c> auditRecords = buildAuditRecords(
        records,
        runLogId,
        transitionTime,
        lotteryStart
      );

      if (!auditRecords.isEmpty()) {
        databaseRepo.insertSObjects(auditRecords);
        result.recordsCreated = auditRecords.size();
        result.lastRecordId = records[records.size() - 1].Id;
        result.nextLotteryNumber = lotteryStart + countLotteryNumbersAssigned(auditRecords);
      }
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage();
    }

    return result;
  }

  /**
   * Builds Lottery_Run_Result__c audit records from AcademicInterest records.
   * For rescinded-optimization records, creates two audit records:
   *   1. Eligible -> Pre-Offer (with lottery number)
   *   2. Pre-Offer -> Rescinded (no lottery number)
   */
  private List<Lottery_Run_Result__c> buildAuditRecords(
    List<AcademicInterest> records,
    Id runLogId,
    Datetime transitionTime,
    Integer startLotteryNumber
  ) {
    List<Lottery_Run_Result__c> auditRecords = new List<Lottery_Run_Result__c>();
    Integer lotteryNumber = startLotteryNumber;

    for (AcademicInterest ai : records) {
      String priorityGroup = ai.Current_Priority_Group__c != null
        ? String.valueOf(ai.Current_Priority_Group__c.intValue())
        : null;
      String sortKey = ai.Randomized_Sort_Key__c != null
        ? String.valueOf(ai.Randomized_Sort_Key__c.longValue())
        : null;
      String schoolRank = ai.School_Rank__c != null
        ? String.valueOf(ai.School_Rank__c.intValue())
        : null;

      if (ai.Status == LotteryConstants.STATUS_RESCINDED_OPTIMIZATION) {
        // Record 1: Eligible -> Pre-Offer (with lottery number)
        auditRecords.add(
          new Lottery_Run_Result__c(
            Lottery_Run__c = runLogId,
            School_Application__c = ai.Id,
            Previous_Status__c = LotteryConstants.STATUS_ELIGIBLE,
            Status__c = LotteryConstants.STATUS_PRE_OFFER,
            Transition_Timestamp__c = transitionTime,
            Priority_Group__c = priorityGroup,
            Priority_Group_Number__c = ai.Current_Priority_Group__c,
            Randomized_Sort_Key__c = sortKey,
            School_Rank__c = schoolRank,
            Lottery_Number__c = lotteryNumber++
          )
        );

        // Record 2: Pre-Offer -> Rescinded (no lottery number)
        auditRecords.add(
          new Lottery_Run_Result__c(
            Lottery_Run__c = runLogId,
            School_Application__c = ai.Id,
            Previous_Status__c = LotteryConstants.STATUS_PRE_OFFER,
            Status__c = LotteryConstants.STATUS_RESCINDED,
            Transition_Timestamp__c = transitionTime,
            Priority_Group__c = priorityGroup,
            Priority_Group_Number__c = ai.Current_Priority_Group__c,
            Randomized_Sort_Key__c = sortKey,
            School_Rank__c = schoolRank
          )
        );
      } else {
        Lottery_Run_Result__c record = new Lottery_Run_Result__c(
          Lottery_Run__c = runLogId,
          School_Application__c = ai.Id,
          Previous_Status__c = LotteryConstants.STATUS_ELIGIBLE,
          Status__c = mapStatusForAuditLog(ai.Status),
          Transition_Timestamp__c = transitionTime,
          Priority_Group__c = priorityGroup,
          Priority_Group_Number__c = ai.Current_Priority_Group__c,
          Randomized_Sort_Key__c = sortKey,
          School_Rank__c = schoolRank
        );

        // Assign lottery number only to Pre-Offer records
        if (ai.Status == LotteryConstants.STATUS_PRE_OFFER) {
          record.Lottery_Number__c = lotteryNumber++;
        }

        auditRecords.add(record);
      }
    }

    return auditRecords;
  }

  /**
   * Counts how many audit records in the list were assigned a lottery number.
   */
  private Integer countLotteryNumbersAssigned(List<Lottery_Run_Result__c> records) {
    Integer count = 0;
    for (Lottery_Run_Result__c record : records) {
      if (record.Lottery_Number__c != null) {
        count++;
      }
    }
    return count;
  }

  /**
   * Maps AcademicInterest status values to Lottery_Run_Result__c.Status__c values.
   * The audit log uses a simpler picklist - detailed rescission reasons are mapped to 'Rescinded'.
   */
  private String mapStatusForAuditLog(String status) {
    if (status == LotteryConstants.STATUS_RESCINDED_OPTIMIZATION) {
      return LotteryConstants.STATUS_RESCINDED;
    }
    return status;
  }
}