/**
 * Service for publishing Lead owner events.
 */
public interface LeadOwnerEventService {
  /**
   * Publishes one {@link Lead_Owner_Event__e} per owner id to recount. Owners also present in
   * newlyAssignedOwnerIds carry assignedAt so the subscriber can stamp User.Last_Lead_Assigned__c.
   * @param ownerIdsToRecount The Users whose open Lead count may have changed
   * @param newlyAssignedOwnerIds The subset newly assigned a Lead
   * @param assignedAt The moment the assignment happened
   */
  void publishLeadOwnerEvents(
    Set<Id> ownerIdsToRecount,
    Set<Id> newlyAssignedOwnerIds,
    Datetime assignedAt
  );
}