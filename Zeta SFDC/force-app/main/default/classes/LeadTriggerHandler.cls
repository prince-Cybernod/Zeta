/**
 * {@link TriggerHandler} that handles {@link Lead} DML operations.
 *
 * Stamps User.Last_Lead_Assigned__c when a Lead is owned by a User, either on
 * insert or when OwnerId changes to a User on update. Queue owners are ignored.
 */
public with sharing class LeadTriggerHandler extends NoOpTriggerHandler {
  private final LastLeadAssignedService lastLeadAssignedService;

  public LeadTriggerHandler() {
    this(new LastLeadAssignedServiceImpl());
  }

  @TestVisible
  private LeadTriggerHandler(LastLeadAssignedService lastLeadAssignedService) {
    this.lastLeadAssignedService = lastLeadAssignedService;
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
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Datetime assignedAt = System.now();
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      Lead oldLead = (Lead) oldSObjectsByIds.get(lead.Id);
      if (lead.OwnerId != oldLead.OwnerId && isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    stampIfAny(userIds, assignedAt);
  }

  private void stampIfAny(Set<Id> userIds, Datetime assignedAt) {
    if (!userIds.isEmpty()) {
      lastLeadAssignedService.stampLastLeadAssigned(userIds, assignedAt);
    }
  }

  private static Boolean isUserId(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == Schema.User.SObjectType;
  }
}