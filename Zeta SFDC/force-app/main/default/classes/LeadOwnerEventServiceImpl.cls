/**
 * Implementation of {@link LeadOwnerEventService}.
 *
 * Published as a {@link Lead_Owner_Event__e} so both the recount and the Last_Lead_Assigned__c
 * stamp run in the subscriber's own transaction, whatever async context the triggering Lead DML
 * happened in.
 */
public with sharing class LeadOwnerEventServiceImpl implements LeadOwnerEventService {
  private final EventBusRepo eventBusRepo;

  public LeadOwnerEventServiceImpl() {
    this(new EventBusRepoImpl());
  }

  @TestVisible
  private LeadOwnerEventServiceImpl(EventBusRepo eventBusRepo) {
    this.eventBusRepo = eventBusRepo;
  }

  public void publishLeadOwnerEvents(
    Set<Id> ownerIdsToRecount,
    Set<Id> newlyAssignedOwnerIds,
    Datetime assignedAt
  ) {
    if (ownerIdsToRecount == null || ownerIdsToRecount.isEmpty()) {
      return;
    }

    List<Lead_Owner_Event__e> events = new List<Lead_Owner_Event__e>();
    for (Id ownerId : ownerIdsToRecount) {
      events.add(
        new Lead_Owner_Event__e(
          Owner_Id__c = String.valueOf(ownerId),
          Assigned_At__c = newlyAssignedOwnerIds != null && newlyAssignedOwnerIds.contains(ownerId)
            ? assignedAt
            : null
        )
      );
    }
    logFailures(events, eventBusRepo.publish(events));
  }

  private static void logFailures(
    List<Lead_Owner_Event__e> events,
    List<Database.SaveResult> results
  ) {
    if (results == null) {
      return;
    }
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'Failed to publish Lead_Owner_Event__e for owner ' +
            events[i].Owner_Id__c +
            ': ' +
            results[i].getErrors()
        );
      }
    }
  }
}