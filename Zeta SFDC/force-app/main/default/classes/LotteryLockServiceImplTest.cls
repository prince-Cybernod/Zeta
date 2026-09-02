/**
 * Tests for {@link LotteryLockServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LotteryLockServiceImplTest {
  private static final LotteryLockServiceImpl SERVICE;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SERVICE = new LotteryLockServiceImpl(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void acquireLock_withNullInput_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(LotteryLockException.class);

    try {
      SERVICE.acquireLock(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void acquireLock_withEmptySet_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(LotteryLockException.class);

    try {
      SERVICE.acquireLock(new Set<Id>());
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void acquireLock_withUnlockedCapacities_acquiresLockAndReturnsJobId() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<Lottery_Capacity__c> unlocked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId, Is_Processing__c = false)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(unlocked);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    String jobId = SERVICE.acquireLock(new Set<Id>{ capacityId });

    Assert.isNotNull(jobId, 'Should return a job ID');
    Assert.areEqual(true, unlocked[0].Is_Processing__c, 'Should set Is_Processing__c to true');
    Assert.areEqual(jobId, unlocked[0].Locked_By_Job__c, 'Should set Locked_By_Job__c to job ID');
    Assert.isNotNull(
      unlocked[0].Lock_Acquired_At__c,
      'Should set Lock_Acquired_At__c to current time'
    );
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void acquireLock_withLockedCapacity_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<Lottery_Capacity__c> locked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(
        Id = capacityId,
        Is_Processing__c = true,
        Locked_By_Job__c = 'existing-job-id',
        Lock_Acquired_At__c = DateTime.now()
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(locked);

    AssertThrows.Throwing throwing = AssertThrows.with(LotteryLockException.class);

    try {
      SERVICE.acquireLock(new Set<Id>{ capacityId });
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void acquireLock_withStaleLock_overridesLock() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<Lottery_Capacity__c> staleLocked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(
        Id = capacityId,
        Is_Processing__c = true,
        Locked_By_Job__c = 'old-job-id',
        Lock_Acquired_At__c = DateTime.now().addMinutes(-31)
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(staleLocked);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    String jobId = SERVICE.acquireLock(new Set<Id>{ capacityId });

    Assert.isNotNull(jobId, 'Should return a new job ID');
    Assert.areNotEqual('old-job-id', jobId, 'Should not be the old job ID');
    Assert.areEqual(jobId, staleLocked[0].Locked_By_Job__c, 'Should override with new job ID');
  }

  @IsTest
  private static void verifyLock_withNullInput_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.verifyLock(null, 'job-id');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void verifyLock_withEmptySet_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.verifyLock(new Set<Id>(), 'job-id');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void verifyLock_withMatchingJobId_doesNotThrow() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    String jobId = 'my-job-id';
    List<Lottery_Capacity__c> locked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId, Locked_By_Job__c = jobId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(locked);

    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.verifyLock(new Set<Id>{ capacityId }, jobId);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void verifyLock_withDifferentJobId_throwsException() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<Lottery_Capacity__c> locked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(Id = capacityId, Locked_By_Job__c = 'different-job')
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(locked);

    AssertThrows.Throwing throwing = AssertThrows.with(LotteryLockException.class);

    try {
      SERVICE.verifyLock(new Set<Id>{ capacityId }, 'my-job-id');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void releaseLock_withNullInput_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.releaseLock(null, 'job-id');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void releaseLock_withEmptySet_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.releaseLock(new Set<Id>(), 'job-id');
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void releaseLock_withMatchingJobId_clearsLockFields() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    String jobId = 'my-job-id';
    List<Lottery_Capacity__c> locked = new List<Lottery_Capacity__c>{
      new Lottery_Capacity__c(
        Id = capacityId,
        Is_Processing__c = true,
        Locked_By_Job__c = jobId,
        Lock_Acquired_At__c = DateTime.now()
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(locked);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    SERVICE.releaseLock(new Set<Id>{ capacityId }, jobId);

    Assert.areEqual(false, locked[0].Is_Processing__c, 'Should clear Is_Processing__c');
    Assert.isNull(locked[0].Locked_By_Job__c, 'Should clear Locked_By_Job__c');
    Assert.isNull(locked[0].Lock_Acquired_At__c, 'Should clear Lock_Acquired_At__c');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void releaseLock_withNonMatchingJobId_doesNotRelease() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    // Query returns empty because WHERE clause filters by jobId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Lottery_Capacity__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    SERVICE.releaseLock(new Set<Id>{ capacityId }, 'wrong-job-id');

    // doUpdate should still be called but with empty list
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }
}