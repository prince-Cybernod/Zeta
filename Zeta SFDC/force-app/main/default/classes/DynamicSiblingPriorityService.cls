/**
 * Service for dynamically updating sibling priority when a student receives or loses a seat offer.
 * Updates Priority_Item__c.Priority_Type__c between 'Sibling Applying' and 'Sibling Attending'.
 */
public interface DynamicSiblingPriorityService {
  /**
   * Upgrades sibling priority to 'Sibling Attending' when a student receives an offer.
   * Called when AcademicInterest.Status changes to 'Pre-Offer' or 'Seat Offered'.
   * @param individualApplicationIds IDs of applications that received offers
   */
  void handleUpgrade(Set<Id> individualApplicationIds);

  /**
   * Downgrades sibling priority to 'Sibling Applying' when a student loses all offers.
   * Called when AcademicInterest.Status changes to 'Rescinded' or 'Withdrawn/Declined'.
   * Only downgrades if the student has no remaining offers.
   * @param individualApplicationIds IDs of applications that lost offers
   */
  void handleDowngrade(Set<Id> individualApplicationIds);
}