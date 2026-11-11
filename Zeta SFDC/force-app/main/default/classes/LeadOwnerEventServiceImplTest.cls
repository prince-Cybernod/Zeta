/**
 * Tests for {@link LeadOwnerEventServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LeadOwnerEventServiceImplTest {
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;

  static {
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
  }

  @IsTest
  private static void publishLeadOwnerEvents_withOwnerIds_publishesOneEventPerId() {
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    LeadOwnerEventServiceImpl service = new LeadOwnerEventServiceImpl(EVENT_BUS_REPO_MOCK);
    Id userId1 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id userId2 = SObjectIds.generateFakeId(Schema.User.SObjectType);

    service.publishLeadOwnerEvents(new Set<Id>{ userId1, userId2 }, new Set<Id>(), System.now());

    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishList(), 1);
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Lead_Owner_Event__e> events = (List<Lead_Owner_Event__e>) calls[0].get('events');
    Set<String> ownerIds = new Set<String>();
    for (Lead_Owner_Event__e event : events) {
      ownerIds.add(event.Owner_Id__c);
    }
    Assert.areEqual(2, events.size(), 'Should publish one event per owner id');
    Assert.isTrue(ownerIds.contains(String.valueOf(userId1)), 'Should include the first owner id');
    Assert.isTrue(ownerIds.contains(String.valueOf(userId2)), 'Should include the second owner id');
  }

  @IsTest
  private static void publishLeadOwnerEvents_withNewlyAssignedOwner_stampsOnlyThatEvent() {
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishList()).thenReturn(null);
    LeadOwnerEventServiceImpl service = new LeadOwnerEventServiceImpl(EVENT_BUS_REPO_MOCK);
    Id recountOnlyUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id newlyAssignedUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Datetime assignedAt = System.now();

    service.publishLeadOwnerEvents(
      new Set<Id>{ recountOnlyUserId, newlyAssignedUserId },
      new Set<Id>{ newlyAssignedUserId },
      assignedAt
    );

    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishList()
    );
    List<Lead_Owner_Event__e> events = (List<Lead_Owner_Event__e>) calls[0].get('events');
    Map<String, Datetime> assignedAtByOwnerId = new Map<String, Datetime>();
    for (Lead_Owner_Event__e event : events) {
      assignedAtByOwnerId.put(event.Owner_Id__c, event.Assigned_At__c);
    }
    Assert.areEqual(2, events.size(), 'Should still publish one event per owner in both sets');
    Assert.areEqual(
      assignedAt,
      assignedAtByOwnerId.get(String.valueOf(newlyAssignedUserId)),
      'The newly assigned owner should carry the assignment time'
    );
    Assert.isNull(
      assignedAtByOwnerId.get(String.valueOf(recountOnlyUserId)),
      'A recount-only owner should not carry an assignment time'
    );
  }

  @IsTest
  private static void publishLeadOwnerEvents_withEmptySet_doesNotPublish() {
    LeadOwnerEventServiceImpl service = new LeadOwnerEventServiceImpl(EVENT_BUS_REPO_MOCK);

    service.publishLeadOwnerEvents(new Set<Id>(), new Set<Id>(), System.now());

    EVENT_BUS_REPO_MOCK.never(EVENT_BUS_REPO_MOCK.method.publishList());
  }

  @IsTest
  private static void publishLeadOwnerEvents_withNullSet_doesNotPublish() {
    LeadOwnerEventServiceImpl service = new LeadOwnerEventServiceImpl(EVENT_BUS_REPO_MOCK);

    service.publishLeadOwnerEvents(null, new Set<Id>(), System.now());

    EVENT_BUS_REPO_MOCK.never(EVENT_BUS_REPO_MOCK.method.publishList());
  }
}