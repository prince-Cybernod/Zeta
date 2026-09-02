/**
 * Implementation of {@link LotteryLockService}.
 *
 * Security model: Uses `with sharing` for row-level access control with
 * `SystemModeDatabaseRepo` for field-level writes. This is intentional because
 * lottery locking is admin-only and requires updating Lottery_Capacity__c fields
 * that may have restrictive FLS for regular users.
 */
public with sharing class LotteryLockServiceImpl implements LotteryLockService {
  @TestVisible
  private static final Integer LOCK_TIMEOUT_MINUTES = 30;

  private final DatabaseRepo databaseRepo;

  public LotteryLockServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryLockServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public String acquireLock(Set<Id> capacityIds) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      throw new LotteryLockException('Cannot acquire lock: no capacity IDs provided');
    }

    String jobId = generateJobId();

    // Use FOR UPDATE for atomic check-and-set within this transaction
    String query =
      'SELECT Id, Is_Processing__c, Locked_By_Job__c, Lock_Acquired_At__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds ' +
      'FOR UPDATE';
    List<Lottery_Capacity__c> caps = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );

    for (Lottery_Capacity__c c : caps) {
      if (c.Is_Processing__c && !isLockStale(c)) {
        throw new LotteryLockException(
          String.format(
            'Capacity {0} is locked by job {1}',
            new List<Object>{ c.Id, c.Locked_By_Job__c }
          )
        );
      }
    }

    for (Lottery_Capacity__c c : caps) {
      c.Is_Processing__c = true;
      c.Locked_By_Job__c = jobId;
      c.Lock_Acquired_At__c = DateTime.now();
    }
    databaseRepo.updateSObjects(caps);

    return jobId;
  }

  public void verifyLock(Set<Id> capacityIds, String jobId) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT Id, Locked_By_Job__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds';
    List<Lottery_Capacity__c> caps = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );

    for (Lottery_Capacity__c c : caps) {
      if (c.Locked_By_Job__c != jobId) {
        throw new LotteryLockException(
          String.format('Lock lost on capacity {0}', new List<Object>{ c.Id })
        );
      }
    }
  }

  public void releaseLock(Set<Id> capacityIds, String jobId) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT Id, Locked_By_Job__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds ' +
      'AND Locked_By_Job__c = :jobId';
    List<Lottery_Capacity__c> caps = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds, 'jobId' => jobId }
    );

    for (Lottery_Capacity__c c : caps) {
      c.Is_Processing__c = false;
      c.Locked_By_Job__c = null;
      c.Lock_Acquired_At__c = null;
    }
    databaseRepo.updateSObjects(caps);
  }

  private Boolean isLockStale(Lottery_Capacity__c c) {
    return c.Lock_Acquired_At__c < DateTime.now().addMinutes(-LOCK_TIMEOUT_MINUTES);
  }

  @TestVisible
  private String generateJobId() {
    return UUID.randomUUID().toString();
  }
}