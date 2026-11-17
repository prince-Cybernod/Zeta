/**
 * Service for recalculating the Charter-level employee priority and available
 * seats rollup on Account.
 */
public interface CharterRollupService {
  /**
   * Recalculates {@link Account.Count_Lottery_Employee_Priority__c} and
   * {@link Account.Total_Available_Seats_for_School_Year__c} for the given
   * Charter Account IDs, summing the LearningPrograms linked to each
   * Charter's current cycle: the linked application timelines open today,
   * or, if none is open, the linked timelines that have opened with the
   * latest close date (ties all count). A Charter with no timeline that
   * has ever opened writes 0/0. Only Charters whose sum actually changed
   * are written.
   * @param charterAccountIds IDs of Charter Accounts to recalculate
   */
  void recalculate(Set<Id> charterAccountIds);
}