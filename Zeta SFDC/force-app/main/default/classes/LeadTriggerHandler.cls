/**
 * {@link TriggerHandler} that handles {@link Lead} DML operations.
 *
 * Publishes a {@link Lead_Owner_Event__e} for every User owner who may need their
 * User.Open_Lead_Count__c recalculated, across insert, update, delete, and undelete. On insert
 * and on an OwnerId change to a User, the event also carries the assignment time so the
 * subscriber can stamp User.Last_Lead_Assigned__c. Queue owners are ignored.
 */
public with sharing class LeadTriggerHandler extends NoOpTriggerHandler {
  private final LeadOwnerEventService leadOwnerEventService;

  public LeadTriggerHandler() {
    this(new LeadOwnerEventServiceImpl());
  }

  @TestVisible
  private LeadTriggerHandler(LeadOwnerEventService leadOwnerEventService) {
    this.leadOwnerEventService = leadOwnerEventService;
  }

  public override SObjectType getSObjectType() {
    return Schema.Lead.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    Datetime assignedAt = System.now();
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, userIds, assignedAt);
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Datetime assignedAt = System.now();
    Set<Id> newlyAssignedUserIds = new Set<Id>();
    Set<Id> ownerUserIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      Lead oldLead = (Lead) oldSObjectsByIds.get(lead.Id);
      if (lead.OwnerId != oldLead.OwnerId && isUserId(lead.OwnerId)) {
        newlyAssignedUserIds.add(lead.OwnerId);
      }
      if (isUserId(oldLead.OwnerId)) {
        ownerUserIds.add(oldLead.OwnerId);
      }
      if (isUserId(lead.OwnerId)) {
        ownerUserIds.add(lead.OwnerId);
      }
    }

    publishIfAny(ownerUserIds, newlyAssignedUserIds, assignedAt);
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) oldSObjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, new Set<Id>(), null);
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, new Set<Id>(), null);
  }

  private void publishIfAny(
    Set<Id> ownerIdsToRecount,
    Set<Id> newlyAssignedOwnerIds,
    Datetime assignedAt
  ) {
    if (!ownerIdsToRecount.isEmpty()) {
      leadOwnerEventService.publishLeadOwnerEvents(
        ownerIdsToRecount,
        newlyAssignedOwnerIds,
        assignedAt
      );
    }
  }

  private static Boolean isUserId(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == Schema.User.SObjectType;
  }
}