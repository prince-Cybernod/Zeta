/**
 * Tests for {@link LotteryOrchestrationServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LotteryOrchestrationServiceImplTest {
  private static final LotteryOrchestrationServiceImpl SERVICE;
  private static final LotterySortServiceMock SORT_MOCK;
  private static final OfferOptimizerServiceMock OPTIMIZER_MOCK;
  private static final SeatOfferWithdrawalServiceMock WITHDRAWAL_MOCK;
  private static final DatabaseRepoMock DB_MOCK;
  private static final EventBusRepoMock EVENT_BUS_MOCK;

  static {
    SORT_MOCK = new LotterySortServiceMock();
    OPTIMIZER_MOCK = new OfferOptimizerServiceMock();
    WITHDRAWAL_MOCK = new SeatOfferWithdrawalServiceMock();
    DB_MOCK = new DatabaseRepoMock();
    EVENT_BUS_MOCK = new EventBusRepoMock();
    SERVICE = new LotteryOrchestrationServiceImpl(
      SORT_MOCK,
      OPTIMIZER_MOCK,
      WITHDRAWAL_MOCK,
      DB_MOCK,
      EVENT_BUS_MOCK
    );
  }

  @IsTest
  private static void runLottery_withNullInput_returnsEmptyResult() {
    LotteryRunResult result = SERVICE.runLottery(null);

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.totalEligible, 'Total eligible should be 0');
    Assert.areEqual(0, result.preOffersAssigned, 'Pre-offers assigned should be 0');
    Assert.areEqual(0, result.offersRescinded, 'Offers rescinded should be 0');
    Assert.areEqual(0, result.waitlisted, 'Waitlisted should be 0');
    Assert.isTrue(result.isSuccess, 'Should be success');
  }

  @IsTest
  private static void runLottery_withEmptySet_returnsEmptyResult() {
    LotteryRunResult result = SERVICE.runLottery(new Set<Id>());

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.totalEligible, 'Total eligible should be 0');
    Assert.isTrue(result.isSuccess, 'Should be success');
  }

  @IsTest
  private static void lotteryRunResult_defaultValues_areCorrect() {
    LotteryRunResult result = new LotteryRunResult();

    Assert.areEqual(0, result.totalEligible, 'Default totalEligible should be 0');
    Assert.areEqual(0, result.preOffersAssigned, 'Default preOffersAssigned should be 0');
    Assert.areEqual(0, result.offersRescinded, 'Default offersRescinded should be 0');
    Assert.areEqual(0, result.waitlisted, 'Default waitlisted should be 0');
    Assert.isNotNull(result.capacitiesProcessed, 'capacitiesProcessed should not be null');
    Assert.isTrue(result.capacitiesProcessed.isEmpty(), 'capacitiesProcessed should be empty');
    Assert.isTrue(result.isSuccess, 'Default isSuccess should be true');
    Assert.isNull(result.errorMessage, 'Default errorMessage should be null');
    Assert.areEqual(0, result.withdrawnCount, 'Default withdrawnCount should be 0');
  }

  @IsTest
  private static void constructor_default_canBeInstantiated() {
    LotteryOrchestrationServiceImpl instance = new LotteryOrchestrationServiceImpl();

    Assert.isNotNull(instance, 'Service should be instantiable');
  }

  @IsTest
  private static void runLottery_withNoMatchingCapacities_returnsEmptyResult() {
    Id fakeCapacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>())
      .thenReturn(new List<AcademicInterest>());

    LotteryRunResult result = SERVICE.runLottery(new Set<Id>{ fakeCapacityId });

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.totalEligible, 'Total eligible should be 0 (no matching records)');
    Assert.isTrue(result.isSuccess, 'Should be success even with no matches');
  }

  @IsTest
  private static void runLottery_withEligibleRecords_assignsPreOffers() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 10),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 3 }
    );

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 5; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1,
          Randomized_Sort_Key__c = i * 100
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder()).thenReturn(eligibleRecords);
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    LotteryRunResult result = SERVICE.runLottery(new Set<Id>{ capacityId });

    Assert.isTrue(result.isSuccess, 'Lottery run should succeed');
    Assert.areEqual(5, result.totalEligible, 'Should have 5 eligible records');
    Assert.areEqual(
      3,
      result.preOffersAssigned,
      'Should assign 3 pre-offers (limited by capacity)'
    );
    Assert.areEqual(2, result.waitlisted, 'Should waitlist 2 remaining students');
    Assert.areEqual(0, result.offersRescinded, 'No offers should be rescinded');
    Assert.areEqual(1, result.capacitiesProcessed.size(), 'Should process 1 capacity');
    SORT_MOCK.verify(SORT_MOCK.method.assignRandomizedSortKeys());
    SORT_MOCK.verify(SORT_MOCK.method.sortByLotteryOrder());
    OPTIMIZER_MOCK.verify(OPTIMIZER_MOCK.method.optimizeOffers());
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
    EVENT_BUS_MOCK.verify(EVENT_BUS_MOCK.method.publishList());
  }

  @IsTest
  private static void runLottery_withMultipleCapacities_processesAll() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<Lottery_Capacity__c> capacities = new List<Lottery_Capacity__c>{
      (Lottery_Capacity__c) ReadOnlySObject.create(
        new Lottery_Capacity__c(Id = capacityId1, Grade__c = 'K', Total_Available_Seats__c = 5),
        new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
      ),
      (Lottery_Capacity__c) ReadOnlySObject.create(
        new Lottery_Capacity__c(Id = capacityId2, Grade__c = '1', Total_Available_Seats__c = 5),
        new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
      )
    };

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_ELIGIBLE,
        Lottery_Capacity__c = capacityId1,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      ),
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_ELIGIBLE,
        Lottery_Capacity__c = capacityId1,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 200
      ),
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_ELIGIBLE,
        Lottery_Capacity__c = capacityId1,
        Current_Priority_Group__c = 2,
        Randomized_Sort_Key__c = 300
      ),
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_ELIGIBLE,
        Lottery_Capacity__c = capacityId2,
        Current_Priority_Group__c = 1,
        Randomized_Sort_Key__c = 100
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(capacities)
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder())
      .thenReturn(
        new List<AcademicInterest>{ eligibleRecords[0], eligibleRecords[1], eligibleRecords[2] }
      )
      .thenReturn(new List<AcademicInterest>{ eligibleRecords[3] });
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    LotteryRunResult result = SERVICE.runLottery(new Set<Id>{ capacityId1, capacityId2 });

    Assert.isTrue(result.isSuccess, 'Lottery run should succeed');
    Assert.areEqual(4, result.totalEligible, 'Should have 4 total eligible records');
    Assert.areEqual(3, result.preOffersAssigned, 'Should assign 3 pre-offers (2 + 1)');
    Assert.areEqual(1, result.waitlisted, 'Should waitlist 1 student');
    Assert.areEqual(2, result.capacitiesProcessed.size(), 'Should process 2 capacities');
  }

  @IsTest
  private static void runLottery_withOfferOptimization_reportsRescindedOffers() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 5),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 3 }
    );

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1,
          Randomized_Sort_Key__c = i * 100
        )
      );
    }

    List<AcademicInterest> rescindedOffers = new List<AcademicInterest>{
      new AcademicInterest(
        Id = eligibleRecords[0].Id,
        Status = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder()).thenReturn(eligibleRecords);
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers()).thenReturn(rescindedOffers);
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    LotteryRunResult result = SERVICE.runLottery(new Set<Id>{ capacityId });

    Assert.isTrue(result.isSuccess, 'Lottery run should succeed');
    Assert.areEqual(3, result.totalEligible, 'Should have 3 eligible records');
    Assert.areEqual(3, result.preOffersAssigned, 'Should assign 3 pre-offers');
    Assert.areEqual(1, result.offersRescinded, 'Should report 1 rescinded offer');
    Assert.areEqual(0, result.waitlisted, 'No waitlisted (all got pre-offers initially)');
  }

  @IsTest
  private static void runLottery_withEligibleRecords_capturesTransitions() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 10),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
    );

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 4; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1,
          Randomized_Sort_Key__c = i * 100
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder()).thenReturn(eligibleRecords);
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    LotteryRunResult result = SERVICE.runLottery(new Set<Id>{ capacityId });

    Assert.isTrue(result.isSuccess, 'Lottery run should succeed');
    Assert.isNotNull(result.transitions, 'Transitions should not be null');
    Assert.areEqual(
      4,
      result.transitions.size(),
      'Should capture 4 transitions (2 pre-offers + 2 waitlisted)'
    );

    // Verify pre-offer transitions
    Integer preOfferTransitions = 0;
    Integer waitlistTransitions = 0;
    for (LotteryStatusChange transition : result.transitions) {
      Assert.areEqual(
        LotteryConstants.STATUS_ELIGIBLE,
        transition.fromStatus,
        'All transitions should start from Eligible'
      );
      if (transition.toStatus == LotteryConstants.STATUS_PRE_OFFER) {
        preOfferTransitions++;
        Assert.areEqual(
          LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER,
          transition.reason,
          'Pre-offer transition should have LOTTERY_OFFER reason'
        );
      } else if (transition.toStatus == LotteryConstants.STATUS_WAITLISTED) {
        waitlistTransitions++;
        Assert.areEqual(
          LotteryConstants.TRANSITION_REASON_NO_SEATS,
          transition.reason,
          'Waitlist transition should have NO_SEATS_AVAILABLE reason'
        );
      }
    }
    Assert.areEqual(2, preOfferTransitions, 'Should have 2 pre-offer transitions');
    Assert.areEqual(2, waitlistTransitions, 'Should have 2 waitlist transitions');
  }

  // ==================== Step Method Tests ====================

  @IsTest
  private static void randomizeApplications_withNullInput_returnsZero() {
    Integer count = SERVICE.randomizeApplications(null, null, null);

    Assert.areEqual(0, count, 'Should return 0 for null input');
  }

  @IsTest
  private static void randomizeApplications_withEmptySet_returnsZero() {
    Integer count = SERVICE.randomizeApplications(new Set<Id>(), null, null);

    Assert.areEqual(0, count, 'Should return 0 for empty set');
  }

  @IsTest
  private static void randomizeApplications_withEligibleRecords_assignsKeysAndCommits() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();

    Integer count = SERVICE.randomizeApplications(new Set<Id>{ capacityId }, null, null);

    Assert.areEqual(3, count, 'Should return count of records processed');
    SORT_MOCK.verify(SORT_MOCK.method.assignRandomizedSortKeys());
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void assignPreOffers_withNullInput_returnsEmptyResult() {
    AssignPreOffersResult result = SERVICE.assignPreOffers(null, null, null);

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.preOfferCount, 'preOfferCount should be 0');
    Assert.isTrue(result.isSuccess, 'Should be success');
  }

  @IsTest
  private static void assignPreOffers_withEligibleRecords_assignsOffersAndCommits() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 5),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
    );

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 4; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1,
          Randomized_Sort_Key__c = i * 100
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder()).thenReturn(eligibleRecords);

    AssignPreOffersResult result = SERVICE.assignPreOffers(new Set<Id>{ capacityId }, null, null);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(2, result.preOfferCount, 'Should assign 2 pre-offers (limited by capacity)');
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void optimizeOffers_withNullRunLogId_returnsEmptyResult() {
    OptimizeOffersResult result = SERVICE.optimizeOffers(null);

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.rescindedCount, 'rescindedCount should be 0');
    Assert.isTrue(result.isSuccess, 'Should be success');
  }

  @IsTest
  private static void optimizeOffers_withPreOfferRecords_optimizesAndCommits() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<Lottery_Capacity__c> capacities = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId)
    };

    List<AcademicInterest> preOfferRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      preOfferRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_PRE_OFFER,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    List<AcademicInterest> rescindedRecords = new List<AcademicInterest>{ preOfferRecords[0] };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(capacities)
      .thenReturn(preOfferRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers()).thenReturn(rescindedRecords);
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    OptimizeOffersResult result = SERVICE.optimizeOffers(runLogId);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(1, result.rescindedCount, 'Should rescind 1 offer');
    OPTIMIZER_MOCK.verify(OPTIMIZER_MOCK.method.optimizeOffers());
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void finalizeLottery_withNullInput_returnsEmptyResult() {
    FinalizeResult result = SERVICE.finalizeLottery(null, null);

    Assert.isNotNull(result, 'Result should not be null');
    Assert.areEqual(0, result.waitlistCount, 'waitlistCount should be 0');
    Assert.areEqual(0, result.eventsPublished, 'eventsPublished should be 0');
    Assert.isTrue(result.isSuccess, 'Should be success');
  }

  @IsTest
  private static void finalizeLottery_withEligibleRecords_waitlistsAndPublishesEvents() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    FinalizeResult result = SERVICE.finalizeLottery(new Set<Id>{ capacityId }, runLogId);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(3, result.waitlistCount, 'Should waitlist 3 students');
    Assert.areEqual(1, result.eventsPublished, 'Should publish 1 event');
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
    EVENT_BUS_MOCK.verify(EVENT_BUS_MOCK.method.publishList());
  }

  // ==================== Batch Method Tests ====================

  // --- randomizeApplicationsBatch ---

  @IsTest
  private static void randomizeApplicationsBatch_withRecords_returnsProcessedResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();

    RandomizeBatchResult result = SERVICE.randomizeApplicationsBatch(
      new Set<Id>{ capacityId },
      null,
      null,
      null,
      5
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(3, result.processedCount, 'Should process 3 records');
    Assert.areEqual(
      eligibleRecords[2].Id,
      result.lastRecordId,
      'lastRecordId should be last record in batch'
    );
    Assert.isFalse(result.hasMore, 'hasMore should be false when records < batchSize');
    SORT_MOCK.verify(SORT_MOCK.method.assignRandomizedSortKeys());
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void randomizeApplicationsBatch_withFullBatch_setsHasMoreTrue() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Integer batchSize = 3;

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < batchSize; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.assignRandomizedSortKeys()).thenReturnVoid();

    RandomizeBatchResult result = SERVICE.randomizeApplicationsBatch(
      new Set<Id>{ capacityId },
      null,
      null,
      null,
      batchSize
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.isTrue(result.hasMore, 'hasMore should be true when records == batchSize');
    Assert.areEqual(batchSize, result.processedCount, 'Should process batchSize records');
  }

  @IsTest
  private static void randomizeApplicationsBatch_withNoRecords_returnsEmptyResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(new List<AcademicInterest>());

    RandomizeBatchResult result = SERVICE.randomizeApplicationsBatch(
      new Set<Id>{ capacityId },
      null,
      null,
      null,
      5
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.processedCount, 'processedCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
    Assert.isNull(result.lastRecordId, 'lastRecordId should be null');
  }

  @IsTest
  private static void randomizeApplicationsBatch_withNullInput_returnsEmptyResult() {
    RandomizeBatchResult result = SERVICE.randomizeApplicationsBatch(null, null, null, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.processedCount, 'processedCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
  }

  // --- assignPreOffersBatch ---

  @IsTest
  private static void assignPreOffersBatch_withRecords_assignsOffersAndReturnsCursor() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 10),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 5 }
    );

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1,
          Randomized_Sort_Key__c = i * 100
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    SORT_MOCK.when(SORT_MOCK.method.sortByLotteryOrder()).thenReturn(eligibleRecords);

    AssignPreOffersResult result = SERVICE.assignPreOffersBatch(
      new Set<Id>{ capacityId },
      null,
      null,
      null,
      5
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(3, result.preOfferCount, 'Should assign 3 pre-offers (within capacity)');
    Assert.areEqual(
      eligibleRecords[2].Id,
      result.lastRecordId,
      'lastRecordId should be last record in batch'
    );
    Assert.isFalse(result.hasMore, 'hasMore should be false when records < batchSize');
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void assignPreOffersBatch_withNoRecords_returnsEmptyResult() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Lottery_Capacity__c capacity = (Lottery_Capacity__c) ReadOnlySObject.create(
      new Lottery_Capacity__c(Id = capacityId, Grade__c = 'K', Total_Available_Seats__c = 10),
      new Map<String, Object>{ 'Remaining_Available_Seats__c' => 5 }
    );

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ capacity })
      .thenReturn(new List<AcademicInterest>());

    AssignPreOffersResult result = SERVICE.assignPreOffersBatch(
      new Set<Id>{ capacityId },
      null,
      null,
      null,
      5
    );

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.preOfferCount, 'preOfferCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
    Assert.isNull(result.lastRecordId, 'lastRecordId should be null');
  }

  @IsTest
  private static void assignPreOffersBatch_withNullInput_returnsEmptyResult() {
    AssignPreOffersResult result = SERVICE.assignPreOffersBatch(null, null, null, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.preOfferCount, 'preOfferCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
  }

  // --- optimizeOffersBatch ---

  @IsTest
  private static void optimizeOffersBatch_withRecords_optimizesAndReturnsCursor() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<Lottery_Capacity__c> capacities = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId)
    };

    List<AcademicInterest> preOfferRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      preOfferRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_PRE_OFFER,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    List<AcademicInterest> rescindedRecords = new List<AcademicInterest>{ preOfferRecords[0] };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(capacities)
      .thenReturn(preOfferRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    OPTIMIZER_MOCK.when(OPTIMIZER_MOCK.method.optimizeOffers()).thenReturn(rescindedRecords);
    WITHDRAWAL_MOCK.when(WITHDRAWAL_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    OptimizeOffersResult result = SERVICE.optimizeOffersBatch(runLogId, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(1, result.rescindedCount, 'Should rescind 1 offer');
    Assert.areEqual(
      preOfferRecords[2].Id,
      result.lastRecordId,
      'lastRecordId should be last record in batch'
    );
    Assert.isFalse(result.hasMore, 'hasMore should be false when records < batchSize');
    OPTIMIZER_MOCK.verify(OPTIMIZER_MOCK.method.optimizeOffers());
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void optimizeOffersBatch_withNoPreOfferRecords_returnsEmptyResult() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<Lottery_Capacity__c> capacities = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId)
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds())
      .thenReturn(capacities)
      .thenReturn(new List<AcademicInterest>());

    OptimizeOffersResult result = SERVICE.optimizeOffersBatch(runLogId, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.rescindedCount, 'rescindedCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
    Assert.isNull(result.lastRecordId, 'lastRecordId should be null');
  }

  @IsTest
  private static void optimizeOffersBatch_withNullRunLogId_returnsEmptyResult() {
    OptimizeOffersResult result = SERVICE.optimizeOffersBatch(null, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.rescindedCount, 'rescindedCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
  }

  // --- finalizeLotteryBatch ---

  @IsTest
  private static void finalizeLotteryBatch_withRecords_waitlistsAndReturnsCursor() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Integer batchSize = 5;

    List<AcademicInterest> eligibleRecords = new List<AcademicInterest>();
    for (Integer i = 0; i < 3; i++) {
      eligibleRecords.add(
        new AcademicInterest(
          Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId,
          Current_Priority_Group__c = 1
        )
      );
    }

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(eligibleRecords);
    DB_MOCK.when(DB_MOCK.method.updateSObjects()).thenReturnVoid();
    // Bypass rollup so the non-injected LotteryCapacityRollupServiceImpl
    // doesn't attempt real DML against the org
    LotteryCapacityRollupServiceImpl.enableBypass();
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    FinalizeResult result = SERVICE.finalizeLotteryBatch(
      new Set<Id>{ capacityId },
      runLogId,
      null,
      batchSize
    );

    LotteryCapacityRollupServiceImpl.disableBypass();

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(3, result.waitlistCount, 'Should waitlist 3 students');
    Assert.areEqual(
      eligibleRecords[2].Id,
      result.lastRecordId,
      'lastRecordId should be last record in batch'
    );
    Assert.isFalse(result.hasMore, 'hasMore should be false when records < batchSize');
    // When hasMore is false, events are published and rollup runs
    Assert.areEqual(1, result.eventsPublished, 'Should publish 1 event on final batch');
    DB_MOCK.verify(DB_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void finalizeLotteryBatch_withNoRecords_publishesEventsAndReturnsEmpty() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(new List<AcademicInterest>());
    // Bypass rollup so the non-injected LotteryCapacityRollupServiceImpl
    // doesn't attempt real DML against the org
    LotteryCapacityRollupServiceImpl.enableBypass();
    EVENT_BUS_MOCK.when(EVENT_BUS_MOCK.method.publishList())
      .thenReturn(new List<Database.SaveResult>());

    FinalizeResult result = SERVICE.finalizeLotteryBatch(
      new Set<Id>{ capacityId },
      runLogId,
      null,
      5
    );

    LotteryCapacityRollupServiceImpl.disableBypass();

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.waitlistCount, 'waitlistCount should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
    Assert.areEqual(1, result.eventsPublished, 'Should publish events on empty (final) batch');
    EVENT_BUS_MOCK.verify(EVENT_BUS_MOCK.method.publishList());
  }

  @IsTest
  private static void finalizeLotteryBatch_withNullInput_returnsEmptyResult() {
    FinalizeResult result = SERVICE.finalizeLotteryBatch(null, null, null, 5);

    Assert.isTrue(result.isSuccess, 'Should succeed');
    Assert.areEqual(0, result.waitlistCount, 'waitlistCount should be 0');
    Assert.areEqual(0, result.eventsPublished, 'eventsPublished should be 0');
    Assert.isFalse(result.hasMore, 'hasMore should be false');
  }
}