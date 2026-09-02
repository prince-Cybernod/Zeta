/**
 * Tests for {@link IndividualApplication}.
 */
@IsTest(IsParallel=true)
private class IndividualApplicationTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new IndividualApplicationTriggerRunner());
  }

  private class IndividualApplicationTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new IndividualApplication();
    }
  }
}