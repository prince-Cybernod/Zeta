/**
 * Tests for {@link Lead}.
 */
@IsTest(IsParallel=true)
private class LeadTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new LeadTriggerRunner());
  }

  private class LeadTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new Lead();
    }
  }
}