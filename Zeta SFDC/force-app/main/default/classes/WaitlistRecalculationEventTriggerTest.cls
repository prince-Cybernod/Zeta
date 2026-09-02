/**
 * Tests for {@link WaitlistRecalculationEventTrigger}.
 */
@IsTest(IsParallel=true)
private class WaitlistRecalculationEventTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new WaitlistRecalculationEventTriggerRunner());
  }

  private class WaitlistRecalculationEventTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      Waitlist_Recalculation_Event__e event = new Waitlist_Recalculation_Event__e(
        Lottery_Capacity_Id__c = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType)
      );

      EventBus.publish(event);
      Test.getEventBus().deliver();
    }
  }
}