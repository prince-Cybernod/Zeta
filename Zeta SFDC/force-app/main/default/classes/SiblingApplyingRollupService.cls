/**
 * Service for recalculating the Sibling Applying rollup count.
 */
public interface SiblingApplyingRollupService {
  /**
   * Recalculates {@link IndividualApplication.Count_of_Sibling_Applying__c} for the given IDs.
   * Counts approved Priority Items with Priority_Type = 'Sibling Applying'.
   * @param individualApplicationIds IDs of Individual Applications to recalculate
   */
  void recalculate(Set<Id> individualApplicationIds);
}