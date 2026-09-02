/**
 * Service for recalculating the Pre-Offer count rollup.
 */
public interface PreOfferCountRollupService {
  /**
   * Recalculates Pre-Offer counts for the given Individual Application IDs.
   * Counts AcademicInterest records with Status = 'Pre-Offer', updates
   * IndividualApplication.Count_of_Pre_Offer_School_Applications__c,
   * and cascades the count to all child AcademicInterest records.
   * @param individualApplicationIds IDs of Individual Applications to recalculate
   */
  void recalculate(Set<Id> individualApplicationIds);
}