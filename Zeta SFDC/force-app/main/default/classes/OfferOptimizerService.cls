/**
 * Service for optimizing student offers when they have multiple pre-offers.
 *
 * When a student has pre-offers from multiple schools, this service:
 * 1. Identifies the highest-ranked school (lowest School_Rank__c)
 * 2. Keeps that pre-offer active
 * 3. Rescinds lower-ranked pre-offers (sets status back to Waitlisted)
 *
 * This ensures students only hold one offer at a time (their top choice).
 */
public interface OfferOptimizerService {
  /**
   * Optimizes offers for students with multiple pre-offers.
   *
   * For each student with Pre_Offer_Count__c > 1:
   * - Finds the school with lowest School_Rank__c (highest preference)
   * - Keeps that pre-offer, rescinds others
   *
   * @param records AcademicInterest records to evaluate (typically those with status change to Pre-Offer)
   * @param transitions List to append status transitions to (for audit tracking)
   * @return Records that need status updates (rescinded offers)
   */
  List<AcademicInterest> optimizeOffers(
    List<AcademicInterest> records,
    List<LotteryStatusChange> transitions
  );
}