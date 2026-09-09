/**
 * Service for recalculating the Application Count rollup on Account.
 */
public interface ApplicationCountRollupService {
  /**
   * Recalculates {@link Account.Application_Count__c} for the given IDs.
   * Counts every Individual Application the Account is attached to, as the
   * student or as either guardian, regardless of status.
   * @param accountIds IDs of Accounts to recalculate
   */
  void recalculate(Set<Id> accountIds);
}