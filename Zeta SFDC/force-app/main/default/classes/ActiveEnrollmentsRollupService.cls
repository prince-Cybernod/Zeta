/**
 * Service for recalculating the Active Enrollments rollup on Account.
 */
public interface ActiveEnrollmentsRollupService {
  /**
   * Recalculates {@link Account.Active_Enrollments__c} for the given IDs.
   * Counts every Academic Term Enrollment with {@code Active__c = true} the
   * Account is attached to, as the learner or as either guardian.
   * @param accountIds IDs of Accounts to recalculate
   */
  void recalculate(Set<Id> accountIds);
}