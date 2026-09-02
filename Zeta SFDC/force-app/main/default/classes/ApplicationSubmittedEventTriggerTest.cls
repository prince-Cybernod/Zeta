/**
 * Tests for {@link ApplicationSubmittedEventTrigger}.
 */
@IsTest(IsParallel=true)
private class ApplicationSubmittedEventTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new ApplicationSubmittedEventTriggerRunner());
  }

  private class ApplicationSubmittedEventTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      EventBus.publish(
        new Application_Submitted_Event__e(
          Application_Id__c = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType)
        )
      );
      Test.getEventBus().deliver();
    }
  }
}