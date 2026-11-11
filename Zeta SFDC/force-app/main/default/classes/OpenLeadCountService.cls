/**
 * Service for recalculating a User's open Lead count.
 */
public interface OpenLeadCountService {
  /**
   * Recalculates User.Open_Lead_Count__c for each of the given User ids.
   * @param userIds The Users whose open Lead count may have changed
   */
  void recalculateOpenLeadCount(Set<Id> userIds);
}