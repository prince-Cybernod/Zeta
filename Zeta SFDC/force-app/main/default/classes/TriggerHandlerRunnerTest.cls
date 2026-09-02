/**
 * Tests for {@link TriggerHandlerRunner}.
 */
@IsTest(IsParallel=true)
private class TriggerHandlerRunnerTest {
  private static final TriggerHandlerProviderMock TRIGGER_HANDLER_PROVIDER_MOCK;
  private static final TriggerHandlerMock TRIGGER_HANDLER_MOCK;

  static {
    TRIGGER_HANDLER_PROVIDER_MOCK = new TriggerHandlerProviderMock();
    TRIGGER_HANDLER_MOCK = new TriggerHandlerMock();

    // Returns the list of `triggerHandler` multiple times because triggers can run other triggers
    TRIGGER_HANDLER_PROVIDER_MOCK.when(TRIGGER_HANDLER_PROVIDER_MOCK.method.get())
      .thenReturn(new List<TriggerHandler>{ TRIGGER_HANDLER_MOCK })
      .thenReturn(new List<TriggerHandler>{ TRIGGER_HANDLER_MOCK })
      .thenReturn(new List<TriggerHandler>{ TRIGGER_HANDLER_MOCK });

    TriggerHandlerRunner.triggerHandlerProvider = TRIGGER_HANDLER_PROVIDER_MOCK;
  }

  @IsTest
  private static void run_emptySObjectLists_throws() {
    List<SObject> sobjects = new List<SObject>();
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>();
    TriggerOperation triggerOperation = TriggerOperation.BEFORE_INSERT;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected to get the SObjectType from the records in the trigger, but got null. Trigger.new contained 0 records and Trigger.oldMap contained 0 records.'
    );

    try {
      TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void run_nullTriggerOperation_throws() {
    List<SObject> sobjects = new List<Account>{ new Account() };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>();
    TriggerOperation triggerOperation = null;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Attempted to run unexpected Trigger Operation: null'
    );

    try {
      TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void run_beforeInsert_runsOnBeforeInsert() {
    List<SObject> sobjects = new List<SObject>{ new Account() };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>();
    TriggerOperation triggerOperation = TriggerOperation.BEFORE_INSERT;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onBeforeInsert()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onBeforeInsert());
  }

  @IsTest
  private static void run_beforeUpdate_runsOnBeforeUpdate() {
    Id accountId = SObjectIds.generateFakeId(Account.SObjectType);
    List<SObject> sobjects = new List<SObject>{ new Account(Id = accountId) };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>{
      accountId => new Account(Id = accountId)
    };
    TriggerOperation triggerOperation = TriggerOperation.BEFORE_UPDATE;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onBeforeUpdate()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onBeforeUpdate());
  }

  @IsTest
  private static void run_beforeDelete_runsOnBeforeDelete() {
    Id accountId = SObjectIds.generateFakeId(Account.SObjectType);
    List<SObject> sobjects = new List<SObject>();
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>{
      accountId => new Account(Id = accountId)
    };
    TriggerOperation triggerOperation = TriggerOperation.BEFORE_DELETE;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onBeforeDelete()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onBeforeDelete());
  }

  @IsTest
  private static void run_afterInsert_runsOnAfterInsert() {
    List<SObject> sobjects = new List<SObject>{ new Account() };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>();
    TriggerOperation triggerOperation = TriggerOperation.AFTER_INSERT;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onAfterInsert()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onAfterInsert());
  }

  @IsTest
  private static void run_afterUpdate_runsOnAfterUpdate() {
    Id accountId = SObjectIds.generateFakeId(Account.SObjectType);
    List<SObject> sobjects = new List<SObject>{ new Account(Id = accountId) };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>{
      accountId => new Account(Id = accountId)
    };
    TriggerOperation triggerOperation = TriggerOperation.AFTER_UPDATE;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onAfterUpdate()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onAfterUpdate());
  }

  @IsTest
  private static void run_afterDelete_runsOnAfterDelete() {
    Id accountId = SObjectIds.generateFakeId(Account.SObjectType);
    List<SObject> sobjects = new List<SObject>();
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>{
      accountId => new Account(Id = accountId)
    };
    TriggerOperation triggerOperation = TriggerOperation.AFTER_DELETE;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onAfterDelete()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onAfterDelete());
  }

  @IsTest
  private static void run_afterUndelete_runsOnAfterUndelete() {
    Id accountId = SObjectIds.generateFakeId(Account.SObjectType);
    List<SObject> sobjects = new List<SObject>{ new Account(Id = accountId) };
    Map<Id, SObject> oldSObjectsByIds = new Map<Id, SObject>();
    TriggerOperation triggerOperation = TriggerOperation.AFTER_UNDELETE;
    TRIGGER_HANDLER_MOCK.when(TRIGGER_HANDLER_MOCK.method.onAfterUndelete()).thenReturnVoid();

    TriggerHandlerRunner.run(sobjects, oldSObjectsByIds, triggerOperation);

    TRIGGER_HANDLER_MOCK.verify(TRIGGER_HANDLER_MOCK.method.onAfterUndelete());
  }
}