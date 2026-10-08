/**
 * Service for recalculating the Application Count rollups on Account.
 */
public interface ApplicationCountRollupService {
  /**
   * Recalculates {@link Account.Application_Count__c} and
   * {@link Account.Post_Draft_Application_Count__c} for the given IDs. Both
   * count every Individual Application the Account is attached to, as the
   * student or as either guardian; Application_Count__c counts regardless of
   * status, Post_Draft_Application_Count__c excludes Status = 'Draft'.
   * @param accountIds IDs of Accounts to recalculate
   */
  void recalculate(Set<Id> accountIds);
}