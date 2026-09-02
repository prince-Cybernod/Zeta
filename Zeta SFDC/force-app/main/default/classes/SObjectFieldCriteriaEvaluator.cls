/**
 * Evaluates boolean criteria defined in SObject_Field_Criteria__mdt against SObject sobjs.
 */
public interface SObjectFieldCriteriaEvaluator {
  /**
   * Evaluates the criteria formula against the provided record.
   *
   * @param criteria The SObject_Field_Criteria__mdt record containing the formula expression
   * @param sobj The SObject sobj to evaluate the criteria against
   * @return true if the record meets the criteria, false otherwise
   * @throws IllegalArgumentException if criteria is null, inactive, or has invalid formula
   */
  Boolean evaluate(SObject_Field_Criteria__mdt criteria, SObject sobj);

  /**
   * Returns the set of field API names referenced in the formula expression.
   * Use this to determine which fields need to be queried before evaluation.
   *
   * @param criteria The SObject_Field_Criteria__mdt record containing the formula expression
   * @return Set of field API names referenced in the formula
   * @throws IllegalArgumentException if criteria is null or has invalid formula
   */
  Set<String> getReferencedFields(SObject_Field_Criteria__mdt criteria);
}