/**
 * Tests for {@link AcademicInterest}.
 */
@IsTest(IsParallel=true)
private class AcademicInterestTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new AcademicInterestTriggerRunner());
  }

  private class AcademicInterestTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new AcademicInterest();
    }
  }
}