/**
 * Tests for {@link WaitlistRecalculationEventHandler}.
 */
@IsTest(IsParallel=true)
private class WaitlistRecalculationEventHandlerTest {
  private static final WaitlistRecalculationEventHandler HANDLER;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    HANDLER = new WaitlistRecalculationEventHandler(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void getSObjectType_returnsWaitlistRecalculationEvent() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Waitlist_Recalculation_Event__e.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_withValidCapacityIds_enqueuesJob() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = capacityId)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isTrue(HANDLER.hasEnqueuedJob, 'Should have enqueued a job');
  }

  @IsTest
  private static void onAfterInsert_withMultipleCapacityIds_enqueuesSingleJob() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = capacityId1),
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = capacityId2)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isTrue(HANDLER.hasEnqueuedJob, 'Should have enqueued a job');
  }

  @IsTest
  private static void onAfterInsert_withDuplicateCapacityIds_deduplicates() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = capacityId),
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = capacityId)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isTrue(HANDLER.hasEnqueuedJob, 'Should have enqueued a job');
  }

  @IsTest
  private static void onAfterInsert_withEmptyCapacityId_doesNotEnqueueJob() {
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = '')
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isFalse(HANDLER.hasEnqueuedJob, 'Should not have enqueued a job');
  }

  @IsTest
  private static void onAfterInsert_withInvalidCapacityId_skipsInvalidAndContinues() {
    Id validCapacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = 'invalid-id'),
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = validCapacityId)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isTrue(HANDLER.hasEnqueuedJob, 'Should have enqueued a job with valid ID');
  }

  @IsTest
  private static void onAfterInsert_withNullCapacityId_doesNotEnqueueJob() {
    List<SObject> events = new List<SObject>{
      new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = null)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isFalse(HANDLER.hasEnqueuedJob, 'Should not have enqueued a job');
  }

  @IsTest
  private static void onAfterInsert_withEmptyList_doesNotEnqueueJob() {
    List<SObject> events = new List<SObject>();

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    Assert.isFalse(HANDLER.hasEnqueuedJob, 'Should not have enqueued a job');
  }
}