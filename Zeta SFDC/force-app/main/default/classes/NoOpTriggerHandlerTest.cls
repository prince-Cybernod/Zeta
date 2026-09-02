/**
 * Tests for {@link NoOpTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class NoOpTriggerHandlerTest {
  @IsTest
  private static void runEachMethod_doesNothing() {
    AccountNoOpTriggerHandler accountNoOpTriggerHandler = new AccountNoOpTriggerHandler();
    List<Account> accounts = new List<Account>();
    Map<Id, Account> oldAccountsByIds = new Map<Id, Account>();

    SObjectType sobjectType = accountNoOpTriggerHandler.getSObjectType();
    accountNoOpTriggerHandler.onBeforeInsert(accounts);
    accountNoOpTriggerHandler.onBeforeUpdate(accounts, oldAccountsByIds);
    accountNoOpTriggerHandler.onBeforeDelete(accounts);
    accountNoOpTriggerHandler.onAfterInsert(accounts);
    accountNoOpTriggerHandler.onAfterUpdate(accounts, oldAccountsByIds);
    accountNoOpTriggerHandler.onAfterDelete(accounts);
    accountNoOpTriggerHandler.onAfterUndelete(accounts);

    Assert.areEqual(Account.SObjectType, sobjectType);
  }

  private class AccountNoOpTriggerHandler extends NoOpTriggerHandler {
    public override SObjectType getSObjectType() {
      return Account.SObjectType;
    }
  }
}