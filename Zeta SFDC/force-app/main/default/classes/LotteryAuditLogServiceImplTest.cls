/**
 * Tests for {@link LotteryAuditLogServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LotteryAuditLogServiceImplTest {
  private static final LotteryAuditLogServiceImpl SERVICE;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SERVICE = new LotteryAuditLogServiceImpl(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void constructor_default_canBeInstantiated() {
    LotteryAuditLogServiceImpl instance = new LotteryAuditLogServiceImpl();

    Assert.isNotNull(instance, 'Service should be instantiable');
  }

  @IsTest
  private static void createLotteryRunLog_withTimelineId_createsRecord() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SERVICE.createLotteryRunLog(timelineId);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void createLotteryRunLog_setsCorrectFields() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SERVICE.createLotteryRunLog(timelineId);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');
    Lottery_Run_Log__c runLog = (Lottery_Run_Log__c) insertedRecords[0];

    Assert.areEqual(timelineId, runLog.Application_Timeline__c, 'Should set timeline');
    Assert.isNotNull(runLog.Lottery_Run_Date__c, 'Should set run date');
    Assert.areEqual(
      LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      runLog.Status__c,
      'Should set status to Draft'
    );
  }

  @IsTest
  private static void createLotteryRunResults_withNullResult_returnsZero() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    Integer result = SERVICE.createLotteryRunResults(runLogId, null);

    Assert.areEqual(0, result, 'Should return 0 for null result');
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void createLotteryRunResults_withEmptyTransitions_returnsZero() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    Integer result = SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    Assert.areEqual(0, result, 'Should return 0 for empty transitions');
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void createLotteryRunResults_withTransitions_createsResults() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    for (Integer i = 0; i < 3; i++) {
      Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
      lotteryResult.transitions.add(
        new LotteryStatusChange(
          aiId,
          LotteryConstants.STATUS_ELIGIBLE,
          LotteryConstants.STATUS_PRE_OFFER,
          'offer'
        )
      );
    }

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    Assert.areEqual(3, result, 'Should return 3 for 3 transitions');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void createLotteryRunResults_fromResult_createsOnePerTransition() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    // Same record, two transitions: Eligible -> Pre-Offer -> Rescinded
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId,
        LotteryConstants.STATUS_ELIGIBLE,
        LotteryConstants.STATUS_PRE_OFFER,
        'offer'
      )
    );
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId,
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_RESCINDED,
        'rescind'
      )
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    Assert.areEqual(2, result, 'Should create one result per transition');
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual(2, insertedRecords.size(), 'Should insert 2 records');
  }

  @IsTest
  private static void createLotteryRunResults_assignsSequentialLotteryNumbers() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    for (Integer i = 0; i < 3; i++) {
      Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
      lotteryResult.transitions.add(
        new LotteryStatusChange(
          aiId,
          LotteryConstants.STATUS_ELIGIBLE,
          LotteryConstants.STATUS_PRE_OFFER,
          'offer'
        )
      );
    }

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Assert.areEqual(
      1,
      ((Lottery_Run_Result__c) insertedRecords[0]).Lottery_Number__c,
      'First should be 1'
    );
    Assert.areEqual(
      2,
      ((Lottery_Run_Result__c) insertedRecords[1]).Lottery_Number__c,
      'Second should be 2'
    );
    Assert.areEqual(
      3,
      ((Lottery_Run_Result__c) insertedRecords[2]).Lottery_Number__c,
      'Third should be 3'
    );
  }

  @IsTest
  private static void createLotteryRunResults_assignsLotteryNumberOnlyToFirstPreOffer() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    // Same record gets Pre-Offer, then Rescinded, then Pre-Offer again
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId,
        LotteryConstants.STATUS_ELIGIBLE,
        LotteryConstants.STATUS_PRE_OFFER,
        'offer'
      )
    );
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId,
        LotteryConstants.STATUS_PRE_OFFER,
        LotteryConstants.STATUS_RESCINDED,
        'rescind'
      )
    );
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId,
        LotteryConstants.STATUS_RESCINDED,
        LotteryConstants.STATUS_PRE_OFFER,
        'offer'
      )
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Assert.areEqual(3, insertedRecords.size(), 'Should create 3 results');
    Assert.areEqual(
      1,
      ((Lottery_Run_Result__c) insertedRecords[0]).Lottery_Number__c,
      'First Pre-Offer should get lottery number 1'
    );
    Assert.isNull(
      ((Lottery_Run_Result__c) insertedRecords[1]).Lottery_Number__c,
      'Rescinded should not get lottery number'
    );
    Assert.isNull(
      ((Lottery_Run_Result__c) insertedRecords[2]).Lottery_Number__c,
      'Second Pre-Offer for same record should NOT get lottery number'
    );
  }

  @IsTest
  private static void createLotteryRunResults_stampsPriorityGroup() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    LotteryRunResult lotteryResult = new LotteryRunResult();

    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId3 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Add transitions with different priority groups
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId1,
        LotteryConstants.STATUS_ELIGIBLE,
        LotteryConstants.STATUS_PRE_OFFER,
        'offer',
        1
      )
    );
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId2,
        LotteryConstants.STATUS_ELIGIBLE,
        LotteryConstants.STATUS_PRE_OFFER,
        'offer',
        2
      )
    );
    lotteryResult.transitions.add(
      new LotteryStatusChange(
        aiId3,
        LotteryConstants.STATUS_ELIGIBLE,
        LotteryConstants.STATUS_WAITLISTED,
        'no seats',
        null
      )
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SERVICE.createLotteryRunResults(runLogId, lotteryResult);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Assert.areEqual(
      '1',
      ((Lottery_Run_Result__c) insertedRecords[0]).Priority_Group__c,
      'First record should have priority group 1'
    );
    Assert.areEqual(
      '2',
      ((Lottery_Run_Result__c) insertedRecords[1]).Priority_Group__c,
      'Second record should have priority group 2'
    );
    Assert.isNull(
      ((Lottery_Run_Result__c) insertedRecords[2]).Priority_Group__c,
      'Third record should have null priority group'
    );
  }

  @IsTest
  private static void linkCapacitiesToRun_withNullSet_doesNothing() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    SERVICE.linkCapacitiesToRun(runLogId, null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void linkCapacitiesToRun_withEmptySet_doesNothing() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    SERVICE.linkCapacitiesToRun(runLogId, new Set<Id>());

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void linkCapacitiesToRun_updatesCapacities() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = new Lottery_Capacity__c(Id = capacityId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SERVICE.linkCapacitiesToRun(runLogId, new Set<Id>{ capacityId });

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    Assert.areEqual(runLogId, capacity.Lottery_Run_Log__c, 'Should set run log reference');
  }

  @IsTest
  private static void publishLotteryRun_withNullId_doesNothing() {
    SERVICE.publishLotteryRun(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void publishLotteryRun_updatesStatusAndDate() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(Id = runLogId, Status__c = 'Not Published');

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    LotteryPublishStampOffersQueueable.chainToTransition = false;
    SERVICE.publishLotteryRun(runLogId);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    Assert.areEqual('Published', runLog.Status__c, 'Should set status to Published');
    Assert.isNotNull(runLog.Lottery_Publish_Date__c, 'Should set publish date');
  }

  @IsTest
  private static void publishLotteryRun_withNoMatchingRecord_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>());

    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      SERVICE.publishLotteryRun(runLogId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackLotteryRun_withTestRun_resetsAllRecords() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);
    Lottery_Capacity__c capacity = new Lottery_Capacity__c(
      Id = capacityId,
      Lottery_Run_Log__c = runLogId
    );
    AcademicInterest ai = new AcademicInterest(
      Id = aiId,
      Status = LotteryConstants.STATUS_PRE_OFFER,
      Randomized_Sort_Key__c = 12345,
      Waitlist_Position__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline })
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(new List<Waitlist_Movement_History__c>())
      .thenReturn(new List<Lottery_Run_Result__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid() // unlink capacities
      .thenReturnVoid(); // reset AcademicInterests
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid(); // delete Lottery_Run_Log only (histories/results empty)

    LotteryRollbackResult result = SERVICE.rollbackLotteryRun(runLogId);

    Assert.areEqual(1, result.capacitiesUnlinked, 'Should unlink 1 capacity');
    Assert.areEqual(1, result.academicInterestsReset, 'Should reset 1 academic interest');
    Assert.areEqual(0, result.waitlistHistoryDeleted, 'Should delete 0 history records');
    Assert.areEqual(0, result.runResultsDeleted, 'Should delete 0 result records');
    Assert.isNull(capacity.Lottery_Run_Log__c, 'Capacity should be unlinked');
    Assert.areEqual(LotteryConstants.STATUS_ELIGIBLE, ai.Status, 'AI status should be Eligible');
    Assert.isNull(ai.Randomized_Sort_Key__c, 'AI randomized key should be null');
    Assert.isNull(ai.Waitlist_Position__c, 'AI waitlist position should be null');
  }

  @IsTest
  private static void rollbackLotteryRun_withPublishedRun_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_PUBLISHED,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Cannot rollback a published lottery run'
    );

    try {
      SERVICE.rollbackLotteryRun(runLogId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackLotteryRun_withNonTestRun_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = false);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Rollback is only available for test lottery runs'
    );

    try {
      SERVICE.rollbackLotteryRun(runLogId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackLotteryRun_withNullId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      SERVICE.rollbackLotteryRun(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void rollbackLotteryRun_withNoAffectedRecords_succeeds() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline })
      .thenReturn(new List<Lottery_Capacity__c>())
      .thenReturn(new List<Waitlist_Movement_History__c>())
      .thenReturn(new List<Lottery_Run_Result__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();

    LotteryRollbackResult result = SERVICE.rollbackLotteryRun(runLogId);

    Assert.areEqual(0, result.capacitiesUnlinked, 'Should unlink 0 capacities');
    Assert.areEqual(0, result.academicInterestsReset, 'Should reset 0 academic interests');
    Assert.areEqual(0, result.waitlistHistoryDeleted, 'Should delete 0 history records');
    Assert.areEqual(0, result.runResultsDeleted, 'Should delete 0 result records');
  }

  // ==================== createAuditRecords Tests ====================

  @IsTest
  private static void createAuditRecords_withRescindedRecords_createsTwoRecordsEach() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest ai = new AcademicInterest(
      Id = aiId,
      Status = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION,
      Current_Priority_Group__c = 1,
      Randomized_Sort_Key__c = 100
    );

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createAuditRecords(runLogId, new Set<Id>{ capacityId });

    Assert.areEqual(2, result, 'Should create 2 records for 1 rescinded AI');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    // Record 1: Eligible -> Pre-Offer
    Lottery_Run_Result__c preOfferRecord = (Lottery_Run_Result__c) insertedRecords[0];
    Assert.areEqual(
      LotteryConstants.STATUS_ELIGIBLE,
      preOfferRecord.Previous_Status__c,
      'First record previous should be Eligible'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      preOfferRecord.Status__c,
      'First record status should be Pre-Offer'
    );
    Assert.areEqual(1, preOfferRecord.Lottery_Number__c, 'First record should get lottery number');

    // Record 2: Pre-Offer -> Rescinded
    Lottery_Run_Result__c rescindedRecord = (Lottery_Run_Result__c) insertedRecords[1];
    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      rescindedRecord.Previous_Status__c,
      'Second record previous should be Pre-Offer'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_RESCINDED,
      rescindedRecord.Status__c,
      'Second record status should be Rescinded'
    );
    Assert.isNull(rescindedRecord.Lottery_Number__c, 'Second record should not get lottery number');
  }

  @IsTest
  private static void createAuditRecords_lotteryNumbersIncludeRescindedPreOffer() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiPreOffer = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiRescinded = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Pre-Offer student comes first in sort order, then rescinded
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiPreOffer,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 50
      ),
      new AcademicInterest(
        Id = aiRescinded,
        Status = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      )
    };

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(records)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createAuditRecords(runLogId, new Set<Id>{ capacityId });

    Assert.areEqual(3, result, 'Should create 3 records (1 Pre-Offer + 2 for rescinded)');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    // Pre-Offer student gets lottery number 1
    Assert.areEqual(
      1,
      ((Lottery_Run_Result__c) insertedRecords[0]).Lottery_Number__c,
      'Pre-Offer should be lottery #1'
    );

    // Rescinded student's Pre-Offer record gets lottery number 2
    Assert.areEqual(
      2,
      ((Lottery_Run_Result__c) insertedRecords[1]).Lottery_Number__c,
      'Rescinded Pre-Offer should be lottery #2'
    );

    // Rescinded student's Rescinded record gets no lottery number
    Assert.isNull(
      ((Lottery_Run_Result__c) insertedRecords[2]).Lottery_Number__c,
      'Rescinded record should have no lottery number'
    );
  }

  @IsTest
  private static void createAuditRecords_withOnlyPreOfferRecords_unchangedBehavior() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId1,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 50
      ),
      new AcademicInterest(
        Id = aiId2,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      )
    };

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(records)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createAuditRecords(runLogId, new Set<Id>{ capacityId });

    Assert.areEqual(2, result, 'Should create 1 record per Pre-Offer student');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Lottery_Run_Result__c record1 = (Lottery_Run_Result__c) insertedRecords[0];
    Assert.areEqual(
      LotteryConstants.STATUS_ELIGIBLE,
      record1.Previous_Status__c,
      'Previous should be Eligible'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      record1.Status__c,
      'Status should be Pre-Offer'
    );
    Assert.areEqual(1, record1.Lottery_Number__c, 'Should get lottery #1');

    Lottery_Run_Result__c record2 = (Lottery_Run_Result__c) insertedRecords[1];
    Assert.areEqual(2, record2.Lottery_Number__c, 'Should get lottery #2');
  }

  @IsTest
  private static void createAuditRecords_withWaitlistedRecord_createsSingleRecord() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest ai = new AcademicInterest(
      Id = aiId,
      Status = LotteryConstants.STATUS_WAITLISTED,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 200
    );

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Integer result = SERVICE.createAuditRecords(runLogId, new Set<Id>{ capacityId });

    Assert.areEqual(1, result, 'Should create 1 record for waitlisted AI');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Lottery_Run_Result__c record = (Lottery_Run_Result__c) insertedRecords[0];
    Assert.areEqual(
      LotteryConstants.STATUS_ELIGIBLE,
      record.Previous_Status__c,
      'Previous should be Eligible'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_WAITLISTED,
      record.Status__c,
      'Status should be Waitlisted'
    );
    Assert.isNull(record.Lottery_Number__c, 'Waitlisted should not get lottery number');
  }

  @IsTest
  private static void createAuditRecords_withNullInputs_returnsZero() {
    Assert.areEqual(
      0,
      SERVICE.createAuditRecords(null, new Set<Id>()),
      'Null runLogId should return 0'
    );

    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Assert.areEqual(
      0,
      SERVICE.createAuditRecords(runLogId, null),
      'Null capacityIds should return 0'
    );
    Assert.areEqual(
      0,
      SERVICE.createAuditRecords(runLogId, new Set<Id>()),
      'Empty capacityIds should return 0'
    );
  }

  // ==================== createAuditRecordsBatch Tests ====================

  @IsTest
  private static void createAuditRecordsBatch_paginatesCorrectly() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Simulate batch of 1 with hasMore (return 2 records for batchSize=1)
    List<AcademicInterest> batch1Records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId1,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 50
      ),
      new AcademicInterest(
        Id = aiId2,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      )
    };

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(batch1Records) // AcademicInterest query returns 2 (batchSize+1)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog }); // Run log query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    CreateAuditBatchResult result = SERVICE.createAuditRecordsBatch(
      runLogId,
      new Set<Id>{ capacityId },
      null,
      1,
      1
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.isTrue(result.hasMore, 'Should indicate more records');
    Assert.areEqual(1, result.recordsCreated, 'Should create 1 record (batchSize)');
    Assert.areEqual(aiId1, result.lastRecordId, 'Should return last processed record ID');
    Assert.areEqual(2, result.nextLotteryNumber, 'Next lottery number should be 2');
  }

  @IsTest
  private static void createAuditRecordsBatch_withNullInputs_returnsEmptyResult() {
    CreateAuditBatchResult result1 = SERVICE.createAuditRecordsBatch(
      null,
      new Set<Id>(),
      null,
      100,
      1
    );
    Assert.isTrue(result1.isSuccess, 'Null runLogId should return success with empty result');
    Assert.areEqual(0, result1.recordsCreated, 'Should create 0 records');
    Assert.isFalse(result1.hasMore, 'Should not have more');

    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    CreateAuditBatchResult result2 = SERVICE.createAuditRecordsBatch(runLogId, null, null, 100, 1);
    Assert.isTrue(result2.isSuccess, 'Null capacityIds should return success with empty result');
    Assert.areEqual(0, result2.recordsCreated, 'Should create 0 records');

    CreateAuditBatchResult result3 = SERVICE.createAuditRecordsBatch(
      runLogId,
      new Set<Id>(),
      null,
      100,
      1
    );
    Assert.isTrue(result3.isSuccess, 'Empty capacityIds should return success with empty result');
    Assert.areEqual(0, result3.recordsCreated, 'Should create 0 records');
  }

  @IsTest
  private static void createAuditRecordsBatch_withRescinded_createsTwoRecords() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId,
        Status = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      )
    };

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(records)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    CreateAuditBatchResult result = SERVICE.createAuditRecordsBatch(
      runLogId,
      new Set<Id>{ capacityId },
      null,
      200,
      1
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(2, result.recordsCreated, 'Should create 2 records for 1 rescinded AI');
    Assert.areEqual(
      2,
      result.nextLotteryNumber,
      'Next lottery number should be 2 (1 Pre-Offer assigned)'
    );

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Lottery_Run_Result__c preOfferRecord = (Lottery_Run_Result__c) insertedRecords[0];
    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      preOfferRecord.Status__c,
      'First should be Pre-Offer'
    );
    Assert.areEqual(1, preOfferRecord.Lottery_Number__c, 'Should get lottery number');

    Lottery_Run_Result__c rescindedRecord = (Lottery_Run_Result__c) insertedRecords[1];
    Assert.areEqual(
      LotteryConstants.STATUS_RESCINDED,
      rescindedRecord.Status__c,
      'Second should be Rescinded'
    );
    Assert.isNull(rescindedRecord.Lottery_Number__c, 'Should not get lottery number');
  }

  @IsTest
  private static void createAuditRecordsBatch_chainsLotteryNumberAcrossBatches() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 50
      )
    };

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Lottery_Run_Date__c = Datetime.now()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(records)
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    // Simulate second batch starting at lottery number 5
    CreateAuditBatchResult result = SERVICE.createAuditRecordsBatch(
      runLogId,
      new Set<Id>{ capacityId },
      null,
      200,
      5
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(6, result.nextLotteryNumber, 'Next lottery number should be 6');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> insertedRecords = (List<SObject>) calls[0].get('sobjects');

    Assert.areEqual(
      5,
      ((Lottery_Run_Result__c) insertedRecords[0]).Lottery_Number__c,
      'Should start at 5'
    );
  }

  // ==================== prepareRollback Tests ====================

  @IsTest
  private static void prepareRollback_withTestRun_unlinksAndDeletesRecords() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);
    Lottery_Capacity__c capacity = new Lottery_Capacity__c(
      Id = capacityId,
      Lottery_Run_Log__c = runLogId
    );
    Waitlist_Movement_History__c history = new Waitlist_Movement_History__c(
      Id = SObjectIds.generateFakeId(Schema.Waitlist_Movement_History__c.SObjectType)
    );
    Lottery_Run_Result__c runResult = new Lottery_Run_Result__c(
      Id = SObjectIds.generateFakeId(Schema.Lottery_Run_Result__c.SObjectType)
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline })
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(new List<Waitlist_Movement_History__c>{ history })
      .thenReturn(new List<Lottery_Run_Result__c>{ runResult });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects())
      .thenReturnVoid() // delete histories
      .thenReturnVoid() // delete results
      .thenReturnVoid(); // delete run log
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.countQueryWithBinds()).thenReturn(12);

    RollbackPrepareResult result = SERVICE.prepareRollback(runLogId);

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(1, result.capacitiesUnlinked, 'Should unlink 1 capacity');
    Assert.areEqual(1, result.waitlistHistoryDeleted, 'Should delete 1 history');
    Assert.areEqual(1, result.runResultsDeleted, 'Should delete 1 result');
    Assert.areEqual(12, result.totalRecordsToReset, 'Should report 12 records to reset');
    Assert.isTrue(result.capacityIds.contains(capacityId), 'Should include capacity ID');
    Assert.isNull(capacity.Lottery_Run_Log__c, 'Capacity should be unlinked');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects(), 3);
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.countQueryWithBinds());
  }

  @IsTest
  private static void prepareRollback_withNoAffectedRecords_succeeds() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline })
      .thenReturn(new List<Lottery_Capacity__c>())
      .thenReturn(new List<Waitlist_Movement_History__c>())
      .thenReturn(new List<Lottery_Run_Result__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();

    RollbackPrepareResult result = SERVICE.prepareRollback(runLogId);

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(0, result.capacitiesUnlinked, 'Should unlink 0 capacities');
    Assert.areEqual(0, result.waitlistHistoryDeleted, 'Should delete 0 histories');
    Assert.areEqual(0, result.runResultsDeleted, 'Should delete 0 results');
    Assert.areEqual(0, result.totalRecordsToReset, 'Should have 0 records to reset');
    Assert.isTrue(result.capacityIds.isEmpty(), 'Should have no capacity IDs');
  }

  @IsTest
  private static void prepareRollback_withNullId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Run Log ID is required'
    );

    try {
      SERVICE.prepareRollback(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void prepareRollback_withPublishedRun_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_PUBLISHED,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = true);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Cannot rollback a published lottery run'
    );

    try {
      SERVICE.prepareRollback(runLogId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void prepareRollback_withNonTestRun_throwsException() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Lottery_Run_Log__c runLog = new Lottery_Run_Log__c(
      Id = runLogId,
      Status__c = LotteryConstants.LOTTERY_RUN_STATUS_DRAFT,
      Application_Timeline__c = timelineId
    );
    ApplicationTimeline timeline = new ApplicationTimeline(Id = timelineId, Test__c = false);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Run_Log__c>{ runLog })
      .thenReturn(new List<ApplicationTimeline>{ timeline });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Rollback is only available for test lottery runs'
    );

    try {
      SERVICE.prepareRollback(runLogId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  // ==================== rollbackAcademicInterestsBatch Tests ====================

  @IsTest
  private static void rollbackAcademicInterestsBatch_withRecords_resetsAndReturnsCursor() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = aiId1,
      Status = LotteryConstants.STATUS_PRE_OFFER,
      Randomized_Sort_Key__c = 12345,
      Waitlist_Position__c = null,
      Original_Priority_Group__c = 1
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = aiId2,
      Status = LotteryConstants.STATUS_WAITLISTED,
      Randomized_Sort_Key__c = 67890,
      Waitlist_Position__c = 3,
      Original_Priority_Group__c = 2
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai1, ai2 });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    RollbackBatchResult result = SERVICE.rollbackAcademicInterestsBatch(
      new Set<Id>{ capacityId },
      null,
      10
    );

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(2, result.resetCount, 'Should reset 2 records');
    Assert.areEqual(aiId2, result.lastRecordId, 'Last record ID should be second record');
    Assert.isFalse(result.hasMore, 'Should not have more records');

    // Verify records were reset
    Assert.areEqual(LotteryConstants.STATUS_ELIGIBLE, ai1.Status, 'AI1 should be Eligible');
    Assert.isNull(ai1.Randomized_Sort_Key__c, 'AI1 sort key should be null');
    Assert.isNull(ai1.Original_Priority_Group__c, 'AI1 original priority group should be null');
    Assert.areEqual(LotteryConstants.STATUS_ELIGIBLE, ai2.Status, 'AI2 should be Eligible');
    Assert.isNull(ai2.Randomized_Sort_Key__c, 'AI2 sort key should be null');
    Assert.isNull(ai2.Waitlist_Position__c, 'AI2 waitlist position should be null');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withMoreRecords_setsHasMore() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Return batchSize + 1 records to trigger hasMore
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(
        Id = aiId1,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        Randomized_Sort_Key__c = 100
      ),
      new AcademicInterest(
        Id = aiId2,
        Status = LotteryConstants.STATUS_WAITLISTED,
        Randomized_Sort_Key__c = 200
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(records);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    RollbackBatchResult result = SERVICE.rollbackAcademicInterestsBatch(
      new Set<Id>{ capacityId },
      null,
      1 // batchSize=1, so 2 records means hasMore
    );

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.isTrue(result.hasMore, 'Should have more records');
    Assert.areEqual(1, result.resetCount, 'Should process only batchSize records');
    Assert.areEqual(aiId1, result.lastRecordId, 'Last record should be first (extra removed)');
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withNullCapacityIds_returnsEmpty() {
    RollbackBatchResult result = SERVICE.rollbackAcademicInterestsBatch(null, null, 100);

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(0, result.resetCount, 'Should reset 0 records');
    Assert.isFalse(result.hasMore, 'Should not have more');
  }

  @IsTest
  private static void rollbackAcademicInterestsBatch_withEmptyCapacityIds_returnsEmpty() {
    RollbackBatchResult result = SERVICE.rollbackAcademicInterestsBatch(
      new Set<Id>(),
      null,
      100
    );

    Assert.isTrue(result.isSuccess, 'Should be successful');
    Assert.areEqual(0, result.resetCount, 'Should reset 0 records');
  }
}