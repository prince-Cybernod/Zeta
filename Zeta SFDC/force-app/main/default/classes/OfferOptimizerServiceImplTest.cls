/**
 * Tests for {@link OfferOptimizerServiceImpl}.
 */
@IsTest(IsParallel=true)
private class OfferOptimizerServiceImplTest {
  private static final OfferOptimizerServiceImpl SERVICE = new OfferOptimizerServiceImpl();
  private static final String STATUS_PRE_OFFER = LotteryConstants.STATUS_PRE_OFFER;
  private static final String STATUS_RESCINDED_OPTIMIZATION = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION;

  @IsTest
  private static void optimizeOffers_withNullInput_returnsEmptyList() {
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(null, transitions);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
  }

  @IsTest
  private static void optimizeOffers_withEmptyList_returnsEmptyList() {
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(
      new List<AcademicInterest>(),
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void optimizeOffers_withNoPreOfferRecords_returnsEmptyList() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 1, 'Eligible'),
      createRecord(appId, 2, 'Waitlisted')
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.isTrue(result.isEmpty(), 'Should return empty list when no Pre-Offer records');
  }

  @IsTest
  private static void optimizeOffers_withSinglePreOffer_returnsEmptyList() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 1, STATUS_PRE_OFFER)
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.isTrue(
      result.isEmpty(),
      'Should return empty list for single pre-offer (no rescission needed)'
    );
  }

  @IsTest
  private static void optimizeOffers_withTwoPreOffers_rescindLowerRanked() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 1, STATUS_PRE_OFFER), // Best ranked (rank 1)
      createRecord(appId, 2, STATUS_PRE_OFFER) // Lower ranked (rank 2) - should be rescinded
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.areEqual(2, result[0].School_Rank__c, 'Should rescind the rank 2 school');
    Assert.areEqual(
      STATUS_RESCINDED_OPTIMIZATION,
      result[0].Rescinded_Reason__c,
      'Should set rescinded reason'
    );
    Assert.areEqual(STATUS_RESCINDED_OPTIMIZATION, result[0].Status, 'Should set rescinded status');
  }

  @IsTest
  private static void optimizeOffers_withThreePreOffers_rescindTwoLowerRanked() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 3, STATUS_PRE_OFFER), // Rank 3 - rescind
      createRecord(appId, 1, STATUS_PRE_OFFER), // Rank 1 - keep
      createRecord(appId, 2, STATUS_PRE_OFFER) // Rank 2 - rescind
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(2, result.size(), 'Should rescind two records');

    Set<Decimal> rescindedRanks = new Set<Decimal>();
    for (AcademicInterest record : result) {
      rescindedRanks.add(record.School_Rank__c);
      Assert.areEqual(
        STATUS_RESCINDED_OPTIMIZATION,
        record.Rescinded_Reason__c,
        'Should set rescinded reason'
      );
      Assert.areEqual(STATUS_RESCINDED_OPTIMIZATION, record.Status, 'Should set rescinded status');
    }
    Assert.isTrue(rescindedRanks.contains(2), 'Rank 2 should be rescinded');
    Assert.isTrue(rescindedRanks.contains(3), 'Rank 3 should be rescinded');
    Assert.isFalse(rescindedRanks.contains(1), 'Rank 1 should NOT be rescinded');
  }

  @IsTest
  private static void optimizeOffers_keepsBestRankedSchool() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    AcademicInterest bestRanked = createRecord(appId, 1, STATUS_PRE_OFFER);
    AcademicInterest lowerRanked = createRecord(appId, 5, STATUS_PRE_OFFER);

    List<AcademicInterest> records = new List<AcademicInterest>{ lowerRanked, bestRanked };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.areEqual(5, result[0].School_Rank__c, 'Should rescind rank 5, keep rank 1');
  }

  @IsTest
  private static void optimizeOffers_handlesMultipleApplicationsSeparately() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId1, 1, STATUS_PRE_OFFER),
      createRecord(appId1, 2, STATUS_PRE_OFFER), // Rescind for app1
      createRecord(appId2, 1, STATUS_PRE_OFFER),
      createRecord(appId2, 3, STATUS_PRE_OFFER) // Rescind for app2
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(2, result.size(), 'Should rescind one record per application');
  }

  @IsTest
  private static void optimizeOffers_singlePreOfferPerApplication_noRescission() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId1, 1, STATUS_PRE_OFFER),
      createRecord(appId2, 1, STATUS_PRE_OFFER)
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.isTrue(result.isEmpty(), 'No rescission when each app has only one pre-offer');
  }

  @IsTest
  private static void optimizeOffers_ignoresRecordsWithNullApplicationId() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(null, 1, STATUS_PRE_OFFER), // No application ID
      createRecord(null, 2, STATUS_PRE_OFFER), // No application ID
      createRecord(appId, 1, STATUS_PRE_OFFER) // Has application ID
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.isTrue(result.isEmpty(), 'Should not rescind records without application ID');
  }

  @IsTest
  private static void optimizeOffers_sameRank_usesLotteryNumberAsTieBreaker() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    AcademicInterest lowerLottery = createRecordWithLotteryNumber(appId, 1, STATUS_PRE_OFFER, 100);
    AcademicInterest higherLottery = createRecordWithLotteryNumber(appId, 1, STATUS_PRE_OFFER, 500);

    List<AcademicInterest> records = new List<AcademicInterest>{ higherLottery, lowerLottery };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.areEqual(
      500,
      result[0].Randomized_Sort_Key__c,
      'Should rescind higher lottery number (keep lower)'
    );
  }

  @IsTest
  private static void optimizeOffers_nullSchoolRank_sortsLast() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    AcademicInterest withRank = createRecord(appId, 5, STATUS_PRE_OFFER);
    AcademicInterest nullRank = createRecord(appId, null, STATUS_PRE_OFFER);

    List<AcademicInterest> records = new List<AcademicInterest>{ nullRank, withRank };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.isNull(result[0].School_Rank__c, 'Should rescind record with null rank');
  }

  @IsTest
  private static void optimizeOffers_mixedStatuses_onlyProcessesPreOffers() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 1, STATUS_PRE_OFFER),
      createRecord(appId, 2, STATUS_PRE_OFFER),
      createRecord(appId, 3, 'Eligible'), // Not Pre-Offer - ignored
      createRecord(appId, 4, 'Waitlisted') // Not Pre-Offer - ignored
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should only rescind from Pre-Offer records');
    Assert.areEqual(2, result[0].School_Rank__c, 'Should rescind rank 2 Pre-Offer');
  }

  @IsTest
  private static void optimizeOffers_capturesRescissionTransition() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest bestRanked = createRecord(appId, 1, STATUS_PRE_OFFER);
    AcademicInterest toRescind = new AcademicInterest(
      Id = recordId,
      IndividualApplicationId = appId,
      School_Rank__c = 2,
      Status = STATUS_PRE_OFFER
    );

    List<AcademicInterest> records = new List<AcademicInterest>{ bestRanked, toRescind };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, transitions.size(), 'Should capture one transition');
    LotteryStatusChange transition = transitions[0];
    Assert.areEqual(recordId, transition.recordId, 'Transition should have correct record ID');
    Assert.areEqual(
      STATUS_PRE_OFFER,
      transition.fromStatus,
      'Should capture Pre-Offer as fromStatus'
    );
    Assert.areEqual(
      STATUS_RESCINDED_OPTIMIZATION,
      transition.toStatus,
      'Should capture rescinded status as toStatus'
    );
    Assert.areEqual(
      LotteryConstants.TRANSITION_REASON_SEAT_OPTIMIZATION,
      transition.reason,
      'Should have SEAT_OPTIMIZATION reason'
    );
  }

  @IsTest
  private static void optimizeOffers_seatOfferedRecordsIncludedInOptimization() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(appId, 1, STATUS_PRE_OFFER),
      createRecord(appId, 2, LotteryConstants.STATUS_SEAT_OFFERED)
    };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record when both offer types present');
    Assert.areEqual(
      2,
      result[0].School_Rank__c,
      'Should rescind the lower-ranked Seat Offered record'
    );
  }

  @IsTest
  private static void optimizeOffers_bestRankedSeatOfferedKept() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    AcademicInterest seatOffered = createRecord(appId, 1, LotteryConstants.STATUS_SEAT_OFFERED);
    AcademicInterest preOffer = createRecord(appId, 2, STATUS_PRE_OFFER);
    List<AcademicInterest> records = new List<AcademicInterest>{ preOffer, seatOffered };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.areEqual(2, result[0].School_Rank__c, 'Should rescind Pre-Offer at rank 2');
    Assert.areEqual(
      STATUS_RESCINDED_OPTIMIZATION,
      result[0].Status,
      'Rescinded record should have optimization status'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      seatOffered.Status,
      'Seat Offered at rank 1 should be kept'
    );
  }

  @IsTest
  private static void optimizeOffers_newPreOfferBeatsExistingSeatOffered() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    AcademicInterest preOffer = createRecord(appId, 1, STATUS_PRE_OFFER);
    AcademicInterest seatOffered = createRecord(appId, 2, LotteryConstants.STATUS_SEAT_OFFERED);
    List<AcademicInterest> records = new List<AcademicInterest>{ seatOffered, preOffer };
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.optimizeOffers(records, transitions);

    Assert.areEqual(1, result.size(), 'Should rescind one record');
    Assert.areEqual(2, result[0].School_Rank__c, 'Should rescind Seat Offered at rank 2');
    Assert.areEqual(
      STATUS_RESCINDED_OPTIMIZATION,
      result[0].Status,
      'Rescinded record should have optimization status'
    );
    Assert.areEqual(
      STATUS_RESCINDED_OPTIMIZATION,
      result[0].Rescinded_Reason__c,
      'Should set rescinded reason'
    );
    Assert.areEqual(STATUS_PRE_OFFER, preOffer.Status, 'Pre-Offer at rank 1 should be kept');
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    OfferOptimizerServiceImpl instance = new OfferOptimizerServiceImpl();

    Assert.isNotNull(instance, 'Service should be instantiable');
  }

  private static AcademicInterest createRecord(
    Id applicationId,
    Decimal schoolRank,
    String status
  ) {
    return new AcademicInterest(
      IndividualApplicationId = applicationId,
      School_Rank__c = schoolRank,
      Status = status
    );
  }

  private static AcademicInterest createRecordWithLotteryNumber(
    Id applicationId,
    Decimal schoolRank,
    String status,
    Decimal lotteryNumber
  ) {
    return new AcademicInterest(
      IndividualApplicationId = applicationId,
      School_Rank__c = schoolRank,
      Status = status,
      Randomized_Sort_Key__c = lotteryNumber
    );
  }
}