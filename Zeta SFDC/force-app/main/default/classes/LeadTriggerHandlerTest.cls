/**
 * Tests for {@link LeadTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class LeadTriggerHandlerTest {
  private static final LeadTriggerHandler HANDLER;
  private static final LeadOwnerEventServiceMock SERVICE_MOCK;
  private static final Datetime ATTEMPT_1 = Datetime.newInstanceGmt(2027, 7, 14, 15, 0, 0);
  private static final Datetime ATTEMPT_2 = Datetime.newInstanceGmt(2027, 7, 16, 15, 0, 0);
  private static final Datetime OLD_DUE = Datetime.newInstanceGmt(2027, 7, 1, 15, 0, 0);
  private static final Datetime SATURDAY = Datetime.newInstanceGmt(2027, 7, 17, 14, 0, 0);

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

  @IsTest
  private static void onBeforeInsert_setsNextFollowUpDueInBusinessDays() {
    Lead newLead = new Lead();
    Lead importedLead = new Lead(
      Outreach_Attempt_1__c = ATTEMPT_1,
      Outreach_Attempt_2__c = ATTEMPT_2
    );
    Lead saturdayAttempt1 = new Lead(Outreach_Attempt_1__c = SATURDAY);

    Lead keptCreatedDate = (Lead) JSON.deserialize(
      '{"CreatedDate":"2027-07-17T00:00:00.000+0000"}',
      Lead.class
    );

    HANDLER.onBeforeInsert(
      new List<SObject>{ newLead, importedLead, saturdayAttempt1, keptCreatedDate }
    );

    Assert.isTrue(
      newLead.Next_Follow_Up_Due__c > System.now(),
      'A new Lead should be due after now'
    );
    Assert.areEqual(
      '17:00',
      newLead.Next_Follow_Up_Due__c.format('HH:mm', 'America/New_York'),
      'Every due date should be at 5 pm'
    );
    Assert.areEqual(
      Datetime.newInstanceGmt(2027, 7, 19, 21, 0, 0),
      keptCreatedDate.Next_Follow_Up_Due__c,
      'Created Friday 8 pm should be due the next working day at 5 pm, Monday 5 pm'
    );
    Assert.areEqual(
      Datetime.newInstanceGmt(2027, 7, 23, 21, 0, 0),
      importedLead.Next_Follow_Up_Due__c,
      'Attempt 2 on Friday 11 am + 7 calendar days should be due the next Friday at 5 pm'
    );
    Assert.areEqual(
      Datetime.newInstanceGmt(2027, 7, 19, 21, 0, 0),
      saturdayAttempt1.Next_Follow_Up_Due__c,
      'Attempt 1 on Saturday lands on Monday, so it should be due Monday at 5 pm, a full working day'
    );
  }

  @IsTest
  private static void onBeforeUpdate_setsNextFollowUpDueOnlyWhenAnAttemptChanges() {
    Id addedAttempt1Id = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id addedAttempt3Id = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id unchangedId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id closedId = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Id saturdayAttempt2Id = SObjectIds.generateFakeId(Schema.Lead.SObjectType);
    Lead addedAttempt1 = new Lead(
      Id = addedAttempt1Id,
      Next_Follow_Up_Due__c = OLD_DUE,
      Outreach_Attempt_1__c = ATTEMPT_2
    );
    Lead saturdayAttempt2 = new Lead(
      Id = saturdayAttempt2Id,
      Next_Follow_Up_Due__c = OLD_DUE,
      Outreach_Attempt_1__c = ATTEMPT_1,
      Outreach_Attempt_2__c = SATURDAY
    );
    Lead addedAttempt3 = new Lead(
      Id = addedAttempt3Id,
      Next_Follow_Up_Due__c = OLD_DUE,
      Outreach_Attempt_3__c = ATTEMPT_2
    );
    Lead unchanged = new Lead(
      Id = unchangedId,
      Next_Follow_Up_Due__c = OLD_DUE,
      Outreach_Attempt_1__c = ATTEMPT_1
    );
    Lead closed = new Lead(
      Id = closedId,
      Next_Follow_Up_Due__c = OLD_DUE,
      Status = 'Closed - Not Converted'
    );
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>{
      closedId => new Lead(Id = closedId, Next_Follow_Up_Due__c = OLD_DUE, Status = 'Open - Working'),
      addedAttempt1Id => new Lead(Id = addedAttempt1Id, Next_Follow_Up_Due__c = OLD_DUE),
      saturdayAttempt2Id => new Lead(
        Id = saturdayAttempt2Id,
        Next_Follow_Up_Due__c = OLD_DUE,
        Outreach_Attempt_1__c = ATTEMPT_1
      ),
      addedAttempt3Id => new Lead(Id = addedAttempt3Id, Next_Follow_Up_Due__c = OLD_DUE),
      unchangedId => unchanged.clone(true)
    };

    HANDLER.onBeforeUpdate(
      new List<SObject>{ addedAttempt1, saturdayAttempt2, addedAttempt3, unchanged, closed },
      oldSObjectsByIds
    );

    Assert.areEqual(
      Datetime.newInstanceGmt(2027, 7, 19, 21, 0, 0),
      addedAttempt1.Next_Follow_Up_Due__c,
      'Attempt 1 on Friday 11 am lands on Sunday, so it should move to Monday at 5 pm'
    );
    Assert.areEqual(
      Datetime.newInstanceGmt(2027, 7, 26, 21, 0, 0),
      saturdayAttempt2.Next_Follow_Up_Due__c,
      'Attempt 2 on Saturday lands on a Saturday, so it should move to Monday at 5 pm'
    );
    Assert.isNull(
      addedAttempt3.Next_Follow_Up_Due__c,
      'Should be blank once Outreach Attempt 3 is done'
    );
    Assert.areEqual(
      OLD_DUE,
      unchanged.Next_Follow_Up_Due__c,
      'Should keep the due date when no attempt changed'
    );
    Assert.isNull(closed.Next_Follow_Up_Due__c, 'Should be blank once the Lead is closed');
  }
}