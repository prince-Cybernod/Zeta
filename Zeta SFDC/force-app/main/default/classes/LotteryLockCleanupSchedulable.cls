/**
 * Scheduled job that cleans up stale lottery locks.
 *
 * Locks older than 30 minutes are considered stale and are cleared.
 * This prevents capacity records from being permanently locked due to
 * job failures or timeouts.
 *
 * Schedule example (hourly):
 * System.schedule('Lottery Lock Cleanup', '0 0 * * * ?', new LotteryLockCleanupSchedulable());
 */
public with sharing class LotteryLockCleanupSchedulable implements Schedulable {
  @TestVisible
  private static final Integer LOCK_TIMEOUT_MINUTES = 30;

  private final DatabaseRepo databaseRepo;

  public LotteryLockCleanupSchedulable() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryLockCleanupSchedulable(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void execute(SchedulableContext sc) {
    DateTime staleThreshold = DateTime.now().addMinutes(-LOCK_TIMEOUT_MINUTES);

    String query =
      'SELECT Id, Is_Processing__c, Locked_By_Job__c, Lock_Acquired_At__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Is_Processing__c = true ' +
      'AND Lock_Acquired_At__c < :staleThreshold';

    List<Lottery_Capacity__c> staleLocks = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'staleThreshold' => staleThreshold }
    );

    if (staleLocks.isEmpty()) {
      return;
    }

    for (Lottery_Capacity__c c : staleLocks) {
      c.Is_Processing__c = false;
      c.Locked_By_Job__c = null;
      c.Lock_Acquired_At__c = null;
    }

    databaseRepo.updateSObjects(staleLocks);
  }
}