/**
 * Result of a lottery rollback operation.
 */
public with sharing class LotteryRollbackResult {
  public Integer capacitiesUnlinked = 0;
  public Integer academicInterestsReset = 0;
  public Integer waitlistHistoryDeleted = 0;
  public Integer runResultsDeleted = 0;

  public Integer getTotalRecordsAffected() {
    return capacitiesUnlinked + academicInterestsReset + waitlistHistoryDeleted + runResultsDeleted;
  }
}