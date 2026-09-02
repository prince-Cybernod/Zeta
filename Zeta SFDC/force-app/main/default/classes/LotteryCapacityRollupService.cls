/**
 * Service for recalculating rollup fields on Lottery Capacity records.
 */
public interface LotteryCapacityRollupService {
  /**
   * Recalculates rollup fields on Lottery Capacity records for the given IDs.
   * Updates Seats_Offered__c, Seats_Accepted__c, and Count_of_Pre_Offer_School_Applications__c
   * based on related AcademicInterest statuses.
   * @param lotteryCapacityIds IDs of Lottery Capacity records to recalculate
   */
  void recalculate(Set<Id> lotteryCapacityIds);
}