/**
 * Service for withdrawing lower-ranked school applications when a student receives a seat offer.
 */
public interface SeatOfferWithdrawalService {
  /**
   * Queries and withdraws lower-ranked applications for students who have offers.
   * Finds cross-capacity records via SOQL. Only withdraws Eligible and Waitlisted
   * records with School_Rank__c greater than the student's best offer.
   *
   * @param offeredRecords Records with Pre-Offer or Seat Offered status
   * @param excludeRecordIds Record IDs already in the working set (won't be re-queried)
   * @param transitions Audit transition list to append to
   * @return Records set to Withdrawn/Declined (caller handles DML)
   */
  List<AcademicInterest> withdrawLowerRankedApplications(
    List<AcademicInterest> offeredRecords,
    Set<Id> excludeRecordIds,
    List<LotteryStatusChange> transitions
  );
}