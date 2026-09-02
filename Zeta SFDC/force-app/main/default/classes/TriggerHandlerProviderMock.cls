/**
 * {@link Mock} implementation of {@link TriggerHandlerProvider}.
 */
@IsTest
@SuppressWarnings('PMD.CognitiveComplexity')
public class TriggerHandlerProviderMock extends Mock implements TriggerHandlerProvider {
  public final Method method = new Method();

  public List<TriggerHandler> get(SObjectType sobjectType) {
    return (List<TriggerHandler>) mockedCall(
      method.get(),
      new Map<String, Object>{ 'sobjectType' => sobjectType }
    );
  }

  public class Method {
    public String get() {
      return new ExecutionInfo().getFullName();
    }
  }
}