/**
 * Tests for {@link LotteryCapacityRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LotteryCapacityRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final LotteryCapacityRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new LotteryCapacityRollupServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void processAggregateResults_withMixedStatuses_calculatesCorrectCounts() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(capacityId, AcademicInterestConstants.STATUS_PRE_OFFER, 5),
      new LotteryCapacityAggregateResult(
        capacityId,
        AcademicInterestConstants.STATUS_SEAT_OFFERED,
        3
      ),
      new LotteryCapacityAggregateResult(
        capacityId,
        AcademicInterestConstants.STATUS_SEAT_ACCEPTED,
        2
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should update one capacity record');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(capacityId, updated.Id, 'Should update the correct capacity record');
    Assert.areEqual(
      8,
      updated.Seats_Offered__c,
      'Seats_Offered__c should be Pre-Offer + Seat Offered (5 + 3)'
    );
    Assert.areEqual(
      2,
      updated.Seats_Accepted__c,
      'Seats_Accepted__c should be Seat Accepted count (2)'
    );
    Assert.areEqual(
      5,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be Pre-Offer count (5)'
    );
    Assert.areEqual(
      0,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be 0 (no Submitted/Eligible/Waitlisted/Applied)'
    );
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsAllCountsToZero() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> emptyResults = new List<LotteryCapacityAggregateResult>();

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, emptyResults);

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should update one capacity record');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(capacityId, updated.Id, 'Should update the correct capacity record');
    Assert.areEqual(0, updated.Seats_Offered__c, 'Seats_Offered__c should be 0');
    Assert.areEqual(0, updated.Seats_Accepted__c, 'Seats_Accepted__c should be 0');
    Assert.areEqual(
      0,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be 0'
    );
    Assert.areEqual(
      0,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be 0'
    );
  }

  @IsTest
  private static void processAggregateResults_withMultipleCapacities_updatesAllRecords() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId1, capacityId2 };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(
        capacityId1,
        AcademicInterestConstants.STATUS_PRE_OFFER,
        3
      ),
      new LotteryCapacityAggregateResult(
        capacityId1,
        AcademicInterestConstants.STATUS_SEAT_OFFERED,
        2
      ),
      new LotteryCapacityAggregateResult(
        capacityId1,
        AcademicInterestConstants.STATUS_SEAT_ACCEPTED,
        1
      ),
      new LotteryCapacityAggregateResult(
        capacityId2,
        AcademicInterestConstants.STATUS_PRE_OFFER,
        7
      ),
      new LotteryCapacityAggregateResult(
        capacityId2,
        AcademicInterestConstants.STATUS_SEAT_ACCEPTED,
        4
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(2, updatedRecords.size(), 'Should update two capacity records');

    Map<Id, Lottery_Capacity__c> updatedById = new Map<Id, Lottery_Capacity__c>();
    for (SObject record : updatedRecords) {
      Lottery_Capacity__c capacity = (Lottery_Capacity__c) record;
      updatedById.put(capacity.Id, capacity);
    }

    Lottery_Capacity__c updated1 = updatedById.get(capacityId1);
    Assert.isNotNull(updated1, 'Should include first capacity in update');
    Assert.areEqual(
      5,
      updated1.Seats_Offered__c,
      'First capacity Seats_Offered__c should be 3 + 2'
    );
    Assert.areEqual(1, updated1.Seats_Accepted__c, 'First capacity Seats_Accepted__c should be 1');
    Assert.areEqual(
      3,
      updated1.Count_of_Pre_Offer_School_Applications__c,
      'First capacity Pre-Offer count should be 3'
    );
    Assert.areEqual(
      0,
      updated1.Total_Applied_Applications__c,
      'First capacity Total_Applied_Applications__c should be 0'
    );

    Lottery_Capacity__c updated2 = updatedById.get(capacityId2);
    Assert.isNotNull(updated2, 'Should include second capacity in update');
    Assert.areEqual(
      7,
      updated2.Seats_Offered__c,
      'Second capacity Seats_Offered__c should be 7 (only Pre-Offer)'
    );
    Assert.areEqual(4, updated2.Seats_Accepted__c, 'Second capacity Seats_Accepted__c should be 4');
    Assert.areEqual(
      7,
      updated2.Count_of_Pre_Offer_School_Applications__c,
      'Second capacity Pre-Offer count should be 7'
    );
    Assert.areEqual(
      0,
      updated2.Total_Applied_Applications__c,
      'Second capacity Total_Applied_Applications__c should be 0'
    );
  }

  @IsTest
  private static void recalculate_withEmptySet_doesNotQuery() {
    Set<Id> emptySet = new Set<Id>();

    SERVICE.recalculate(emptySet);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withNullSet_doesNotQuery() {
    SERVICE.recalculate(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void processAggregateResults_withOnlyPreOfferStatus_calculatesCorrectCounts() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(capacityId, AcademicInterestConstants.STATUS_PRE_OFFER, 10)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(
      10,
      updated.Seats_Offered__c,
      'Seats_Offered__c should equal Pre-Offer count when no Seat Offered records'
    );
    Assert.areEqual(0, updated.Seats_Accepted__c, 'Seats_Accepted__c should be 0');
    Assert.areEqual(
      10,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be 10'
    );
    Assert.areEqual(
      0,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be 0'
    );
  }

  @IsTest
  private static void processAggregateResults_withOnlySeatOfferedStatus_calculatesCorrectCounts() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(
        capacityId,
        AcademicInterestConstants.STATUS_SEAT_OFFERED,
        6
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(
      6,
      updated.Seats_Offered__c,
      'Seats_Offered__c should equal Seat Offered count'
    );
    Assert.areEqual(0, updated.Seats_Accepted__c, 'Seats_Accepted__c should be 0');
    Assert.areEqual(
      0,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be 0'
    );
    Assert.areEqual(
      0,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be 0'
    );
  }

  @IsTest
  private static void processAggregateResults_withOnlySeatAcceptedStatus_calculatesCorrectCounts() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(
        capacityId,
        AcademicInterestConstants.STATUS_SEAT_ACCEPTED,
        4
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(
      0,
      updated.Seats_Offered__c,
      'Seats_Offered__c should be 0 when only Seat Accepted records exist'
    );
    Assert.areEqual(4, updated.Seats_Accepted__c, 'Seats_Accepted__c should be 4');
    Assert.areEqual(
      0,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be 0'
    );
    Assert.areEqual(
      0,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be 0'
    );
  }

  @IsTest
  private static void recalculate_withValidIds_queriesAndProcesses() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId1, capacityId2 };

    List<AggregateResult> mockResults = new List<AggregateResult>();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockResults);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(capacityIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, updatedRecords.size(), 'Should update both capacity records');
  }

  @IsTest
  private static void processAggregateResults_withAppliedStatuses_calculatesTotalApplied() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<LotteryCapacityAggregateResult> wrappedResults = new List<LotteryCapacityAggregateResult>{
      new LotteryCapacityAggregateResult(capacityId, 'Submitted', 4),
      new LotteryCapacityAggregateResult(capacityId, 'Eligible', 3),
      new LotteryCapacityAggregateResult(capacityId, 'Waitlisted', 2),
      new LotteryCapacityAggregateResult(capacityId, 'Applied', 6),
      new LotteryCapacityAggregateResult(capacityId, AcademicInterestConstants.STATUS_PRE_OFFER, 5)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(capacityIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Lottery_Capacity__c updated = (Lottery_Capacity__c) updatedRecords[0];
    Assert.areEqual(
      15,
      updated.Total_Applied_Applications__c,
      'Total_Applied_Applications__c should be Submitted + Eligible + Waitlisted + Applied (4 + 3 + 2 + 6)'
    );
    Assert.areEqual(
      5,
      updated.Seats_Offered__c,
      'Seats_Offered__c should be Pre-Offer count (unaffected by applied statuses)'
    );
    Assert.areEqual(0, updated.Seats_Accepted__c, 'Seats_Accepted__c should be 0');
    Assert.areEqual(
      5,
      updated.Count_of_Pre_Offer_School_Applications__c,
      'Count_of_Pre_Offer_School_Applications__c should be Pre-Offer count'
    );
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    LotteryCapacityRollupServiceImpl service = new LotteryCapacityRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }

  @IsTest
  private static void recalculate_withBypassEnabled_skipsProcessing() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    LotteryCapacityRollupServiceImpl.enableBypass();
    try {
      SERVICE.recalculate(capacityIds);

      MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
      MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
    } finally {
      LotteryCapacityRollupServiceImpl.disableBypass();
    }
  }

  @IsTest
  private static void bypass_canBeEnabledAndDisabled() {
    Assert.isFalse(
      LotteryCapacityRollupServiceImpl.isBypassEnabled(),
      'Bypass should be disabled by default'
    );

    LotteryCapacityRollupServiceImpl.enableBypass();
    Assert.isTrue(
      LotteryCapacityRollupServiceImpl.isBypassEnabled(),
      'Bypass should be enabled after enableBypass()'
    );

    LotteryCapacityRollupServiceImpl.disableBypass();
    Assert.isFalse(
      LotteryCapacityRollupServiceImpl.isBypassEnabled(),
      'Bypass should be disabled after disableBypass()'
    );
  }

  @IsTest
  private static void recalculate_afterBypassDisabled_resumesNormalProcessing() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Set<Id> capacityIds = new Set<Id>{ capacityId };

    List<AggregateResult> mockResults = new List<AggregateResult>();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockResults);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    // Enable then disable bypass
    LotteryCapacityRollupServiceImpl.enableBypass();
    LotteryCapacityRollupServiceImpl.disableBypass();

    SERVICE.recalculate(capacityIds);

    // Should process normally after bypass is disabled
    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
  }
}