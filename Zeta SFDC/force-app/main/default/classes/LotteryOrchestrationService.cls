/**
 * Service for orchestrating the complete lottery execution process.
 *
 * The lottery process:
 * 1. Assigns randomized sort keys to all eligible records
 * 2. Processes grades lowest-first (K before 1, 1 before 2, etc.)
 * 3. Within each grade, processes priority groups 1→4
 * 4. Makes pre-offers to students within capacity
 * 5. Optimizes offers (one per student)
 * 6. Transitions remaining eligible to waitlist
 * 7. Publishes waitlist recalculation events
 */
public interface LotteryOrchestrationService {
  /**
   * Runs the lottery for a set of Lottery_Capacity records.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @return Result containing counts of offers made, rescinded, and waitlisted
   */
  LotteryRunResult runLottery(Set<Id> lotteryCapacityIds);

  /**
   * Runs the lottery for a set of Lottery_Capacity records with date filtering.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @param startDate Optional start date filter for applied date (Application_Submitted_Date__c)
   * @param endDate Optional end date filter for applied date (Application_Submitted_Date__c)
   * @return Result containing counts of offers made, rescinded, and waitlisted
   */
  LotteryRunResult runLottery(Set<Id> lotteryCapacityIds, Date startDate, Date endDate);

  /**
   * Step 1: Assigns randomized sort keys to eligible applications.
   * Commits to database before returning.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @param startDate Optional start date filter for applied date (Application_Submitted_Date__c)
   * @param endDate Optional end date filter for applied date (Application_Submitted_Date__c)
   * @return Count of applications that received sort keys
   */
  Integer randomizeApplications(Set<Id> lotteryCapacityIds, Date startDate, Date endDate);

  /**
   * Step 2: Makes pre-offers to students within capacity.
   * Processes grades lowest-first, priority groups 1→4 within each grade.
   * Commits to database before returning.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @return Result containing count of PRE_OFFER assignments
   */
  AssignPreOffersResult assignPreOffers(Set<Id> lotteryCapacityIds, Date startDate, Date endDate);

  /**
   * Step 3: Optimizes offers by rescinding duplicates (one offer per student).
   * Commits to database before returning.
   *
   * @param runLogId The Lottery_Run_Log__c Id for this lottery run
   * @return Result containing count of rescinded offers
   */
  OptimizeOffersResult optimizeOffers(Id runLogId);

  /**
   * Step 4: Transitions remaining eligible applications to waitlist status
   * and publishes waitlist recalculation events.
   * Commits to database before returning.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records processed
   * @param runLogId The Lottery_Run_Log__c Id for this lottery run
   * @return Result containing waitlist count and event publication status
   */
  FinalizeResult finalizeLottery(Set<Id> lotteryCapacityIds, Id runLogId);

  // ==================== Batched Methods (for large datasets) ====================

  /**
   * Batched version of randomizeApplications using keyset pagination.
   * Processes a batch of records and returns cursor for next batch.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with processedCount, lastRecordId cursor, and hasMore flag
   */
  RandomizeBatchResult randomizeApplicationsBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  );

  /**
   * Batched version of assignPreOffers using keyset pagination.
   * Processes a batch of randomized records and assigns pre-offers.
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records to process
   * @param startDate Optional start date filter
   * @param endDate Optional end date filter
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with preOfferCount, lastRecordId cursor, and hasMore flag
   */
  AssignPreOffersResult assignPreOffersBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  );

  /**
   * Batched version of optimizeOffers using keyset pagination.
   * Processes a batch of pre-offer records for optimization.
   *
   * @param runLogId The Lottery_Run_Log__c Id for this lottery run
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with rescindedCount, lastRecordId cursor, and hasMore flag
   */
  OptimizeOffersResult optimizeOffersBatch(Id runLogId, Id lastRecordId, Integer batchSize);

  /**
   * Batched version of finalizeLottery using keyset pagination.
   * Transitions a batch of remaining eligible to waitlist status.
   * Events are published only on the final batch (when hasMore=false).
   *
   * @param lotteryCapacityIds The IDs of Lottery_Capacity__c records processed
   * @param runLogId The Lottery_Run_Log__c Id for this lottery run
   * @param lastRecordId Cursor from previous batch (null for first batch)
   * @param batchSize Number of records to process per batch
   * @return Result with waitlistCount, lastRecordId cursor, and hasMore flag
   */
  FinalizeResult finalizeLotteryBatch(
    Set<Id> lotteryCapacityIds,
    Id runLogId,
    Id lastRecordId,
    Integer batchSize
  );
}