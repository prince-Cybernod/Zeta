/**
 * Tests for {@link PriorityItem}.
 */
@IsTest(IsParallel=true)
private class PriorityItemTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new PriorityItemTriggerRunner());
  }

  private class PriorityItemTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new Priority_Item__c();
    }
  }
}