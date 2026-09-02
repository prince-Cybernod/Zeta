/**
 * Implementation of {@link SObjectFieldCriteriaEvaluator} using the FormulaEval API.
 */
public with sharing class SObjectFieldCriteriaEvaluatorImpl implements SObjectFieldCriteriaEvaluator {
  public Boolean evaluate(SObject_Field_Criteria__mdt criteria, SObject sobj) {
    validateCriteria(criteria);
    Preconditions.checkNotNull(sobj, 'SObject cannot be null');

    try {
      FormulaEval.FormulaInstance formula = buildFormulaInstance(criteria);
      Object result = formula.evaluate(sobj);
      return (Boolean) result;
    } catch (Exception e) {
      throw new IllegalArgumentException(
        String.format(
          'Failed to evaluate criteria "{0}": {1}',
          new List<Object>{ criteria.MasterLabel, e.getMessage() }
        ),
        e
      );
    }
  }

  public Set<String> getReferencedFields(SObject_Field_Criteria__mdt criteria) {
    validateCriteria(criteria);

    try {
      FormulaEval.FormulaInstance formula = buildFormulaInstance(criteria);
      return formula.getReferencedFields();
    } catch (Exception e) {
      throw new IllegalArgumentException(
        String.format(
          'Failed to get referenced fields for criteria "{0}": {1}',
          new List<Object>{ criteria.MasterLabel, e.getMessage() }
        ),
        e
      );
    }
  }

  private static void validateCriteria(SObject_Field_Criteria__mdt criteria) {
    Preconditions.checkNotNull(criteria, 'Criteria cannot be null');
    Preconditions.checkArgument(
      String.isNotBlank(criteria.Formula_Expression__c),
      'Formula Expression cannot be blank'
    );
    Preconditions.checkArgument(
      String.isNotBlank(criteria.Entity_Definition__r?.QualifiedApiName),
      'Entity Definition cannot be blank'
    );
  }

  private static FormulaEval.FormulaInstance buildFormulaInstance(
    SObject_Field_Criteria__mdt criteria
  ) {
    String sobjectApiName = criteria.Entity_Definition__r.QualifiedApiName;
    Type sobjectType = Type.forName(sobjectApiName);

    return Formula.builder()
      .withType(sobjectType)
      .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
      .withFormula(criteria.Formula_Expression__c)
      .build();
  }
}