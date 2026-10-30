/**
 * Service for recalculating the School Applications and Application Lead
 * Sources rollups on Contact (read and written on Account via the `__pc`
 * suffix for person accounts).
 */
public interface ContactApplicationRollupService {
  /**
   * Recalculates {@link Account.School_Applications__pc} and
   * {@link Account.Application_Lead_Sources__pc} for the given person
   * Account IDs, considering every IndividualApplication where the Account
   * is the student (AccountId) or the primary guardian
   * (Primary_Guardian__c).
   * @param personAccountIds IDs of person Accounts to recalculate
   */
  void recalculate(Set<Id> personAccountIds);
}