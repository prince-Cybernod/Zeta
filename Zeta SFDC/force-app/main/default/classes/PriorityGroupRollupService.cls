/**
 * Service for recalculating the Priority Group MIN rollup.
 */
public interface PriorityGroupRollupService {
  /**
   * Recalculates {@link IndividualApplication.Relationship_Priority_Group__c} for the given IDs.
   * Sets the field to the MIN of {@link Priority_Item__c.Priority_Group__c} where Review_Status is Approved.
   * @param individualApplicationIds IDs of Individual Applications to recalculate
   */
  void recalculate(Set<Id> individualApplicationIds);
}