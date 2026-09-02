/**
 * Service for sorting waitlisted students and assigning positions.
 */
public interface WaitlistSortService {
  /**
   * Sorts AcademicInterest records by waitlist priority and assigns sequential positions.
   *
   * Sort order:
   * 1. Current_Priority_Group__c ASC (1=Sibling first, 4=General last)
   * 2. Within same group: students WITHOUT Date_of_Current_Priority_Change__c first
   * 3. Then by: Randomized_Sort_Key__c ASC (or CreatedDate if null)
   * 4. Tie-breaker: CreatedDate ASC
   *
   * After sorting, assigns sequential Waitlist_Position__c values (1, 2, 3...).
   *
   * @param records List of waitlisted AcademicInterest records to sort
   * @return The same records with Waitlist_Position__c assigned
   */
  List<AcademicInterest> sortAndAssignPositions(List<AcademicInterest> records);
}