/**
 * Tests for {@link LearningProgram}.
 */
@IsTest(IsParallel=true)
private class LearningProgramTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new LearningProgramTriggerRunner());
  }

  private class LearningProgramTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new LearningProgram();
    }
  }
}