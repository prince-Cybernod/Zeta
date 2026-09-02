/**
 * Base class that runs an {@link ApexTrigger} to meet code coverage requirements.
 */
@IsTest
public class TriggerTest {
  private final TriggerHandlerProviderMock triggerHandlerProvider;
  private final TriggerHandlerMock triggerHandler;

  public TriggerTest() {
    triggerHandlerProvider = new TriggerHandlerProviderMock();
    triggerHandler = new TriggerHandlerMock();

    TriggerHandlerRunner.triggerHandlerProvider = triggerHandlerProvider;
  }

  /**
   * Runs the trigger and asserts that it was called the expected number of times.
   */
  public void runTriggerAndAssert(TriggerTestRunner triggerRunnerForTest) {
    // Returns the list of `triggerHandler` multiple times because triggers can run other triggers
    triggerHandlerProvider.when(triggerHandlerProvider.method.get())
      .thenReturn(new List<TriggerHandler>{ triggerHandler })
      .thenReturn(new List<TriggerHandler>{ triggerHandler })
      .thenReturn(new List<TriggerHandler>{ triggerHandler });
    triggerHandler.when(triggerHandler.method.onBeforeInsert()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onBeforeUpdate()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onBeforeDelete()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onAfterInsert()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onAfterUpdate()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onAfterDelete()).thenReturnVoid();
    triggerHandler.when(triggerHandler.method.onAfterUndelete()).thenReturnVoid();

    try {
      triggerRunnerForTest.insertSObject();
    } catch (DmlException e) {
      System.debug('Preventing the test from failing due to a DML exception.');
      System.debug('We just want to cause the trigger to run in this case.');
    }

    Integer providerCalls = triggerHandlerProvider.getCallCount(
      triggerHandlerProvider.method.get()
    );
    Assert.isTrue(providerCalls > 0, 'Expected the trigger handler to be provided at least once');
    List<Integer> triggerHandlerCalls = new List<Integer>{
      triggerHandler.getCallCount(triggerHandler.method.onBeforeInsert()),
      triggerHandler.getCallCount(triggerHandler.method.onBeforeUpdate()),
      triggerHandler.getCallCount(triggerHandler.method.onBeforeDelete()),
      triggerHandler.getCallCount(triggerHandler.method.onAfterInsert()),
      triggerHandler.getCallCount(triggerHandler.method.onAfterUpdate()),
      triggerHandler.getCallCount(triggerHandler.method.onAfterDelete()),
      triggerHandler.getCallCount(triggerHandler.method.onAfterUndelete())
    };
    Boolean hasTriggerHandlerCall = false;
    for (Integer triggerHandlerCall : triggerHandlerCalls) {
      if (triggerHandlerCall > 0) {
        hasTriggerHandlerCall = true;
        break;
      }
    }
    Assert.isTrue(hasTriggerHandlerCall, 'Expected the trigger handler to be called at least once');
  }
}