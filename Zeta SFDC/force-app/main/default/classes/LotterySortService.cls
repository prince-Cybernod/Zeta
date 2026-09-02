/**
 * Service for sorting lottery candidates and assigning randomized sort keys.
 */
public interface LotterySortService {
  /**
   * Assigns randomized sort keys to all eligible AcademicInterest records.
   * Each record gets a unique random number for lottery ordering.
   *
   * @param records List of eligible AcademicInterest records
   */
  void assignRandomizedSortKeys(List<AcademicInterest> records);

  /**
   * Sorts AcademicInterest records by lottery order.
   *
   * Sort order:
   * 1. Current_Priority_Group__c ASC (1=Sibling first, 4=General last)
   * 2. Within same group: students WITHOUT Date_of_Current_Priority_Change__c first
   * 3. Then by: Randomized_Sort_Key__c ASC
   * 4. Tie-breaker: CreatedDate ASC
   *
   * @param records List of AcademicInterest records to sort
   * @return Sorted list of records
   */
  List<AcademicInterest> sortByLotteryOrder(List<AcademicInterest> records);

  /**
   * Processes lottery for a single grade capacity.
   * Queries eligible students, sorts them, and returns the top N for offers.
   *
   * @param lotteryCapacityId The Lottery_Capacity__c record ID
   * @param availableSeats Number of seats to fill
   * @return List of AcademicInterest records to receive offers (top N)
   */
  List<AcademicInterest> getTopCandidatesForCapacity(Id lotteryCapacityId, Integer availableSeats);
}