/**
 * Service for managing application-level locking on lottery capacity records.
 *
 * Since FOR UPDATE only holds locks within a single transaction, this service
 * implements custom lock fields that persist across multiple transactions,
 * enabling the sequential sync execution model.
 *
 * Lock fields on Lottery_Capacity__c:
 * - Is_Processing__c: Quick boolean check for lock status
 * - Locked_By_Job__c: UUID identifying the lock holder
 * - Lock_Acquired_At__c: Timestamp for stale lock detection
 */
public interface LotteryLockService {
  /**
   * Acquires lock on capacity records for lottery processing.
   * Uses FOR UPDATE for atomic check-and-set within this transaction.
   * Stale locks (>30 min) are automatically overridden.
   *
   * @param capacityIds Set of Lottery_Capacity__c IDs to lock
   * @return String UUID jobId for subsequent verify/release calls
   * @throws LotteryLockException if any capacity is locked by active job
   */
  String acquireLock(Set<Id> capacityIds);

  /**
   * Verifies the caller still holds the lock on all capacities.
   * Call at the start of each step to detect concurrent modification.
   *
   * @param capacityIds Set of Lottery_Capacity__c IDs to verify
   * @param jobId The job ID that should hold the lock
   * @throws LotteryLockException if lock was lost or taken by another job
   */
  void verifyLock(Set<Id> capacityIds, String jobId);

  /**
   * Releases lock on capacity records after processing completes.
   * Only releases if the caller's jobId matches the current lock holder.
   *
   * @param capacityIds Set of Lottery_Capacity__c IDs to unlock
   * @param jobId The job ID that holds the lock
   */
  void releaseLock(Set<Id> capacityIds, String jobId);
}