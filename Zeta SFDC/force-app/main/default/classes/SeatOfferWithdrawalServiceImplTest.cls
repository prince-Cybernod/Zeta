/**
 * Tests for {@link SeatOfferWithdrawalServiceImpl}.
 */
@IsTest(IsParallel=true)
private class SeatOfferWithdrawalServiceImplTest {
  private static final SeatOfferWithdrawalServiceImpl SERVICE;
  private static final DatabaseRepoMock DB_MOCK;

  static {
    DB_MOCK = new DatabaseRepoMock();
    SERVICE = new SeatOfferWithdrawalServiceImpl(DB_MOCK);
  }

  @IsTest
  private static void withdrawLowerRanked_withNoOfferedRecords_returnsEmpty() {
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      new List<AcademicInterest>(),
      new Set<Id>(),
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
    Assert.isTrue(transitions.isEmpty(), 'Should not create transitions');
  }

  @IsTest
  private static void withdrawLowerRanked_withNullInput_returnsEmpty() {
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      null,
      new Set<Id>(),
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
  }

  @IsTest
  private static void withdrawLowerRanked_withSingleOffer_withdrawsLowerRanked() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lowerRank2Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lowerRank3Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = lowerRank2Id,
        Status = LotteryConstants.STATUS_ELIGIBLE,
        IndividualApplicationId = appId,
        School_Rank__c = 2,
        Current_Priority_Group__c = 1
      ),
      new AcademicInterest(
        Id = lowerRank3Id,
        Status = LotteryConstants.STATUS_ELIGIBLE,
        IndividualApplicationId = appId,
        School_Rank__c = 3,
        Current_Priority_Group__c = 1
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offeredId },
      transitions
    );

    Assert.areEqual(2, result.size(), 'Should withdraw 2 lower-ranked records');
    Assert.areEqual(2, transitions.size(), 'Should create 2 transitions');
  }

  @IsTest
  private static void withdrawLowerRanked_withSingleOffer_skipsHigherRanked() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id higherRankId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 2
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = higherRankId,
        Status = LotteryConstants.STATUS_WAITLISTED,
        IndividualApplicationId = appId,
        School_Rank__c = 1,
        Current_Priority_Group__c = 1
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offeredId },
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should not withdraw higher-ranked records');
    Assert.isTrue(transitions.isEmpty(), 'Should not create transitions for higher-ranked');
  }

  @IsTest
  private static void withdrawLowerRanked_setsCorrectStatusAndReason() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lowerRankId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = lowerRankId,
        Status = LotteryConstants.STATUS_ELIGIBLE,
        IndividualApplicationId = appId,
        School_Rank__c = 3,
        Current_Priority_Group__c = 2
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offeredId },
      transitions
    );

    Assert.areEqual(1, result.size(), 'Should withdraw 1 record');
    Assert.areEqual(
      LotteryConstants.STATUS_WITHDRAWN_DECLINED,
      result[0].Status,
      'Status should be Withdrawn/Declined'
    );
    Assert.areEqual(
      LotteryConstants.WITHDRAWN_REASON_SEAT_OFFER,
      result[0].Declined_Withdrawn_Reason__c,
      'Declined/Withdrawn reason should be set'
    );
  }

  @IsTest
  private static void withdrawLowerRanked_createsTransitions() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lowerRankId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = lowerRankId,
        Status = LotteryConstants.STATUS_WAITLISTED,
        IndividualApplicationId = appId,
        School_Rank__c = 2,
        Current_Priority_Group__c = 1
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    SERVICE.withdrawLowerRankedApplications(offeredRecords, new Set<Id>{ offeredId }, transitions);

    Assert.areEqual(1, transitions.size(), 'Should create 1 transition');
    LotteryStatusChange transition = transitions[0];
    Assert.areEqual(lowerRankId, transition.recordId, 'Should have correct record ID');
    Assert.areEqual(
      LotteryConstants.STATUS_WAITLISTED,
      transition.fromStatus,
      'From status should be Waitlisted'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_WITHDRAWN_DECLINED,
      transition.toStatus,
      'To status should be Withdrawn/Declined'
    );
    Assert.areEqual(
      LotteryConstants.TRANSITION_REASON_SEAT_OFFER_WITHDRAWAL,
      transition.reason,
      'Reason should be SEAT_OFFER_WITHDRAWAL'
    );
  }

  @IsTest
  private static void withdrawLowerRanked_excludesRecordIds() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    // Mock returns empty because excludeIds filters out all results
    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(new List<AcademicInterest>());

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offeredId },
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty when all candidates excluded');
    DB_MOCK.verify(DB_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void withdrawLowerRanked_handlesMultipleStudents() {
    DB_MOCK.reset();
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offered1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id offered2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lower1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id lower2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offered1,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId1,
        School_Rank__c = 1
      ),
      new AcademicInterest(
        Id = offered2,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId2,
        School_Rank__c = 2
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = lower1,
        Status = LotteryConstants.STATUS_ELIGIBLE,
        IndividualApplicationId = appId1,
        School_Rank__c = 3,
        Current_Priority_Group__c = 1
      ),
      new AcademicInterest(
        Id = lower2,
        Status = LotteryConstants.STATUS_WAITLISTED,
        IndividualApplicationId = appId2,
        School_Rank__c = 4,
        Current_Priority_Group__c = 1
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offered1, offered2 },
      transitions
    );

    Assert.areEqual(2, result.size(), 'Should withdraw 1 per student');
    Assert.areEqual(2, transitions.size(), 'Should create 2 transitions');
  }

  @IsTest
  private static void withdrawLowerRanked_skipsNonEligibleStatuses() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // Input records include non-Pre-Offer statuses — should be ignored
    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Status = LotteryConstants.STATUS_WAITLISTED,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>(),
      transitions
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty when no Pre-Offer/Seat Offered records');
  }

  @IsTest
  private static void withdrawLowerRanked_handlesNullSchoolRank() {
    DB_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id nullRankId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> offeredRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = offeredId,
        Status = LotteryConstants.STATUS_PRE_OFFER,
        IndividualApplicationId = appId,
        School_Rank__c = 1
      )
    };

    List<AcademicInterest> queriedRecords = new List<AcademicInterest>{
      new AcademicInterest(
        Id = nullRankId,
        Status = LotteryConstants.STATUS_ELIGIBLE,
        IndividualApplicationId = appId,
        School_Rank__c = null,
        Current_Priority_Group__c = 1
      )
    };

    DB_MOCK.when(DB_MOCK.method.queryWithBinds()).thenReturn(queriedRecords);

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> result = SERVICE.withdrawLowerRankedApplications(
      offeredRecords,
      new Set<Id>{ offeredId },
      transitions
    );

    Assert.areEqual(1, result.size(), 'Should withdraw records with null School_Rank__c');
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    SeatOfferWithdrawalServiceImpl instance = new SeatOfferWithdrawalServiceImpl();

    Assert.isNotNull(instance, 'Service should be instantiable');
  }
}