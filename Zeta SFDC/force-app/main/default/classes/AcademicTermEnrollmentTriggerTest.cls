/**
 * Tests for {@link AcademicTermEnrollment}.
 */
@IsTest(IsParallel=true)
private class AcademicTermEnrollmentTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new AcademicTermEnrollmentTriggerRunner());
  }

  private class AcademicTermEnrollmentTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new AcademicTermEnrollment();
    }
  }
}