/**
 * Service for recalculating the Employee Priority rollup count on LearningProgram.
 */
public interface EmployeePriorityRollupService {
  /**
   * Recalculates {@link LearningProgram.Count_Lottery_Employee_Priority__c} for programs
   * associated with the given Individual Applications.
   * Counts approved Priority Items with Priority_Type = 'Parent is Zeta Staff'.
   * @param individualApplicationIds IDs of Individual Applications whose programs should be recalculated
   */
  void recalculate(Set<Id> individualApplicationIds);
}