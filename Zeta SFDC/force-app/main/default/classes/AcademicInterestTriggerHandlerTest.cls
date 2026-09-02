/**
 * Tests for {@link AcademicInterestTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class AcademicInterestTriggerHandlerTest {
  private static final LotteryCapacityRollupServiceMock ROLLUP_SERVICE_MOCK;
  private static final CurrentPriorityCalcServiceMock PRIORITY_SERVICE_MOCK;
  private static final DynamicSiblingPriorityServiceMock SIBLING_PRIORITY_SERVICE_MOCK;
  private static final PreOfferCountRollupServiceMock PRE_OFFER_COUNT_SERVICE_MOCK;
  private static final SchoolRankValidationServiceMock RANK_VALIDATION_SERVICE_MOCK;
  private static final WaitlistHistoryServiceMock WAITLIST_HISTORY_SERVICE_MOCK;
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;
  private static final AcademicInterestTriggerHandler HANDLER;

  static {
    ROLLUP_SERVICE_MOCK = new LotteryCapacityRollupServiceMock();
    PRIORITY_SERVICE_MOCK = new CurrentPriorityCalcServiceMock();
    SIBLING_PRIORITY_SERVICE_MOCK = new DynamicSiblingPriorityServiceMock();
    PRE_OFFER_COUNT_SERVICE_MOCK = new PreOfferCountRollupServiceMock();
    RANK_VALIDATION_SERVICE_MOCK = new SchoolRankValidationServiceMock();
    WAITLIST_HISTORY_SERVICE_MOCK = new WaitlistHistoryServiceMock();
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
    HANDLER = new AcademicInterestTriggerHandler(
      ROLLUP_SERVICE_MOCK,
      PRIORITY_SERVICE_MOCK,
      SIBLING_PRIORITY_SERVICE_MOCK,
      PRE_OFFER_COUNT_SERVICE_MOCK,
      RANK_VALIDATION_SERVICE_MOCK,
      WAITLIST_HISTORY_SERVICE_MOCK,
      EVENT_BUS_REPO_MOCK
    );
  }

  @IsTest
  private static void getSObjectType_returnsAcademicInterest() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.AcademicInterest.SObjectType, result);
  }

  @IsTest
  private static void onBeforeInsert_callsPriorityServiceWithRecords() {
    PRIORITY_SERVICE_MOCK.when(PRIORITY_SERVICE_MOCK.method.calculateForRecords()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new AcademicInterest(IndividualApplicationId = applicationId)
    };

    HANDLER.onBeforeInsert(records);

    PRIORITY_SERVICE_MOCK.verify(PRIORITY_SERVICE_MOCK.method.calculateForRecords(), 1);
    List<Map<String, Object>> calls = PRIORITY_SERVICE_MOCK.getCalls(
      PRIORITY_SERVICE_MOCK.method.calculateForRecords()
    );
    List<AcademicInterest> capturedRecords = (List<AcademicInterest>) calls[0]
      .get('academicInterests');
    Assert.areEqual(1, capturedRecords.size(), 'Should pass one record to service');
  }

  @IsTest
  private static void onBeforeUpdate_callsServiceWhenInDistrictPriorityChanges() {
    PRIORITY_SERVICE_MOCK.when(PRIORITY_SERVICE_MOCK.method.calculateForRecords()).thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        In_District_Priority__c = true
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        In_District_Priority__c = false
      )
    };

    HANDLER.onBeforeUpdate(newRecords, oldMap);

    PRIORITY_SERVICE_MOCK.verify(PRIORITY_SERVICE_MOCK.method.calculateForRecords(), 1);
  }

  @IsTest
  private static void onBeforeUpdate_callsServiceWhenApplicationChanges() {
    PRIORITY_SERVICE_MOCK.when(PRIORITY_SERVICE_MOCK.method.calculateForRecords()).thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id oldApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id newApplicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = newApplicationId,
        In_District_Priority__c = false
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = oldApplicationId,
        In_District_Priority__c = false
      )
    };

    HANDLER.onBeforeUpdate(newRecords, oldMap);

    PRIORITY_SERVICE_MOCK.verify(PRIORITY_SERVICE_MOCK.method.calculateForRecords(), 1);
  }

  @IsTest
  private static void onBeforeUpdate_doesNotCallServiceWhenNoPriorityFieldsChange() {
    PRIORITY_SERVICE_MOCK.when(PRIORITY_SERVICE_MOCK.method.calculateForRecords()).thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        In_District_Priority__c = false,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        In_District_Priority__c = false,
        Status = 'Pending'
      )
    };

    HANDLER.onBeforeUpdate(newRecords, oldMap);

    PRIORITY_SERVICE_MOCK.verify(PRIORITY_SERVICE_MOCK.method.calculateForRecords(), 0);
  }

  @IsTest
  private static void onAfterInsert_callsRankValidationService() {
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        IndividualApplicationId = applicationId,
        School_Rank__c = 1
      )
    };

    HANDLER.onAfterInsert(records);

    RANK_VALIDATION_SERVICE_MOCK.verify(
      RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks(),
      1
    );
    List<Map<String, Object>> calls = RANK_VALIDATION_SERVICE_MOCK.getCalls(
      RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks()
    );
    List<AcademicInterest> capturedRecords = (List<AcademicInterest>) calls[0]
      .get('triggerRecords');
    Assert.areEqual(1, capturedRecords.size(), 'Should pass one record to service');
  }

  @IsTest
  private static void onAfterInsert_callsServiceWithCapacityIds() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> records = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = capacityId1,
        Status = 'Pending'
      ),
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = capacityId2,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterInsert(records);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = ROLLUP_SERVICE_MOCK.getCalls(
      ROLLUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('lotteryCapacityIds');
    Assert.isTrue(capturedIds.contains(capacityId1), 'Should include first capacity ID');
    Assert.isTrue(capturedIds.contains(capacityId2), 'Should include second capacity ID');
    Assert.areEqual(2, capturedIds.size(), 'Should have exactly 2 capacity IDs');
  }

  @IsTest
  private static void onAfterInsert_ignoresNullCapacityIds() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    List<SObject> records = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = null,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterInsert(records);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterInsert_callsPreOfferCountServiceForPreOfferStatus() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> records = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_PRE_OFFER
      )
    };

    HANDLER.onAfterInsert(records);

    PRE_OFFER_COUNT_SERVICE_MOCK.verify(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = PRE_OFFER_COUNT_SERVICE_MOCK.getCalls(
      PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(capturedIds.contains(applicationId), 'Should include application ID');
  }

  @IsTest
  private static void onAfterInsert_doesNotCallPreOfferServiceForNonPreOfferStatus() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> records = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterInsert(records);

    PRE_OFFER_COUNT_SERVICE_MOCK.verify(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_callsRankValidationService() {
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        School_Rank__c = 2
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        School_Rank__c = 1
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    RANK_VALIDATION_SERVICE_MOCK.verify(
      RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks(),
      1
    );
    List<Map<String, Object>> calls = RANK_VALIDATION_SERVICE_MOCK.getCalls(
      RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks()
    );
    List<AcademicInterest> capturedRecords = (List<AcademicInterest>) calls[0]
      .get('triggerRecords');
    Assert.areEqual(1, capturedRecords.size(), 'Should pass one record to service');
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallRankValidationWhenRankUnchanged() {
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        School_Rank__c = 1,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        School_Rank__c = 1,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    RANK_VALIDATION_SERVICE_MOCK.verify(
      RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_callsServiceWhenStatusChanges() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = capacityId,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = ROLLUP_SERVICE_MOCK.getCalls(
      ROLLUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('lotteryCapacityIds');
    Assert.isTrue(capturedIds.contains(capacityId), 'Should include the capacity ID');
  }

  @IsTest
  private static void onAfterUpdate_callsServiceWhenCapacityChanges() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id oldCapacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id newCapacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = newCapacityId,
        Status = 'Pending'
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = oldCapacityId,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = ROLLUP_SERVICE_MOCK.getCalls(
      ROLLUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('lotteryCapacityIds');
    Assert.isTrue(capturedIds.contains(oldCapacityId), 'Should include old capacity ID');
    Assert.isTrue(capturedIds.contains(newCapacityId), 'Should include new capacity ID');
    Assert.areEqual(2, capturedIds.size(), 'Should have both capacity IDs');
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallRollupServiceWhenNoRelevantFieldsChange() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = capacityId,
        Status = 'Pending'
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = capacityId,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_ignoresNullCapacityIds() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = null,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        Lottery_Capacity__c = null,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_callsPreOfferCountServiceWhenStatusChangesToPreOffer() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_PRE_OFFER
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = 'Eligible'
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    PRE_OFFER_COUNT_SERVICE_MOCK.verify(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = PRE_OFFER_COUNT_SERVICE_MOCK.getCalls(
      PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(capturedIds.contains(applicationId), 'Should include application ID');
  }

  @IsTest
  private static void onAfterUpdate_callsPreOfferCountServiceWhenStatusChangesFromPreOffer() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_PRE_OFFER
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    PRE_OFFER_COUNT_SERVICE_MOCK.verify(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate(), 1);
  }

  @IsTest
  private static void onAfterDelete_callsServiceWithCapacityIds() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> oldRecords = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = capacityId1,
        Status = 'Pending'
      ),
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = capacityId2,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterDelete(oldRecords);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = ROLLUP_SERVICE_MOCK.getCalls(
      ROLLUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('lotteryCapacityIds');
    Assert.isTrue(capturedIds.contains(capacityId1), 'Should include first capacity ID');
    Assert.isTrue(capturedIds.contains(capacityId2), 'Should include second capacity ID');
    Assert.areEqual(2, capturedIds.size(), 'Should have exactly 2 capacity IDs');
  }

  @IsTest
  private static void onAfterDelete_ignoresNullCapacityIds() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    List<SObject> oldRecords = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        Lottery_Capacity__c = null,
        Status = 'Pending'
      )
    };

    HANDLER.onAfterDelete(oldRecords);

    ROLLUP_SERVICE_MOCK.verify(ROLLUP_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterDelete_callsPreOfferCountServiceForPreOfferRecords() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> oldRecords = new List<SObject>{
      new AcademicInterest(
        Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType),
        IndividualApplicationId = applicationId,
        Lottery_Capacity__c = capacityId,
        Status = AcademicInterestConstants.STATUS_PRE_OFFER
      )
    };

    HANDLER.onAfterDelete(oldRecords);

    PRE_OFFER_COUNT_SERVICE_MOCK.verify(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = PRE_OFFER_COUNT_SERVICE_MOCK.getCalls(
      PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(capturedIds.contains(applicationId), 'Should include application ID');
  }

  @IsTest
  private static void onAfterUpdate_callsWaitlistHistoryServiceWhenStatusChanges() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = 5,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = 10,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      1
    );
  }

  @IsTest
  private static void onAfterUpdate_callsWaitlistHistoryServiceWhenPriorityChanges() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = 5,
          Current_Priority_Group__c = 1
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = 5,
          Current_Priority_Group__c = 3
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      1
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallWaitlistHistoryServiceWhenLotteryNotRun() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => false }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Eligible',
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => false }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallWaitlistHistoryServiceWhenNoRelevantFieldsChange() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    RANK_VALIDATION_SERVICE_MOCK.when(RANK_VALIDATION_SERVICE_MOCK.method.validateUniqueRanks())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Status = 'Waitlisted',
        Current_Priority_Group__c = 2,
        School_Rank__c = 2
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => new AcademicInterest(
        Id = academicInterestId,
        IndividualApplicationId = applicationId,
        Status = 'Waitlisted',
        Current_Priority_Group__c = 2,
        School_Rank__c = 1
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallWaitlistHistoryServiceForPreOfferStatus() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Lottery_Capacity__c = capacityId,
          Status = AcademicInterestConstants.STATUS_PRE_OFFER,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Lottery_Capacity__c = capacityId,
          Status = 'Eligible',
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallWaitlistHistoryServiceForSeatOfferedStatus() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Lottery_Capacity__c = capacityId,
          Status = AcademicInterestConstants.STATUS_SEAT_OFFERED,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Lottery_Capacity__c = capacityId,
          Status = AcademicInterestConstants.STATUS_PRE_OFFER,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotCallWaitlistHistoryServiceWhenPositionIsNull() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = null,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Eligible',
          Waitlist_Position__c = null,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      0
    );
  }

  @IsTest
  private static void onAfterUpdate_callsWaitlistHistoryServiceWhenPositionChanges() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = 3,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Waitlisted',
          Waitlist_Position__c = null,
          Current_Priority_Group__c = 2
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    WAITLIST_HISTORY_SERVICE_MOCK.verify(
      WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords(),
      1
    );
  }

  @IsTest
  private static void onAfterUpdate_publishesWaitlistRecalcEventWhenStatusChangesToWaitlistedPostLottery() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 1);
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Waitlist_Recalculation_Event__e> events = (List<Waitlist_Recalculation_Event__e>) calls[0]
      .get('events');
    Assert.areEqual(1, events.size(), 'Should publish one event');
    Assert.areEqual(
      String.valueOf(capacityId),
      events[0].Lottery_Capacity_Id__c,
      'Event should contain capacity ID'
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotPublishWaitlistRecalcEventPreLottery() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => false }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => false }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 0);
  }

  @IsTest
  private static void onAfterUpdate_doesNotPublishWaitlistRecalcEventWhenAlreadyWaitlisted() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId,
          Waitlist_Position__c = 3
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId,
          Waitlist_Position__c = 5
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 0);
  }

  @IsTest
  private static void onAfterUpdate_doesNotPublishWaitlistRecalcEventForOtherStatusChanges() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    SIBLING_PRIORITY_SERVICE_MOCK.when(SIBLING_PRIORITY_SERVICE_MOCK.method.handleUpgrade())
      .thenReturnVoid();
    PRE_OFFER_COUNT_SERVICE_MOCK.when(PRE_OFFER_COUNT_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Status = AcademicInterestConstants.STATUS_PRE_OFFER,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          IndividualApplicationId = applicationId,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 0);
  }

  @IsTest
  private static void onAfterUpdate_publishesSingleEventPerCapacityForBulkWaitlistChanges() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = aiId1,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      ),
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = aiId2,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      aiId1 => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = aiId1,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      ),
      aiId2 => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = aiId2,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 1);
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Waitlist_Recalculation_Event__e> events = (List<Waitlist_Recalculation_Event__e>) calls[0]
      .get('events');
    Assert.areEqual(1, events.size(), 'Should publish one event per unique capacity');
  }

  @IsTest
  private static void onAfterUpdate_eligibleStatusChangePublishesRecalcEvent() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Submitted',
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 1);
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Waitlist_Recalculation_Event__e> events = (List<Waitlist_Recalculation_Event__e>) calls[0]
      .get('events');
    Assert.areEqual(1, events.size(), 'Should publish one event');
    Assert.areEqual(
      String.valueOf(capacityId),
      events[0].Lottery_Capacity_Id__c,
      'Event should contain capacity ID'
    );
  }

  @IsTest
  private static void onAfterUpdate_doesNotPublishWaitlistRecalcEventWhenNoCapacity() {
    WAITLIST_HISTORY_SERVICE_MOCK.when(WAITLIST_HISTORY_SERVICE_MOCK.method.createHistoryRecords())
      .thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_WAITLISTED,
          Lottery_Capacity__c = null
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = WaitlistConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = null
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 0);
  }

  @IsTest
  private static void onAfterUpdate_publishesWaitlistRecalcEventWhenStatusChangesToEligiblePostLottery() {
    ROLLUP_SERVICE_MOCK.when(ROLLUP_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = LotteryConstants.STATUS_ELIGIBLE,
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      academicInterestId => (AcademicInterest) ReadOnlySObject.create(
        new AcademicInterest(
          Id = academicInterestId,
          Status = 'Submitted',
          Lottery_Capacity__c = capacityId
        ),
        new Map<String, Object>{ 'Has_Lottery_Run__c' => true }
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 1);
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Waitlist_Recalculation_Event__e> events = (List<Waitlist_Recalculation_Event__e>) calls[0]
      .get('events');
    Assert.areEqual(1, events.size(), 'Should publish one event');
    Assert.areEqual(
      String.valueOf(capacityId),
      events[0].Lottery_Capacity_Id__c,
      'Event should contain capacity ID'
    );
  }
}