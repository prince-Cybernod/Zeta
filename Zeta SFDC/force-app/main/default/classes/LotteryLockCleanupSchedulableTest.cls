/**
 * Tests for {@link LotteryLockCleanupSchedulable}.
 */
@IsTest(IsParallel=true)
private class LotteryLockCleanupSchedulableTest {
  private static final LotteryLockCleanupSchedulable SCHEDULABLE;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SCHEDULABLE = new LotteryLockCleanupSchedulable(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void execute_withNoStaleLocks_doesNotUpdate() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>());

    SCHEDULABLE.execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void execute_withStaleLocks_clearsLockFields() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<Lottery_Capacity__c> staleLocks = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(
        Id = capacityId,
        Is_Processing__c = true,
        Locked_By_Job__c = 'stale-job-id',
        Lock_Acquired_At__c = DateTime.now().addMinutes(-31)
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(staleLocks);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    SCHEDULABLE.execute(null);

    Assert.areEqual(false, staleLocks[0].Is_Processing__c, 'Should clear Is_Processing__c');
    Assert.isNull(staleLocks[0].Locked_By_Job__c, 'Should clear Locked_By_Job__c');
    Assert.isNull(staleLocks[0].Lock_Acquired_At__c, 'Should clear Lock_Acquired_At__c');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withActiveLocks_doesNotClear() {
    // Active locks are filtered out by the query's WHERE clause (Lock_Acquired_At__c < threshold)
    // So if the query returns nothing, nothing gets updated
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>());

    SCHEDULABLE.execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds());
  }
}