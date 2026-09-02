/**
 * Tests for {@link RunLotteryController}.
 */
@IsTest(IsParallel=true)
private class RunLotteryControllerTest {
  private static final LotteryOrchestrationServiceMock ORCHESTRATION_MOCK;
  private static final LotteryAuditLogServiceMock AUDIT_LOG_MOCK;
  private static final DatabaseRepoMock DB_MOCK;
  private static final LotteryLockServiceMock LOCK_MOCK;

  static {
    ORCHESTRATION_MOCK = new LotteryOrchestrationServiceMock();
    AUDIT_LOG_MOCK = new LotteryAuditLogServiceMock();
    DB_MOCK = new DatabaseRepoMock();
    LOCK_MOCK = new LotteryLockServiceMock();

    RunLotteryController.orchestrationService = ORCHESTRATION_MOCK;
    RunLotteryController.auditLogService = AUDIT_LOG_MOCK;
    RunLotteryController.databaseRepo = DB_MOCK;
    RunLotteryController.lockService = LOCK_MOCK;
  }

  @IsTest
  private static void runLottery_withValidInput_returnsSuccessfulResponse() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    LotteryRunResult lotteryResult = new LotteryRunResult();
    lotteryResult.totalEligible = 10;
    lotteryResult.preOffersAssigned = 5;
    lotteryResult.offersRescinded = 1;
    lotteryResult.waitlisted = 4;
    lotteryResult.isSuccess = true;

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 12345
      )
    };

    Lottery_Run_Log__c runLog = (Lottery_Run_Log__c) ReadOnlySObject.create(
      new Lottery_Run_Log__c(Id = runLogId),
      new Map<String, Object>{ 'Name' => 'LR-001' }
    );

    // First query: idempotency check returns no already-run capacities
    // Second query: returns processed records
    // Third query: returns run log
    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>())
      .thenReturn(offeredRecords)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createLotteryRunLog()).thenReturn(runLogId);
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.runLottery()).thenReturn(lotteryResult);
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createLotteryRunResults()).thenReturn(1);
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.linkCapacitiesToRun()).thenReturnVoid();

    RunLotteryController.LotteryRunResponse response = RunLotteryController.runLottery(
      new List<Id>{ capacityId },
      timelineId,
      null,
      null
    );

    Assert.areEqual(runLogId, response.runLogId, 'Run log ID should match');
    Assert.areEqual(10, response.totalEligible, 'Total eligible should match');
    Assert.areEqual(5, response.preOffersAssigned, 'Pre-offers assigned should match');
    Assert.areEqual(1, response.offersRescinded, 'Offers rescinded should match');
    Assert.areEqual(4, response.waitlisted, 'Waitlisted should match');
    Assert.areEqual(1, response.results.size(), 'Should have 1 result row');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.createLotteryRunLog());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.runLottery());
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.createLotteryRunResults());
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.linkCapacitiesToRun());
  }

  @IsTest
  private static void getUnrunCapacities_withValidInput_returnsCapacities() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(
        Id = capacityId,
        Name = 'Grade K',
        Grade__c = 'K',
        Total_Available_Seats__c = 30
      ),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 25 }
    );

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity });

    List<Lottery_Capacity__c> results = RunLotteryController.getUnrunCapacities(timelineId);

    Assert.areEqual(1, results.size(), 'Should return 1 capacity');
    Assert.areEqual(capacityId, results[0].Id, 'ID should match');
    Assert.areEqual('Grade K', results[0].Name, 'Name should match');
    Assert.areEqual('K', results[0].Grade__c, 'Grade should match');
    Assert.areEqual(30, results[0].Total_Available_Seats__c, 'Total seats should match');
    Assert.areEqual(25, results[0].Remaining_Available_Seats__c, 'Available seats should match');
    DB_MOCK.verify(DB_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void publishLotteryRun_withValidInput_callsService() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.publishLotteryRun()).thenReturnVoid();

    RunLotteryController.publishLotteryRun(runLogId);

    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.publishLotteryRun());
  }

  @IsTest
  private static void getUnrunCapacities_withNullTimelineId_returnsEmptyList() {
    List<Lottery_Capacity__c> results = RunLotteryController.getUnrunCapacities(null);

    Assert.isNotNull(results, 'Should return non-null list');
    Assert.isTrue(results.isEmpty(), 'Should return empty list for null timeline ID');
  }

  @IsTest
  private static void runLottery_withNullCapacityIds_throwsException() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.runLottery(null, timelineId, null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void runLottery_withEmptyCapacityIds_throwsException() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.runLottery(new List<Id>(), timelineId, null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void runLottery_withNullTimelineId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Timeline ID is required'
    );

    try {
      RunLotteryController.runLottery(new List<Id>{ capacityId }, null, null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void publishLotteryRun_withNullRunLogId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.publishLotteryRun(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void runLottery_withAlreadyRunCapacities_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    Lottery_Capacity__c alreadyRunCapacity = new Lottery_Capacity__c(
      Id = capacityId,
      Name = 'Grade K',
      Lottery_Run_Log__c = runLogId
    );

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ alreadyRunCapacity });

    try {
      RunLotteryController.runLottery(new List<Id>{ capacityId }, timelineId, null, null);
      Assert.fail('Expected RunLotteryException');
    } catch (RunLotteryException e) {
      Assert.isTrue(
        e.getMessage().contains('already been run'),
        'Error should mention already run: ' + e.getMessage()
      );
      Assert.isTrue(
        e.getMessage().contains('Grade K'),
        'Error should include capacity name: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void lotteryRunResponse_hasDefaultValues() {
    RunLotteryController.LotteryRunResponse response = new RunLotteryController.LotteryRunResponse();

    Assert.areEqual(0, response.totalEligible, 'Default totalEligible should be 0');
    Assert.areEqual(0, response.preOffersAssigned, 'Default preOffersAssigned should be 0');
    Assert.areEqual(0, response.offersRescinded, 'Default offersRescinded should be 0');
    Assert.areEqual(0, response.waitlisted, 'Default waitlisted should be 0');
    Assert.isNotNull(response.results, 'Results list should not be null');
    Assert.isTrue(response.results.isEmpty(), 'Results list should be empty');
  }

  @IsTest
  private static void resultRow_canBePopulated() {
    RunLotteryController.ResultRow row = new RunLotteryController.ResultRow();
    row.id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    row.applicationName = 'Test Application';
    row.lotteryNumber = 1;
    row.priorityGroup = 2;
    row.randomizedKey = 12345;

    Assert.isNotNull(row.id, 'ID should be set');
    Assert.areEqual('Test Application', row.applicationName, 'Application name should match');
    Assert.areEqual(1, row.lotteryNumber, 'Lottery number should match');
    Assert.areEqual(2, row.priorityGroup, 'Priority group should match');
    Assert.areEqual(12345, row.randomizedKey, 'Randomized key should match');
  }

  @IsTest
  private static void rollbackLotteryRun_withValidInput_returnsSuccessfulResponse() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    LotteryRollbackResult rollbackResult = new LotteryRollbackResult();
    rollbackResult.capacitiesUnlinked = 2;
    rollbackResult.academicInterestsReset = 10;
    rollbackResult.waitlistHistoryDeleted = 3;
    rollbackResult.runResultsDeleted = 5;

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.rollbackLotteryRun()).thenReturn(rollbackResult);

    RunLotteryController.LotteryRollbackResponse response = RunLotteryController.rollbackLotteryRun(
      runLogId
    );

    Assert.isTrue(response.success, 'Response should be successful');
    Assert.areEqual(
      'Lottery run rolled back successfully',
      response.message,
      'Message should match'
    );
    Assert.areEqual(20, response.recordsReset, 'Records reset should be sum of all counts');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.rollbackLotteryRun());
  }

  @IsTest
  private static void rollbackLotteryRun_withNullRunLogId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.rollbackLotteryRun(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackLotteryRun_withPublishedRun_returnsFailure() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.rollbackLotteryRun())
      .thenThrow(new IllegalArgumentException('Cannot rollback a published lottery run'));

    RunLotteryController.LotteryRollbackResponse response = RunLotteryController.rollbackLotteryRun(
      runLogId
    );

    Assert.isFalse(response.success, 'Response should not be successful');
    Assert.areEqual(
      'Cannot rollback a published lottery run',
      response.message,
      'Message should indicate published status'
    );
    Assert.areEqual(0, response.recordsReset, 'Records reset should be 0');
  }

  @IsTest
  private static void lotteryRollbackResponse_hasDefaultValues() {
    RunLotteryController.LotteryRollbackResponse response = new RunLotteryController.LotteryRollbackResponse();

    Assert.isNull(response.success, 'Default success should be null');
    Assert.isNull(response.message, 'Default message should be null');
    Assert.isNull(response.recordsReset, 'Default recordsReset should be null');
  }

  @IsTest
  private static void getCapacityStats_withValidInput_returnsOnlyCapacitiesWithApplications() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    Lottery_Capacity__c cap1 = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId1, Grade__c = 'K', Total_Available_Seats__c = 30),
      new Map<String, Object>{}
    );
    Lottery_Capacity__c cap2 = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId2, Grade__c = '1', Total_Available_Seats__c = 25),
      new Map<String, Object>{}
    );

    // Mock with empty aggregate results - no capacities should be returned
    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ cap1, cap2 })
      .thenReturn(new List<AggregateResult>());

    List<RunLotteryController.CapacityStats> results = RunLotteryController.getCapacityStats(
      new List<Id>{ capacityId1, capacityId2 },
      null,
      null
    );

    // Only capacities with applications are returned
    Assert.areEqual(0, results.size(), 'Should return 0 stats when no applications');
    DB_MOCK.verify(DB_MOCK.method.queryWithBinds(), 2);
  }

  @IsTest
  private static void getCapacityStats_withNullCapacityIds_returnsEmptyList() {
    List<RunLotteryController.CapacityStats> results = RunLotteryController.getCapacityStats(
      null,
      null,
      null
    );

    Assert.isNotNull(results, 'Should return non-null list');
    Assert.isTrue(results.isEmpty(), 'Should return empty list for null capacity IDs');
  }

  @IsTest
  private static void getCapacityStats_withEmptyCapacityIds_returnsEmptyList() {
    List<RunLotteryController.CapacityStats> results = RunLotteryController.getCapacityStats(
      new List<Id>(),
      null,
      null
    );

    Assert.isNotNull(results, 'Should return non-null list');
    Assert.isTrue(results.isEmpty(), 'Should return empty list for empty capacity IDs');
  }

  @IsTest
  private static void getCapacityStats_withDateFilters_passesFiltersToQuery() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    Lottery_Capacity__c cap = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 30),
      new Map<String, Object>{}
    );

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ cap })
      .thenReturn(new List<AggregateResult>());

    Date startDate = Date.newInstance(2024, 1, 1);
    Date endDate = Date.newInstance(2024, 12, 31);

    List<RunLotteryController.CapacityStats> results = RunLotteryController.getCapacityStats(
      new List<Id>{ capacityId },
      startDate,
      endDate
    );

    // Capacities with no applications are filtered out
    Assert.areEqual(0, results.size(), 'Should return 0 stats when no applications');
    // Verify both queries were called (capacity query + aggregate query with date filters)
    DB_MOCK.verify(DB_MOCK.method.queryWithBinds(), 2);
  }

  @IsTest
  private static void capacityStats_canBePopulated() {
    RunLotteryController.CapacityStats stats = new RunLotteryController.CapacityStats();
    stats.capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    stats.schoolName = 'Test School';
    stats.grade = 'K';
    stats.availableSeats = 30;
    stats.applicationCount = 15;

    Assert.isNotNull(stats.capacityId, 'Capacity ID should be set');
    Assert.areEqual('Test School', stats.schoolName, 'School name should match');
    Assert.areEqual('K', stats.grade, 'Grade should match');
    Assert.areEqual(30, stats.availableSeats, 'Available seats should match');
    Assert.areEqual(15, stats.applicationCount, 'Application count should match');
  }

  @IsTest
  private static void initializeLottery_withValidInput_returnsSuccessfulResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    Lottery_Run_Log__c runLog = (Lottery_Run_Log__c) ReadOnlySObject.create(
      new Lottery_Run_Log__c(Id = runLogId),
      new Map<String, Object>{ 'Name' => 'LR-001' }
    );

    LOCK_MOCK.when(LOCK_MOCK.method.acquireLock()).thenReturn(testJobId);
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createLotteryRunLog()).thenReturn(runLogId);
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.linkCapacitiesToRun()).thenReturnVoid();
    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });

    InitializeLotteryResult result = RunLotteryController.initializeLottery(
      new List<Id>{ capacityId },
      timelineId
    );

    Assert.isTrue(result.isSuccess, 'Result should be successful');
    Assert.areEqual(testJobId, result.jobId, 'Job ID should match');
    Assert.areEqual(runLogId, result.runLogId, 'Run log ID should match');
    Assert.areEqual('LR-001', result.runLogName, 'Run log name should match');
    Assert.isNull(result.errorMessage, 'Error message should be null');
    LOCK_MOCK.verify(LOCK_MOCK.method.acquireLock());
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.createLotteryRunLog());
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.linkCapacitiesToRun());
  }

  @IsTest
  private static void initializeLottery_withNullCapacityIds_throwsException() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.initializeLottery(null, timelineId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void initializeLottery_withEmptyCapacityIds_throwsException() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.initializeLottery(new List<Id>(), timelineId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void initializeLottery_withNullTimelineId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Timeline ID is required'
    );

    try {
      RunLotteryController.initializeLottery(new List<Id>{ capacityId }, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void initializeLottery_withLockFailure_returnsError() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    LOCK_MOCK.when(LOCK_MOCK.method.acquireLock())
      .thenThrow(new LotteryLockException('Capacity already locked by another job'));

    InitializeLotteryResult result = RunLotteryController.initializeLottery(
      new List<Id>{ capacityId },
      timelineId
    );

    Assert.isFalse(result.isSuccess, 'Result should not be successful');
    Assert.isTrue(
      result.errorMessage.contains('Lock acquisition failed'),
      'Error should mention lock failure: ' + result.errorMessage
    );
    Assert.isNull(result.jobId, 'Job ID should be null on failure');
    Assert.isNull(result.runLogId, 'Run log ID should be null on failure');
  }

  @IsTest
  private static void initializeLottery_withGeneralException_returnsError() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    LOCK_MOCK.when(LOCK_MOCK.method.acquireLock()).thenReturn('test-job-123');
    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createLotteryRunLog())
      .thenThrow(new DmlException('Database error'));

    InitializeLotteryResult result = RunLotteryController.initializeLottery(
      new List<Id>{ capacityId },
      timelineId
    );

    Assert.isFalse(result.isSuccess, 'Result should not be successful');
    Assert.isTrue(
      result.errorMessage.contains('Initialization failed'),
      'Error should mention initialization failure: ' + result.errorMessage
    );
  }

  @IsTest
  private static void randomizeApplications_withValidInput_returnsCount() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.randomizeApplications()).thenReturn(25);

    Integer count = RunLotteryController.randomizeApplications(
      new List<Id>{ capacityId },
      runLogId,
      testJobId,
      null,
      null
    );

    Assert.areEqual(25, count, 'Should return count from orchestration service');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.randomizeApplications());
  }

  @IsTest
  private static void randomizeApplications_withNullCapacityIds_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.randomizeApplications(null, runLogId, 'job-123', null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void randomizeApplications_withNullJobId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Job ID is required'
    );

    try {
      RunLotteryController.randomizeApplications(
        new List<Id>{ capacityId },
        runLogId,
        null,
        null,
        null
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void randomizeApplications_withLockFailure_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock())
      .thenThrow(new LotteryLockException('Lock verification failed'));

    try {
      RunLotteryController.randomizeApplications(
        new List<Id>{ capacityId },
        runLogId,
        testJobId,
        null,
        null
      );
      Assert.fail('Expected LotteryLockException');
    } catch (LotteryLockException e) {
      Assert.isTrue(
        e.getMessage().contains('Lock verification failed'),
        'Error should mention lock failure: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void assignPreOffers_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    AssignPreOffersResult expectedResult = new AssignPreOffersResult();
    expectedResult.preOfferCount = 15;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.assignPreOffers()).thenReturn(expectedResult);

    AssignPreOffersResult result = RunLotteryController.assignPreOffers(
      new List<Id>{ capacityId },
      runLogId,
      testJobId,
      null,
      null
    );

    Assert.areEqual(15, result.preOfferCount, 'Pre-offer count should match');
    Assert.isTrue(result.isSuccess, 'Result should be successful');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.assignPreOffers());
  }

  @IsTest
  private static void assignPreOffers_withNullCapacityIds_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.assignPreOffers(null, runLogId, 'job-123', null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void assignPreOffers_withNullJobId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Job ID is required'
    );

    try {
      RunLotteryController.assignPreOffers(new List<Id>{ capacityId }, runLogId, null, null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void assignPreOffers_withLockFailure_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock())
      .thenThrow(new LotteryLockException('Lock verification failed'));

    try {
      RunLotteryController.assignPreOffers(
        new List<Id>{ capacityId },
        runLogId,
        testJobId,
        null,
        null
      );
      Assert.fail('Expected LotteryLockException');
    } catch (LotteryLockException e) {
      Assert.isTrue(
        e.getMessage().contains('Lock verification failed'),
        'Error should mention lock failure: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void optimizeOffers_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    OptimizeOffersResult expectedResult = new OptimizeOffersResult();
    expectedResult.rescindedCount = 5;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.optimizeOffers()).thenReturn(expectedResult);

    OptimizeOffersResult result = RunLotteryController.optimizeOffers(
      runLogId,
      testJobId,
      new List<Id>{ capacityId }
    );

    Assert.areEqual(5, result.rescindedCount, 'Rescinded count should match');
    Assert.isTrue(result.isSuccess, 'Result should be successful');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.optimizeOffers());
  }

  @IsTest
  private static void optimizeOffers_withNullRunLogId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.optimizeOffers(null, 'job-123', new List<Id>{ capacityId });
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void optimizeOffers_withNullJobId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Job ID is required'
    );

    try {
      RunLotteryController.optimizeOffers(runLogId, null, new List<Id>{ capacityId });
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void optimizeOffers_withLockFailure_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock())
      .thenThrow(new LotteryLockException('Lock verification failed'));

    try {
      RunLotteryController.optimizeOffers(runLogId, testJobId, new List<Id>{ capacityId });
      Assert.fail('Expected LotteryLockException');
    } catch (LotteryLockException e) {
      Assert.isTrue(
        e.getMessage().contains('Lock verification failed'),
        'Error should mention lock failure: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void finalizeLottery_withValidInput_returnsResultAndReleasesLock() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    FinalizeResult expectedResult = new FinalizeResult();
    expectedResult.waitlistCount = 10;
    expectedResult.eventsPublished = 5;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    LOCK_MOCK.when(LOCK_MOCK.method.releaseLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.finalizeLottery()).thenReturn(expectedResult);

    FinalizeResult result = RunLotteryController.finalizeLottery(
      new List<Id>{ capacityId },
      runLogId,
      testJobId
    );

    Assert.areEqual(10, result.waitlistCount, 'Waitlist count should match');
    Assert.areEqual(5, result.eventsPublished, 'Events published should match');
    Assert.isTrue(result.isSuccess, 'Result should be successful');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    LOCK_MOCK.verify(LOCK_MOCK.method.releaseLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.finalizeLottery());
  }

  @IsTest
  private static void finalizeLottery_withNullCapacityIds_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.finalizeLottery(null, runLogId, 'job-123');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void finalizeLottery_withNullJobId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Job ID is required'
    );

    try {
      RunLotteryController.finalizeLottery(new List<Id>{ capacityId }, runLogId, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void finalizeLottery_withLockFailure_returnsError() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock())
      .thenThrow(new LotteryLockException('Lock taken by another job'));

    FinalizeResult result = RunLotteryController.finalizeLottery(
      new List<Id>{ capacityId },
      runLogId,
      testJobId
    );

    Assert.isFalse(result.isSuccess, 'Result should not be successful');
    Assert.isTrue(
      result.errorMessage.contains('Lock verification failed'),
      'Error should mention lock failure: ' + result.errorMessage
    );
  }

  @IsTest
  private static void finalizeLottery_withGeneralException_releasesLockAndReturnsError() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    LOCK_MOCK.when(LOCK_MOCK.method.releaseLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.finalizeLottery())
      .thenThrow(new DmlException('Database error'));

    FinalizeResult result = RunLotteryController.finalizeLottery(
      new List<Id>{ capacityId },
      runLogId,
      testJobId
    );

    Assert.isFalse(result.isSuccess, 'Result should not be successful');
    Assert.isTrue(
      result.errorMessage.contains('Finalization failed'),
      'Error should mention finalization failure: ' + result.errorMessage
    );
    LOCK_MOCK.verify(LOCK_MOCK.method.releaseLock());
  }

  @IsTest
  private static void releaseLotteryLock_withValidInput_delegatesToService() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    String testJobId = 'test-job-123';

    LOCK_MOCK.when(LOCK_MOCK.method.releaseLock()).thenReturnVoid();

    RunLotteryController.releaseLotteryLock(new List<Id>{ capacityId }, testJobId);

    LOCK_MOCK.verify(LOCK_MOCK.method.releaseLock());
  }

  @IsTest
  private static void releaseLotteryLock_withNullCapacityIds_returnsWithoutError() {
    RunLotteryController.releaseLotteryLock(null, 'job-123');

    // Should not throw, just return silently
    Assert.isTrue(true, 'Method should complete without error');
  }

  @IsTest
  private static void releaseLotteryLock_withNullJobId_returnsWithoutError() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    RunLotteryController.releaseLotteryLock(new List<Id>{ capacityId }, null);

    // Should not throw, just return silently
    Assert.isTrue(true, 'Method should complete without error');
  }

  // ==================== Batch Controller Method Tests ====================

  @IsTest
  private static void randomizeApplicationsBatch_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    RandomizeBatchResult expectedResult = new RandomizeBatchResult();
    expectedResult.processedCount = 50;
    expectedResult.hasMore = true;
    expectedResult.lastRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.randomizeApplicationsBatch())
      .thenReturn(expectedResult);

    RandomizeBatchResult result = RunLotteryController.randomizeApplicationsBatch(
      new List<Id>{ capacityId },
      runLogId,
      testJobId,
      null,
      null,
      null,
      100
    );

    Assert.areEqual(50, result.processedCount, 'Processed count should match');
    Assert.isTrue(result.hasMore, 'Should indicate more records');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.randomizeApplicationsBatch());
  }

  @IsTest
  private static void randomizeApplicationsBatch_withNullCapacityIds_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.randomizeApplicationsBatch(null, null, 'job-123', null, null, null, 100);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void randomizeApplicationsBatch_withNullBatchSize_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Batch size must be positive'
    );

    try {
      RunLotteryController.randomizeApplicationsBatch(
        new List<Id>{ capacityId },
        null,
        'job-123',
        null,
        null,
        null,
        null
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void assignPreOffersBatch_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    AssignPreOffersResult expectedResult = new AssignPreOffersResult();
    expectedResult.preOfferCount = 20;
    expectedResult.hasMore = false;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.assignPreOffersBatch())
      .thenReturn(expectedResult);

    AssignPreOffersResult result = RunLotteryController.assignPreOffersBatch(
      new List<Id>{ capacityId },
      runLogId,
      testJobId,
      null,
      null,
      null,
      100
    );

    Assert.areEqual(20, result.preOfferCount, 'Pre-offer count should match');
    Assert.isFalse(result.hasMore, 'Should not have more records');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.assignPreOffersBatch());
  }

  @IsTest
  private static void assignPreOffersBatch_withNullCapacityIds_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.assignPreOffersBatch(null, null, 'job-123', null, null, null, 100);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void optimizeOffersBatch_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    OptimizeOffersResult expectedResult = new OptimizeOffersResult();
    expectedResult.rescindedCount = 3;
    expectedResult.hasMore = true;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.optimizeOffersBatch())
      .thenReturn(expectedResult);

    OptimizeOffersResult result = RunLotteryController.optimizeOffersBatch(
      runLogId,
      testJobId,
      new List<Id>{ capacityId },
      null,
      50
    );

    Assert.areEqual(3, result.rescindedCount, 'Rescinded count should match');
    Assert.isTrue(result.hasMore, 'Should indicate more records');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.optimizeOffersBatch());
  }

  @IsTest
  private static void optimizeOffersBatch_withNullRunLogId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.optimizeOffersBatch(
        null,
        'job-123',
        new List<Id>{ capacityId },
        null,
        50
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void optimizeOffersBatch_withNullBatchSize_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Batch size must be positive'
    );

    try {
      RunLotteryController.optimizeOffersBatch(
        runLogId,
        'job-123',
        new List<Id>{ capacityId },
        null,
        null
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void finalizeLotteryBatch_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    String testJobId = 'test-job-123';

    FinalizeResult expectedResult = new FinalizeResult();
    expectedResult.waitlistCount = 8;
    expectedResult.hasMore = false;
    expectedResult.isSuccess = true;

    LOCK_MOCK.when(LOCK_MOCK.method.verifyLock()).thenReturnVoid();
    ORCHESTRATION_MOCK.when(ORCHESTRATION_MOCK.method.finalizeLotteryBatch())
      .thenReturn(expectedResult);

    FinalizeResult result = RunLotteryController.finalizeLotteryBatch(
      new List<Id>{ capacityId },
      runLogId,
      testJobId,
      null,
      100
    );

    Assert.areEqual(8, result.waitlistCount, 'Waitlist count should match');
    Assert.isFalse(result.hasMore, 'Should not have more records');
    LOCK_MOCK.verify(LOCK_MOCK.method.verifyLock());
    ORCHESTRATION_MOCK.verify(ORCHESTRATION_MOCK.method.finalizeLotteryBatch());
  }

  @IsTest
  private static void finalizeLotteryBatch_withNullCapacityIds_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be selected'
    );

    try {
      RunLotteryController.finalizeLotteryBatch(null, runLogId, 'job-123', null, 100);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void finalizeLotteryBatch_withNullBatchSize_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Batch size must be positive'
    );

    try {
      RunLotteryController.finalizeLotteryBatch(
        new List<Id>{ capacityId },
        runLogId,
        'job-123',
        null,
        null
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getResults_withValidInput_returnsResponse() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> processedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 12345
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(processedRecords);

    RunLotteryController.LotteryResultsResponse response = RunLotteryController.getResults(
      new List<Id>{ capacityId }
    );

    Assert.areEqual(1, response.results.size(), 'Should have 1 offered result');
    Assert.areEqual(1, response.allResults.size(), 'Should have 1 total result');
    Assert.areEqual(1, response.totalEligible, 'Total eligible should be 1');
  }

  @IsTest
  private static void getResults_withNullCapacityIds_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be provided'
    );

    try {
      RunLotteryController.getResults(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void createAuditRecords_withValidInput_returnsCount() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createAuditRecords()).thenReturn(5);

    Integer count = RunLotteryController.createAuditRecords(
      runLogId,
      new List<Id>{ capacityId }
    );

    Assert.areEqual(5, count, 'Should return count from audit service');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.createAuditRecords());
  }

  @IsTest
  private static void createAuditRecords_withNullRunLogId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.createAuditRecords(null, new List<Id>{ capacityId });
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void createAuditRecordsBatch_withValidInput_returnsResult() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    CreateAuditBatchResult expectedResult = new CreateAuditBatchResult();
    expectedResult.recordsCreated = 10;
    expectedResult.hasMore = true;
    expectedResult.nextLotteryNumber = 11;

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.createAuditRecordsBatch())
      .thenReturn(expectedResult);

    CreateAuditBatchResult result = RunLotteryController.createAuditRecordsBatch(
      runLogId,
      new List<Id>{ capacityId },
      null,
      100,
      1
    );

    Assert.areEqual(10, result.recordsCreated, 'Records created should match');
    Assert.isTrue(result.hasMore, 'Should indicate more records');
    Assert.areEqual(11, result.nextLotteryNumber, 'Next lottery number should match');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.createAuditRecordsBatch());
  }

  @IsTest
  private static void createAuditRecordsBatch_withNullCapacityIds_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be provided'
    );

    try {
      RunLotteryController.createAuditRecordsBatch(runLogId, null, null, 100, 1);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void prepareRollback_withValidInput_returnsResult() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    RollbackPrepareResult expectedResult = new RollbackPrepareResult();
    expectedResult.capacitiesUnlinked = 3;
    expectedResult.waitlistHistoryDeleted = 5;
    expectedResult.runResultsDeleted = 10;
    expectedResult.totalRecordsToReset = 25;

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.prepareRollback()).thenReturn(expectedResult);

    RollbackPrepareResult result = RunLotteryController.prepareRollback(runLogId);

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(3, result.capacitiesUnlinked, 'Capacities unlinked should match');
    Assert.areEqual(5, result.waitlistHistoryDeleted, 'Waitlist history deleted should match');
    Assert.areEqual(10, result.runResultsDeleted, 'Run results deleted should match');
    Assert.areEqual(25, result.totalRecordsToReset, 'Total records to reset should match');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.prepareRollback());
  }

  @IsTest
  private static void prepareRollback_withNullRunLogId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      RunLotteryController.prepareRollback(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void prepareRollback_withIllegalArgument_returnsFailure() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.prepareRollback())
      .thenThrow(new IllegalArgumentException('Rollback is only available for test lottery runs'));

    RollbackPrepareResult result = RunLotteryController.prepareRollback(runLogId);

    Assert.isFalse(result.isSuccess, 'Should not be successful');
    Assert.areEqual(
      'Rollback is only available for test lottery runs',
      result.errorMessage,
      'Error message should match'
    );
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withValidInput_returnsResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    RollbackBatchResult expectedResult = new RollbackBatchResult();
    expectedResult.resetCount = 15;
    expectedResult.hasMore = true;
    expectedResult.lastRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AUDIT_LOG_MOCK.when(AUDIT_LOG_MOCK.method.rollbackAcademicInterestsBatch())
      .thenReturn(expectedResult);

    RollbackBatchResult result = RunLotteryController.rollbackAcademicInterestsBatch(
      new List<Id>{ capacityId },
      null,
      100
    );

    Assert.areEqual(15, result.resetCount, 'Reset count should match');
    Assert.isTrue(result.hasMore, 'Should indicate more records');
    AUDIT_LOG_MOCK.verify(AUDIT_LOG_MOCK.method.rollbackAcademicInterestsBatch());
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withNullCapacityIds_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'At least one capacity must be provided'
    );

    try {
      RunLotteryController.rollbackAcademicInterestsBatch(null, null, 100);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withNullBatchSize_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Batch size must be positive'
    );

    try {
      RunLotteryController.rollbackAcademicInterestsBatch(
        new List<Id>{ capacityId },
        null,
        null
      );
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
}