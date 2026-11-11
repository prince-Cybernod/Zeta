/**
 * Service for recording that a Lead was assigned to a User.
 */
public interface LastLeadAssignedService {
  /**
   * Stamps User.Last_Lead_Assigned__c to assignedAt for each of the given User ids.
   * @param userIds The Users that were just assigned a Lead
   * @param assignedAt The moment the assignment happened
   */
  void stampLastLeadAssigned(Set<Id> userIds, Datetime assignedAt);
}