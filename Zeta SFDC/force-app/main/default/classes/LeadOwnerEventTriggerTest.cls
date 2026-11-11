/**
 * Tests for {@link LeadOwnerEventTrigger}.
 */
@IsTest(IsParallel=true)
private class LeadOwnerEventTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new LeadOwnerEventTriggerRunner());
  }

  private class LeadOwnerEventTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      Lead_Owner_Event__e event = new Lead_Owner_Event__e(
        Owner_Id__c = SObjectIds.generateFakeId(Schema.User.SObjectType)
      );

      EventBus.publish(event);
      Test.getEventBus().deliver();
    }
  }
}