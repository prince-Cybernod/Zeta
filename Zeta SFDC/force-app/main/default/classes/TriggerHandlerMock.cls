/**
 * {@link Mock} implementation of {@link TriggerHandler}.
 *
 * This is {@code private} so that it is not found when {@link TriggerHandlerProviderImpl} queries
 * {@link ApexTypeImplementor}. It is {@code @TestVisible} so that we can still use it in tests.
 */
@IsTest
@TestVisible
@SuppressWarnings('PMD.CognitiveComplexity')
private class TriggerHandlerMock extends Mock implements TriggerHandler {
  public final Method method = new Method();

  public SObjectType getSObjectType() {
    return (SObjectType) mockedCall(method.getSObjectType(), new Map<String, Object>());
  }

  public void onBeforeInsert(List<SObject> sobjects) {
    mockedCall(method.onBeforeInsert(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void onBeforeUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    mockedCall(
      method.onBeforeUpdate(),
      new Map<String, Object>{ 'sobjects' => sobjects, 'oldSObjectsByIds' => oldSObjectsByIds }
    );
  }

  public void onBeforeDelete(List<SObject> sobjects) {
    mockedCall(method.onBeforeDelete(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void onAfterInsert(List<SObject> sobjects) {
    mockedCall(method.onAfterInsert(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    mockedCall(
      method.onAfterUpdate(),
      new Map<String, Object>{ 'sobjects' => sobjects, 'oldSObjectsByIds' => oldSObjectsByIds }
    );
  }

  public void onAfterDelete(List<SObject> oldSObjects) {
    mockedCall(method.onAfterDelete(), new Map<String, Object>{ 'oldSObjects' => oldSObjects });
  }

  public void onAfterUndelete(List<SObject> sobjects) {
    mockedCall(method.onAfterUndelete(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public class Method {
    public String getSObjectType() {
      return new ExecutionInfo().getFullName();
    }

    public String onBeforeInsert() {
      return new ExecutionInfo().getFullName();
    }

    public String onBeforeUpdate() {
      return new ExecutionInfo().getFullName();
    }

    public String onBeforeDelete() {
      return new ExecutionInfo().getFullName();
    }

    public String onAfterInsert() {
      return new ExecutionInfo().getFullName();
    }

    public String onAfterUpdate() {
      return new ExecutionInfo().getFullName();
    }

    public String onAfterDelete() {
      return new ExecutionInfo().getFullName();
    }

    public String onAfterUndelete() {
      return new ExecutionInfo().getFullName();
    }
  }
}