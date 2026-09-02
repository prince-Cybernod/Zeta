/**
 * Service interface for lottery audit logging.
 *
 * Creates and manages Lottery_Run_Log__c and Lottery_Run_Result__c
 * records for audit trail and compliance.
 */
public interface LotteryAuditLogService {
  /**
   * Creates a new Lottery_Run_Log__c record for the given timeline.
   *
   * @param applicationTimelineId The Application Timeline to associate
   * @return The created Lottery_Run_Log__c record Id
   */
  Id createLotteryRunLog(Id applicationTimelineId);

  /**
   * Creates Lottery_Run_Result__c records from lottery transitions.
   *
   * @param runLogId The Lottery_Run_Log__c to link results to
   * @param result The LotteryRunResult containing transitions
   * @return Number of results created
   */
  Integer createLotteryRunResults(Id runLogId, LotteryRunResult result);

  /**
   * Updates Lottery_Capacity__c records with the run log reference.
   *
   * @param runLogId The Lottery_Run_Log__c Id
   * @param capacityIds The Lottery_Capacity__c Ids to update
   */
  void linkCapacitiesToRun(Id runLogId, Set<Id> capacityIds);

  /**
   * Publishes the lottery run - sets status and publish date.
   *
   * @param runLogId The Lottery_Run_Log__c to publish
   */
  void publishLotteryRun(Id runLogId);

  /**
   * Rolls back (deletes) an unpublished lottery run and resets all affected records.
   * Only works for runs with Status__c = 'Not Published' and ApplicationTimeline.Test__c = true.
   *
   * @param runLogId The Lottery_Run_Log__c to rollback
   * @return LotteryRollbackResult with counts of affected records
   */
  LotteryRollbackResult rollbackLotteryRun(Id runLogId);

  /**
   * Prepares a rollback by unlinking capacities and deleting audit records.
   * Does NOT reset AcademicInterests - use rollbackAcademicInterestsBatch for that.
   * Only works for runs with Status__c = 'Draft' and ApplicationTimeline.Test__c = true.
   *
   * @param runLogId The Lottery_Run_Log__c to rollback
   * @return RollbackPrepareResult with capacityIds for batched reset
   */
  RollbackPrepareResult prepareRollback(Id runLogId);

  /**
   * Resets a batch of AcademicInterests to Eligible status.
   * Uses keyset pagination for CPU-safe processing of large datasets.
   *
   * @param capacityIds The Lottery_Capacity__c IDs to filter records
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return RollbackBatchResult with resetCount, cursor, and hasMore flag
   */
  RollbackBatchResult rollbackAcademicInterestsBatch(
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  );

  /**
   * Creates Lottery_Run_Result__c audit records from the final state of processed records.
   * Used by sequential execution flow where transitions are not accumulated in memory.
   *
   * @param runLogId The Lottery_Run_Log__c to link results to
   * @param capacityIds The Lottery_Capacity__c Ids that were processed
   * @return Number of audit records created
   */
  Integer createAuditRecords(Id runLogId, Set<Id> capacityIds);

  /**
   * Batched version of createAuditRecords using keyset pagination.
   * Creates Lottery_Run_Result__c audit records in chunks to avoid DML limits.
   * Note: Paginates by Id order (not priority/sort order). Lottery numbers are
   * sequential across batches via startLotteryNumber chaining but reflect Id order
   * rather than priority group order. Priority and sort key fields on each record
   * preserve the true selection ordering.
   *
   * @param runLogId The Lottery_Run_Log__c to link results to
   * @param capacityIds The Lottery_Capacity__c Ids that were processed
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @param startLotteryNumber Starting lottery number for this batch (1 for first batch)
   * @return CreateAuditBatchResult with recordsCreated, cursor, nextLotteryNumber, and hasMore flag
   */
  CreateAuditBatchResult createAuditRecordsBatch(
    Id runLogId,
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize,
    Integer startLotteryNumber
  );
}