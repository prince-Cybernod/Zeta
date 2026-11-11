/**
 * Trigger handler for {@link Lead_Owner_Event__e} platform events.
 * De-dupes Owner ids, then recalculates open Lead counts, stamping the latest Assigned_At__c
 * seen in the batch for any owner that has one.
 */
public without sharing class LeadOwnerEventHandler extends NoOpTriggerHandler {
  private final OpenLeadCountRecalculator recalculator;

  public LeadOwnerEventHandler() {
    this(new OpenLeadCountRecalculator());
  }

  @TestVisible
  private LeadOwnerEventHandler(OpenLeadCountRecalculator recalculator) {
    this.recalculator = recalculator;
  }

  public override SObjectType getSObjectType() {
    return Schema.Lead_Owner_Event__e.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    List<Lead_Owner_Event__e> events = (List<Lead_Owner_Event__e>) sobjects;
    Set<Id> userIds = new Set<Id>();
    Map<Id, Datetime> latestAssignedAtByUserId = new Map<Id, Datetime>();
    extractEventData(events, userIds, latestAssignedAtByUserId);

    recalculator.recalculate(userIds, latestAssignedAtByUserId);
  }

  private static void extractEventData(
    List<Lead_Owner_Event__e> events,
    Set<Id> userIds,
    Map<Id, Datetime> latestAssignedAtByUserId
  ) {
    for (Lead_Owner_Event__e event : events) {
      if (String.isBlank(event.Owner_Id__c)) {
        continue;
      }
      Id userId;
      try {
        userId = Id.valueOf(event.Owner_Id__c);
      } catch (StringException e) {
        System.debug(LoggingLevel.WARN, 'Invalid Owner_Id: ' + event.Owner_Id__c);
        continue;
      }
      userIds.add(userId);

      Datetime assignedAt = event.Assigned_At__c;
      if (assignedAt == null) {
        continue;
      }
      Datetime latestSoFar = latestAssignedAtByUserId.get(userId);
      if (latestSoFar == null || assignedAt > latestSoFar) {
        latestAssignedAtByUserId.put(userId, assignedAt);
      }
    }
  }
}