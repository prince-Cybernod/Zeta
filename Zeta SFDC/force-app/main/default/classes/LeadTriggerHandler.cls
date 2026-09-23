/**
 * {@link TriggerHandler} that handles {@link Lead} DML operations.
 *
 * Stamps User.Last_Lead_Assigned__c when a Lead is owned by a User, either on
 * insert or when OwnerId changes to a User on update. Queue owners are ignored.
 *
 * Also recalculates User.Open_Lead_Count__c for any User who may have gained
 * or lost an open Lead, across insert, update, delete, and undelete.
 */
public with sharing class LeadTriggerHandler extends NoOpTriggerHandler {
  private final LastLeadAssignedService lastLeadAssignedService;
  private final OpenLeadCountService openLeadCountService;

  public LeadTriggerHandler() {
    this(new LastLeadAssignedServiceImpl(), new OpenLeadCountServiceImpl());
  }

  @TestVisible
  private LeadTriggerHandler(
    LastLeadAssignedService lastLeadAssignedService,
    OpenLeadCountService openLeadCountService
  ) {
    this.lastLeadAssignedService = lastLeadAssignedService;
    this.openLeadCountService = openLeadCountService;
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

    stampIfAny(userIds, assignedAt);
    recalculateIfAny(userIds);
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

    stampIfAny(newlyAssignedUserIds, assignedAt);
    recalculateIfAny(ownerUserIds);
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) oldSObjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    recalculateIfAny(userIds);
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    recalculateIfAny(userIds);
  }

  private void stampIfAny(Set<Id> userIds, Datetime assignedAt) {
    if (!userIds.isEmpty()) {
      lastLeadAssignedService.stampLastLeadAssigned(userIds, assignedAt);
    }
  }

  private void recalculateIfAny(Set<Id> userIds) {
    if (!userIds.isEmpty()) {
      openLeadCountService.recalculateOpenLeadCount(userIds);
    }
  }

  private static Boolean isUserId(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == Schema.User.SObjectType;
  }
}