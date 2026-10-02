/**
 * Tests for {@link LeadTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class LeadTriggerHandlerTest {
  private static final LeadTriggerHandler HANDLER;
  private static final LeadOwnerEventServiceMock SERVICE_MOCK;

  static {
    SERVICE_MOCK = new LeadOwnerEventServiceMock();
    HANDLER = new LeadTriggerHandler(SERVICE_MOCK);
  }

  @IsTest
  private static void getSObjectType_returnsLead() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Lead.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByUser_publishesRecountAndAssignment() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.publishLeadOwnerEvents(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(new Set<Id>{ userId }, ownerIdsToRecount, 'Should recount the owning User');
    Assert.areEqual(
      new Set<Id>{ userId },
      newlyAssignedOwnerIds,
      'Should mark the owning User as newly assigned'
    );
    Assert.isNotNull(calls[0].get('assignedAt'), 'Should capture the assignment time');
  }

  @IsTest
  private static void onAfterInsert_whenOwnedByQueue_doesNotPublish() {
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.never(SERVICE_MOCK.method.publishLeadOwnerEvents());
  }

  @IsTest
  private static void onAfterInsert_withMultipleLeadsForSameUser_deduplicatesUserIds() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId1 = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id leadId2 = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Lead(Id = leadId1, OwnerId = userId),
      new Lead(Id = leadId2, OwnerId = userId)
    };

    HANDLER.onAfterInsert(newRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.publishLeadOwnerEvents(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Assert.areEqual(1, ownerIdsToRecount.size(), 'Should have deduplicated to one User id');
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesToUser_publishesNewOwnerAsAssigned() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id oldUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id newUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = newUserId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = oldUserId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(
      new Set<Id>{ newUserId },
      newlyAssignedOwnerIds,
      'Should mark only the new owner as newly assigned'
    );
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChanges_recalculatesOldAndNewOwnersButOnlyStampsNew() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id oldUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id newUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = newUserId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = oldUserId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.publishLeadOwnerEvents(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(2, ownerIdsToRecount.size(), 'Should recount both the old and new owner');
    Assert.isTrue(ownerIdsToRecount.contains(oldUserId), 'Should include the old owner');
    Assert.isTrue(ownerIdsToRecount.contains(newUserId), 'Should include the new owner');
    Assert.isFalse(
      newlyAssignedOwnerIds.contains(oldUserId),
      'The old owner should not be marked as newly assigned'
    );
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerUnchanged_recalculatesButDoesNotStamp() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    // The recalculation is idempotent, so the unchanged owner is still
    // included rather than trying to detect that nothing really moved.
    Assert.areEqual(new Set<Id>{ userId }, ownerIdsToRecount, 'Should still recount the owner');
    Assert.isTrue(
      newlyAssignedOwnerIds.isEmpty(),
      'An unchanged owner should not be marked as newly assigned'
    );
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesFromUserToQueue_recalculatesFormerOwnerOnly() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = queueId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = userId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    // The former owner still lost an open Lead, so their count must be
    // recalculated even though the new owner is a Queue.
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(
      new Set<Id>{ userId },
      ownerIdsToRecount,
      'Should recount only the former owning User'
    );
    Assert.isTrue(newlyAssignedOwnerIds.isEmpty(), 'A Queue owner should not be newly assigned');
  }

  @IsTest
  private static void onAfterUpdate_whenOwnerChangesFromQueueToUser_recalculatesAndStampsNewOwner() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id queueId = SObjectIds.generateFakeId(Schema.Group.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      leadId => new Lead(Id = leadId, OwnerId = queueId)
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(new Set<Id>{ userId }, ownerIdsToRecount, 'Should recount the new owner');
    Assert.areEqual(
      new Set<Id>{ userId },
      newlyAssignedOwnerIds,
      'Should mark the new owner as newly assigned'
    );
  }

  @IsTest
  private static void onAfterDelete_whenOwnedByUser_publishesRecountOnly() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> oldRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterDelete(oldRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.publishLeadOwnerEvents(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(
      new Set<Id>{ userId },
      ownerIdsToRecount,
      'Should recount the deleted Lead owner'
    );
    Assert.isTrue(newlyAssignedOwnerIds.isEmpty(), 'A delete should never mark a new assignment');
  }

  @IsTest
  private static void onAfterUndelete_whenOwnedByUser_publishesRecountOnly() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.publishLeadOwnerEvents()).thenReturnVoid();
    Id leadId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> newRecords = new List<SObject>{ new Lead(Id = leadId, OwnerId = userId) };

    HANDLER.onAfterUndelete(newRecords);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.publishLeadOwnerEvents(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.publishLeadOwnerEvents()
    );
    Set<Id> ownerIdsToRecount = (Set<Id>) calls[0].get('ownerIdsToRecount');
    Set<Id> newlyAssignedOwnerIds = (Set<Id>) calls[0].get('newlyAssignedOwnerIds');
    Assert.areEqual(
      new Set<Id>{ userId },
      ownerIdsToRecount,
      'Should recount the undeleted Lead owner'
    );
    Assert.isTrue(
      newlyAssignedOwnerIds.isEmpty(),
      'An undelete should never mark a new assignment'
    );
  }
}