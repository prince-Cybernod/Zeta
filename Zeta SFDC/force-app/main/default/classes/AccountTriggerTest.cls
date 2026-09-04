/**
 * Tests for {@link Account}.
 */
@IsTest(IsParallel=true)
private class AccountTriggerTest {
  @IsTest
  private static void runsTheTrigger() {
    TriggerTest triggerTest = new TriggerTest();
    triggerTest.runTriggerAndAssert(new AccountTriggerRunner());
  }

  private class AccountTriggerRunner extends TriggerTestRunner {
    public override void insertSObject() {
      insert as user new Account(
        RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
          .get('Student')
          .getRecordTypeId(),
        FirstName = 'Trigger',
        LastName = 'TriggerTest',
        PersonBirthdate = Date.newInstance(2015, 1, 1)
      );
    }
  }
}