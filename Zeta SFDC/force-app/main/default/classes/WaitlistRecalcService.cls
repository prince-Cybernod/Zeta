/**
 * Orchestrator service for waitlist recalculation.
 *
 * Coordinates the waitlist recalc workflow:
 * 1. Sort waitlisted students by priority and lottery number
 * 2. Assign sequential positions
 * 3. Identify position changes for DML
 *
 * History records are created automatically by trigger when positions change.
 * Offer optimization is handled separately after DML.
 */
public interface WaitlistRecalcService {
  /**
   * Recalculates waitlist positions for a group of students.
   *
   * @param records Waitlisted AcademicInterest records to recalculate (should be from same Lottery_Capacity__c)
   * @return Records with updated Waitlist_Position__c values (only records that changed)
   */
  List<AcademicInterest> recalculatePositions(List<AcademicInterest> records);

  /**
   * Recalculates waitlist positions for multiple capacities.
   *
   * Groups records by Lottery_Capacity__c and recalculates each group independently.
   *
   * @param records Waitlisted AcademicInterest records (can span multiple capacities)
   * @return Records with updated Waitlist_Position__c values (only records that changed)
   */
  List<AcademicInterest> recalculatePositionsByCapacity(List<AcademicInterest> records);

  /**
   * Identifies waitlisted students eligible for pre-offer promotion.
   *
   * Given a sorted list of waitlisted students and available seats,
   * returns the top N students who should be promoted to Pre-Offer status.
   *
   * Note: This method does NOT modify records. It returns records that SHOULD be promoted.
   * The caller is responsible for:
   * - Setting Status = 'Pre-Offer' on returned records
   * - Performing DML
   * - Calling OfferOptimizerService for multi-offer scenarios
   *
   * @param sortedRecords Waitlisted AcademicInterest records, already sorted by position
   * @param availableSeats Number of seats available for new offers
   * @return Top N records eligible for promotion (where N = availableSeats)
   */
  List<AcademicInterest> getRecordsToPromote(
    List<AcademicInterest> sortedRecords,
    Integer availableSeats
  );
}