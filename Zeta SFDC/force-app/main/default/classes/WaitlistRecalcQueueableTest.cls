/**
 * Tests for {@link WaitlistRecalcQueueable}.
 */
@IsTest(IsParallel=true)
private class WaitlistRecalcQueueableTest {
  private static final WaitlistRecalcServiceMock RECALC_SERVICE_MOCK;
  private static final OfferOptimizerServiceMock OPTIMIZER_SERVICE_MOCK;
  private static final SeatOfferWithdrawalServiceMock WITHDRAWAL_SERVICE_MOCK;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final LotteryCapacityRollupServiceMock ROLLUP_SERVICE_MOCK;
  private static final WaitlistHistoryServiceMock HISTORY_SERVICE_MOCK;

  static {
    RECALC_SERVICE_MOCK = new WaitlistRecalcServiceMock();
    OPTIMIZER_SERVICE_MOCK = new OfferOptimizerServiceMock();
    WITHDRAWAL_SERVICE_MOCK = new SeatOfferWithdrawalServiceMock();
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    ROLLUP_SERVICE_MOCK = new LotteryCapacityRollupServiceMock();
    HISTORY_SERVICE_MOCK = new WaitlistHistoryServiceMock();
  }

  private static void resetAllMocks() {
    RECALC_SERVICE_MOCK.reset();
    OPTIMIZER_SERVICE_MOCK.reset();
    WITHDRAWAL_SERVICE_MOCK.reset();
    DATABASE_REPO_MOCK.reset();
    ROLLUP_SERVICE_MOCK.reset();
    HISTORY_SERVICE_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.setSavepoint()).thenReturn(null);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.rollback()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
  }

  private static WaitlistRecalcQueueable buildQueueable(Set<Id> capacityIds) {
    return buildQueueable(capacityIds, new Map<Id, Integer>());
  }

  private static WaitlistRecalcQueueable buildQueueable(
    Set<Id> capacityIds,
    Map<Id, Integer> seatsOverride
  ) {
    return new WaitlistRecalcQueueable(
      capacityIds,
      RECALC_SERVICE_MOCK,
      OPTIMIZER_SERVICE_MOCK,
      WITHDRAWAL_SERVICE_MOCK,
      DATABASE_REPO_MOCK,
      seatsOverride,
      ROLLUP_SERVICE_MOCK,
      HISTORY_SERVICE_MOCK
    );
  }

  @IsTest
  private static void execute_withNullCapacityIds_exitsEarly() {
    resetAllMocks();

    buildQueueable(null).execute(null);

    RECALC_SERVICE_MOCK.never(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withEmptyCapacityIds_exitsEarly() {
    resetAllMocks();

    buildQueueable(new Set<Id>()).execute(null);

    RECALC_SERVICE_MOCK.never(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    WaitlistRecalcQueueable queueable = new WaitlistRecalcQueueable(new Set<Id>{ capacityId });

    Assert.isNotNull(queueable, 'Should be instantiable');
  }

  @IsTest
  private static void constructor_acceptsSeatsOverride() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    WaitlistRecalcQueueable queueable = new WaitlistRecalcQueueable(
      new Set<Id>{ capacityId },
      new Map<Id, Integer>{ capacityId => 5 }
    );

    Assert.isNotNull(queueable, 'Should be instantiable with seats override');
  }

  @IsTest
  private static void execute_withNoLockedCapacities_exitsEarly() {
    resetAllMocks();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>());
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 1);
    RECALC_SERVICE_MOCK.never(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity());
  }

  @IsTest
  private static void execute_withNoWaitlistedRecords_exitsAfterSecondQuery() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capacityId) })
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 2);
    RECALC_SERVICE_MOCK.never(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity());
  }

  @IsTest
  private static void execute_withWaitlistedRecords_callsRecalcService() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = academicInterestId, Lottery_Capacity__c = capacityId)
    };
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capacityId) })
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    RECALC_SERVICE_MOCK.verify(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity(), 1);
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 2);
  }

  @IsTest
  private static void execute_withChangedRecords_updatesDatabase() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = academicInterestId, Lottery_Capacity__c = capacityId)
    };
    List<AcademicInterest> changedRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = academicInterestId, Waitlist_Position__c = 1)
    };
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capacityId) })
      .thenReturn(waitlistedRecords);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(changedRecords);

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 3);
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<AcademicInterest> updatedRecords = (List<AcademicInterest>) calls[1].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');
    Assert.areEqual(academicInterestId, updatedRecords[0].Id, 'Should update correct record');
  }

  @IsTest
  private static void execute_withAvailableSeats_promotesToPreOfferThenSeatOffered() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId1,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 2,
      IndividualApplicationId = appId2,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai3 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 3,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1, ai2, ai3 };

    AcademicInterest preOffer1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId1,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest preOffer2 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId2,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ preOffer1, preOffer2 });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1, ai2 });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    Assert.areEqual(LotteryConstants.STATUS_PRE_OFFER, ai1.Status, 'Should be Pre-Offer');
    Assert.areEqual(LotteryConstants.STATUS_PRE_OFFER, ai2.Status, 'Should be Pre-Offer');
    Assert.isNull(ai1.Waitlist_Position__c, 'Promoted should have null position');
    Assert.isNull(ai2.Waitlist_Position__c, 'Promoted should have null position');
    Assert.areEqual(WaitlistConstants.STATUS_WAITLISTED, ai3.Status, 'Should stay Waitlisted');
    Assert.areEqual(1, ai3.Waitlist_Position__c, 'Should be renumbered to position 1');
    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      preOffer1.Status,
      'Should be Seat Offered'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      preOffer2.Status,
      'Should be Seat Offered'
    );
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 4);
  }

  @IsTest
  private static void execute_withNoAvailableSeats_onlyReordersPositions() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AcademicInterest ai = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 0 }
          )
        }
      )
      .thenReturn(waitlistedRecords);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 3);
    OPTIMIZER_SERVICE_MOCK.never(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers());
    RECALC_SERVICE_MOCK.never(RECALC_SERVICE_MOCK.method.getRecordsToPromote());
  }

  @IsTest
  private static void execute_withSeatsOverride_usesOverrideValue() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 2,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1, ai2 };

    AcademicInterest preOffer1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 0 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ preOffer1 });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1 });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }, new Map<Id, Integer>{ capacityId => 1 })
      .execute(null);

    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      ai1.Status,
      'Should be promoted via override'
    );
    Assert.isNull(ai1.Waitlist_Position__c, 'Promoted should have null position');
    Assert.areEqual(WaitlistConstants.STATUS_WAITLISTED, ai2.Status, 'Should remain Waitlisted');
    Assert.areEqual(1, ai2.Waitlist_Position__c, 'Should be renumbered to position 1');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 4);
  }

  @IsTest
  private static void execute_callsOptimizerAfterPromotion() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId,
      School_Rank__c = 2,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1 };

    AcademicInterest preOffer1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 2,
      Current_Priority_Group__c = 1
    );
    AcademicInterest preOffer2 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 1 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ preOffer1, preOffer2 });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1 });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    OPTIMIZER_SERVICE_MOCK.verify(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers(), 1);
    List<Map<String, Object>> optimizerCalls = OPTIMIZER_SERVICE_MOCK.getCalls(
      OPTIMIZER_SERVICE_MOCK.method.optimizeOffers()
    );
    List<AcademicInterest> optimizerRecords = (List<AcademicInterest>) optimizerCalls[0]
      .get('records');
    Assert.areEqual(2, optimizerRecords.size(), 'Should receive cross-capacity Pre-Offer records');
  }

  @IsTest
  private static void execute_renumbersRemainingAfterPromotion() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 2,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai3 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 3,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    AcademicInterest ai4 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 4,
      IndividualApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1, ai2, ai3, ai4 };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 2 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1, ai2 });

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    Assert.isNull(ai1.Waitlist_Position__c, 'Promoted should have null position');
    Assert.isNull(ai2.Waitlist_Position__c, 'Promoted should have null position');
    Assert.areEqual(1, ai3.Waitlist_Position__c, 'First remaining should be position 1');
    Assert.areEqual(2, ai4.Waitlist_Position__c, 'Second remaining should be position 2');
  }

  @IsTest
  private static void execute_eligibleRecordsAreIncludedInRecalc() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest waitlistedAi = new AcademicInterest(
      Id = aiId1,
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1
    );
    AcademicInterest eligibleAi = new AcademicInterest(
      Id = aiId2,
      Lottery_Capacity__c = capacityId,
      Status = LotteryConstants.STATUS_ELIGIBLE,
      Waitlist_Position__c = 2
    );
    List<AcademicInterest> allRecords = new List<AcademicInterest>{ waitlistedAi, eligibleAi };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capacityId) })
      .thenReturn(allRecords);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(allRecords);

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    RECALC_SERVICE_MOCK.verify(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity(), 1);
    List<Map<String, Object>> calls = RECALC_SERVICE_MOCK.getCalls(
      RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity()
    );
    List<AcademicInterest> capturedRecords = (List<AcademicInterest>) calls[0].get('records');
    Assert.areEqual(
      2,
      capturedRecords.size(),
      'Should include both Waitlisted and Eligible records'
    );
  }

  @IsTest
  private static void execute_eligibleRecordsPromotedWhenSeatsAvailable() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest eligibleAi = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = LotteryConstants.STATUS_ELIGIBLE,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ eligibleAi };

    AcademicInterest preOffer = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 1 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ preOffer });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ eligibleAi });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    Assert.areEqual(
      LotteryConstants.STATUS_PRE_OFFER,
      eligibleAi.Status,
      'Eligible record should be promoted to Pre-Offer'
    );
    Assert.isNull(eligibleAi.Waitlist_Position__c, 'Promoted should have null position');
    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      preOffer.Status,
      'Should be finalized to Seat Offered'
    );
  }

  @IsTest
  private static void execute_existingSeatOfferedOptimized() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId,
      School_Rank__c = 2,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1 };

    AcademicInterest newPreOffer = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 2,
      Current_Priority_Group__c = 1
    );
    AcademicInterest existingSeatOffered = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_SEAT_OFFERED,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType),
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 1 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ newPreOffer, existingSeatOffered });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1 });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>());

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    OPTIMIZER_SERVICE_MOCK.verify(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers(), 1);
    List<Map<String, Object>> optimizerCalls = OPTIMIZER_SERVICE_MOCK.getCalls(
      OPTIMIZER_SERVICE_MOCK.method.optimizeOffers()
    );
    List<AcademicInterest> optimizerRecords = (List<AcademicInterest>) optimizerCalls[0]
      .get('records');
    Assert.areEqual(
      2,
      optimizerRecords.size(),
      'Should pass both Pre-Offer and existing Seat Offered to optimizer'
    );
  }

  @IsTest
  private static void execute_rescindReasonAlwaysPopulated() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1,
      IndividualApplicationId = appId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai1 };

    AcademicInterest preOffer = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_PRE_OFFER,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = capacityId,
      School_Rank__c = 1,
      Current_Priority_Group__c = 1
    );
    // Simulate a withdrawn record with blank reason
    AcademicInterest withdrawnRecord = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Status = LotteryConstants.STATUS_WITHDRAWN_DECLINED,
      IndividualApplicationId = appId,
      Lottery_Capacity__c = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType),
      School_Rank__c = 2,
      Current_Priority_Group__c = 1,
      Declined_Withdrawn_Reason__c = null
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) ReadOnlySObject.create(
            new Lottery_Capacity__c(Id = capacityId),
            new Map<String, Object>{ 'Remaining_Available_Seats__c' => 1 }
          )
        }
      )
      .thenReturn(waitlistedRecords)
      .thenReturn(new List<AcademicInterest>{ preOffer });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenReturnVoid()
      .thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.getRecordsToPromote())
      .thenReturn(new List<AcademicInterest>{ ai1 });
    OPTIMIZER_SERVICE_MOCK.when(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers())
      .thenReturn(new List<AcademicInterest>());
    WITHDRAWAL_SERVICE_MOCK.when(WITHDRAWAL_SERVICE_MOCK.method.withdrawLowerRankedApplications())
      .thenReturn(new List<AcademicInterest>{ withdrawnRecord });

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    Assert.areEqual(
      'System: Waitlist Recalculation',
      withdrawnRecord.Declined_Withdrawn_Reason__c,
      'Withdrawn/Declined record with blank reason should have default reason populated'
    );
  }

  @IsTest
  private static void execute_withNoPromotions_skipsOptimizerAndSecondDml() {
    resetAllMocks();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    AcademicInterest ai = new AcademicInterest(
      Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
      Lottery_Capacity__c = capacityId,
      Status = WaitlistConstants.STATUS_WAITLISTED,
      Waitlist_Position__c = 1
    );
    List<AcademicInterest> waitlistedRecords = new List<AcademicInterest>{ ai };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capacityId) })
      .thenReturn(waitlistedRecords);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    RECALC_SERVICE_MOCK.when(RECALC_SERVICE_MOCK.method.recalculatePositionsByCapacity())
      .thenReturn(waitlistedRecords);

    buildQueueable(new Set<Id>{ capacityId }).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 3);
    OPTIMIZER_SERVICE_MOCK.never(OPTIMIZER_SERVICE_MOCK.method.optimizeOffers());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 2);
  }
}