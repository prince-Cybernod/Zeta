/**
 * Tests for {@link LeadTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class LeadTriggerHandlerTest {
  private static final LeadTriggerHandler HANDLER;
  private static final LastLeadAssignedServiceMock SERVICE_MOCK;

  static {
    SERVICE_MOCK = new LastLeadAssignedServiceMock();
    HANDLER = new LeadTriggerHandler(SERVICE_MOCK);
  }

  @IsTest
  private static void getSObjectType_returnsLead() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Lead.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByUser_stampsLastLeadAssigned() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
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
  private static void onAfterInsert_whenOwnedByQueue_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
  }

  @IsTest
  private static void onAfterInsert_withMultipleLeadsForSameUser_deduplicatesUserIds() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
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
  private static void onAfterUpdate_whenOwnerUnchanged_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesFromUserToQueue_doesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.stampLastLeadAssigned()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.never(SERVICE_MOCK.method.stampLastLeadAssigned());
  }
}