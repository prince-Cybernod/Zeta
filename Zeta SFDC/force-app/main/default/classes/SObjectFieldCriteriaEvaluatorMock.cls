/**
 * {@link Mock} implementation of {@link SObjectFieldCriteriaEvaluator}.
 */
@IsTest
public class SObjectFieldCriteriaEvaluatorMock extends Mock implements SObjectFieldCriteriaEvaluator {
  public final Method method = new Method();

  public Boolean evaluate(SObject_Field_Criteria__mdt criteria, SObject sobj) {
    return (Boolean) mockedCall(
      method.evaluate(),
      new Map<String, Object>{ 'criteria' => criteria, 'sobj' => sobj }
    );
  }

  public Set<String> getReferencedFields(SObject_Field_Criteria__mdt criteria) {
    return (Set<String>) mockedCall(
      method.getReferencedFields(),
      new Map<String, Object>{ 'criteria' => criteria }
    );
  }

  public class Method {
    public String evaluate() {
      return new ExecutionInfo().getFullName();
    }

    public String getReferencedFields() {
      return new ExecutionInfo().getFullName();
    }
  }
}