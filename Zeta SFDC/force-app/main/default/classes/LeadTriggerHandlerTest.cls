/**
 * Tests for {@link LeadTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class LeadTriggerHandlerTest {
  private static final LeadTriggerHandler HANDLER;
  private static final LastLeadAssignedServiceMock SERVICE_MOCK;
  private static final OpenLeadCountServiceMock OPEN_LEAD_COUNT_SERVICE_MOCK;

  static {
    SERVICE_MOCK = new LastLeadAssignedServiceMock();
    OPEN_LEAD_COUNT_SERVICE_MOCK = new OpenLeadCountServiceMock();
    HANDLER = new LeadTriggerHandler(SERVICE_MOCK, OPEN_LEAD_COUNT_SERVICE_MOCK);
  }

  @IsTest
  private static void getSObjectType_returnsLead() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Lead.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByUser_stampsLastLeadAssigned() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.stampLastLeadAssigned(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.stampLastLeadAssigned()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should have exactly one User id');
    Assert.isTrue(capturedUserIds.contains(userId), 'Should include the owning User');
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByUser_recalculatesOpenLeadCount() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterInsert(newRecords);

    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
    List<Map<String, Object>> calls = OPEN_LEAD_COUNT_SERVICE_MOCK.getCalls(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should have exactly one User id');
    Assert.isTrue(capturedUserIds.contains(userId), 'Should include the owning User');
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByQueue_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
    OPEN_LEAD_COUNT_SERVICE_MOCK.never(OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount());
  }

  @IsTest
  private static void onAfterInsert_withMultipleLeadsForSameUser_deduplicatesUserIds() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId1 = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id leadId2 = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Lead(Id = leadId1, OwnerId = userId),
      new Lead(Id = leadId2, OwnerId = userId)
    };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.stampLastLeadAssigned(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.stampLastLeadAssigned()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should have deduplicated to one User id');
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesToUser_stampsLastLeadAssigned() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id oldUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id newUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = newUserId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = oldUserId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.stampLastLeadAssigned(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.stampLastLeadAssigned()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.isTrue(capturedUserIds.contains(newUserId), 'Should include the new owning User');
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChanges_recalculatesOpenLeadCountForOldAndNewOwners() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id oldUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id newUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = newUserId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = oldUserId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
    List<Map<String, Object>> calls = OPEN_LEAD_COUNT_SERVICE_MOCK.getCalls(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(2, capturedUserIds.size(), 'Should include both the old and new owner');
    Assert.isTrue(capturedUserIds.contains(oldUserId), 'Should include the old owner');
    Assert.isTrue(capturedUserIds.contains(newUserId), 'Should include the new owner');
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerUnchanged_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
    // The recalculation is idempotent, so the unchanged owner is still
    // included rather than trying to detect that nothing really moved.
    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesFromUserToQueue_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
    // The former owner still lost an open Lead, so their count must be
    // recalculated even though the new owner is a Queue.
    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
    List<Map<String, Object>> calls = OPEN_LEAD_COUNT_SERVICE_MOCK.getCalls(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should include only the former owning User');
    Assert.isTrue(capturedUserIds.contains(userId), 'Should include the former owner');
  }

  @IsTest
  private static void onAfterDelete_whenOwnedByUser_recalculatesOpenLeadCount() {
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> oldRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterDelete(oldRecords);

    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
    List<Map<String, Object>> calls = OPEN_LEAD_COUNT_SERVICE_MOCK.getCalls(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should have exactly one User id');
    Assert.isTrue(capturedUserIds.contains(userId), 'Should include the deleted Lead owner');
  }

  @IsTest
  private static void onAfterUndelete_whenOwnedByUser_recalculatesOpenLeadCount() {
    OPEN_LEAD_COUNT_SERVICE_MOCK.when(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    ).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterUndelete(newRecords);

    OPEN_LEAD_COUNT_SERVICE_MOCK.verify(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount(),
      1
    );
    List<Map<String, Object>> calls = OPEN_LEAD_COUNT_SERVICE_MOCK.getCalls(
      OPEN_LEAD_COUNT_SERVICE_MOCK.method.recalculateOpenLeadCount()
    );
    Set<Id> capturedUserIds = (Set<Id>) calls[0].get('userIds');
    Assert.areEqual(1, capturedUserIds.size(), 'Should have exactly one User id');
    Assert.isTrue(capturedUserIds.contains(userId), 'Should include the undeleted Lead owner');
  }
}