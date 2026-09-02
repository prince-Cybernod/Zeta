/**
 * Implementation of {@link LotteryOrchestrationService}.
 *
 * Security model: Uses `with sharing` for row-level access control with
 * `SystemModeDatabaseRepo` for field-level writes. This is intentional because
 * lottery execution is admin-only and requires updating standard objects
 * (AcademicInterest) that may have restrictive FLS for regular users.
 *
 * Orchestrates the lottery execution by:
 * 1. Querying eligible AcademicInterest records for the given capacities
 * 2. Assigning randomized sort keys
 * 3. Sorting by priority group and lottery number
 * 4. Assigning Pre-Offer status to students within capacity
 * 5. Optimizing offers (one per student)
 * 6. Transitioning remaining eligible to Waitlisted
 * 7. Publishing waitlist recalculation events
 */
public with sharing class LotteryOrchestrationServiceImpl implements LotteryOrchestrationService {
  private final LotterySortService sortService;
  private final OfferOptimizerService optimizerService;
  private final SeatOfferWithdrawalService withdrawalService;
  private final DatabaseRepo databaseRepo;
  private final EventBusRepo eventBusRepo;

  private static final String STATUS_ELIGIBLE = LotteryConstants.STATUS_ELIGIBLE;
  private static final String STATUS_PRE_OFFER = LotteryConstants.STATUS_PRE_OFFER;
  private static final String STATUS_WAITLISTED = LotteryConstants.STATUS_WAITLISTED;
  private static final String STATUS_WITHDRAWN_DECLINED = LotteryConstants.STATUS_WITHDRAWN_DECLINED;

  public LotteryOrchestrationServiceImpl() {
    this(
      new LotterySortServiceImpl(),
      new OfferOptimizerServiceImpl(),
      new SeatOfferWithdrawalServiceImpl(),
      new SystemModeDatabaseRepo(),
      new EventBusRepoImpl()
    );
  }

  @TestVisible
  private LotteryOrchestrationServiceImpl(
    LotterySortService sortService,
    OfferOptimizerService optimizerService,
    SeatOfferWithdrawalService withdrawalService,
    DatabaseRepo databaseRepo,
    EventBusRepo eventBusRepo
  ) {
    this.sortService = sortService;
    this.optimizerService = optimizerService;
    this.withdrawalService = withdrawalService;
    this.databaseRepo = databaseRepo;
    this.eventBusRepo = eventBusRepo;
  }

  public LotteryRunResult runLottery(Set<Id> lotteryCapacityIds) {
    return runLottery(lotteryCapacityIds, null, null);
  }

  public LotteryRunResult runLottery(Set<Id> lotteryCapacityIds, Date startDate, Date endDate) {
    LotteryRunResult result = new LotteryRunResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
      Map<Id, Lottery_Capacity__c> capacitiesById = queryCapacities(lotteryCapacityIds);
      List<AcademicInterest> eligibleRecords = queryEligibleRecords(
        lotteryCapacityIds,
        startDate,
        endDate
      );

      result.totalEligible = eligibleRecords.size();

      if (eligibleRecords.isEmpty()) {
        result.capacitiesProcessed = new List<Id>(lotteryCapacityIds);
        return result;
      }

      // Stamp original priority group before any processing for waitlist fairness tracking
      for (AcademicInterest ai : eligibleRecords) {
        ai.Original_Priority_Group__c = ai.Current_Priority_Group__c;
      }

      sortService.assignRandomizedSortKeys(eligibleRecords);

      Map<Id, List<AcademicInterest>> recordsByCapacity = groupByCapacity(eligibleRecords);
      List<AcademicInterest> recordsToUpdate = new List<AcademicInterest>();

      for (Id capacityId : recordsByCapacity.keySet()) {
        Lottery_Capacity__c capacity = capacitiesById.get(capacityId);
        if (capacity == null) {
          continue;
        }

        List<AcademicInterest> capacityRecords = recordsByCapacity.get(capacityId);
        Integer availableSeats = getAvailableSeats(capacity);

        List<AcademicInterest> sortedRecords = sortService.sortByLotteryOrder(capacityRecords);
        Integer offersAssigned = assignPreOffers(sortedRecords, availableSeats, transitions);
        result.preOffersAssigned += offersAssigned;

        recordsToUpdate.addAll(sortedRecords);
        result.capacitiesProcessed.add(capacityId);
      }

      List<AcademicInterest> rescindedRecords = optimizerService.optimizeOffers(
        recordsToUpdate,
        transitions
      );
      result.offersRescinded = rescindedRecords.size();

      // Withdraw lower-ranked in-memory applications
      Integer withdrawnCount = withdrawLowerRankedFromList(recordsToUpdate, transitions);
      // Withdraw cross-capacity applications
      Set<Id> inMemoryIds = new Map<Id, AcademicInterest>(recordsToUpdate).keySet();
      List<AcademicInterest> preOfferRecords = filterByStatus(recordsToUpdate, STATUS_PRE_OFFER);
      List<AcademicInterest> crossCapacityWithdrawn = withdrawalService.withdrawLowerRankedApplications(
        preOfferRecords,
        inMemoryIds,
        transitions
      );
      recordsToUpdate.addAll(crossCapacityWithdrawn);
      result.withdrawnCount = withdrawnCount + crossCapacityWithdrawn.size();

      Integer waitlistedCount = assignWaitlistStatus(recordsToUpdate, transitions);
      result.waitlisted = waitlistedCount;

      result.transitions = transitions;
      databaseRepo.updateSObjects(recordsToUpdate);
      publishWaitlistEvents(lotteryCapacityIds);
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  private Map<Id, Lottery_Capacity__c> queryCapacities(Set<Id> capacityIds) {
    String query =
      'SELECT Id, Grade__c, Total_Available_Seats__c, Remaining_Available_Seats__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds ' +
      'ORDER BY Grade__c ASC';
    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );
    return new Map<Id, Lottery_Capacity__c>(capacities);
  }

  private List<AcademicInterest> queryEligibleRecords(
    Set<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    String query =
      'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
      'Current_Priority_Group__c, Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, CreatedDate ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds AND Status = :status';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'status' => STATUS_ELIGIBLE
    };

    if (startDate != null) {
      query += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      query += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds);
  }

  private static Map<Id, List<AcademicInterest>> groupByCapacity(List<AcademicInterest> records) {
    Map<Id, List<AcademicInterest>> result = new Map<Id, List<AcademicInterest>>();
    for (AcademicInterest record : records) {
      Id capacityId = record.Lottery_Capacity__c;
      if (!result.containsKey(capacityId)) {
        result.put(capacityId, new List<AcademicInterest>());
      }
      result.get(capacityId).add(record);
    }
    return result;
  }

  private static Integer getAvailableSeats(Lottery_Capacity__c capacity) {
    Decimal remaining = capacity.Remaining_Available_Seats__c;
    if (remaining == null || remaining < 0) {
      return 0;
    }
    return remaining.intValue();
  }

  private static Integer assignPreOffers(
    List<AcademicInterest> sortedRecords,
    Integer availableSeats,
    List<LotteryStatusChange> transitions
  ) {
    Integer offersAssigned = 0;
    for (Integer i = 0; i < sortedRecords.size() && offersAssigned < availableSeats; i++) {
      AcademicInterest record = sortedRecords[i];
      if (record.Status == STATUS_ELIGIBLE) {
        transitions.add(
          new LotteryStatusChange(
            record.Id,
            record.Status,
            STATUS_PRE_OFFER,
            LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER,
            record.Current_Priority_Group__c
          )
        );
        record.Status = STATUS_PRE_OFFER;
        offersAssigned++;
      }
    }
    return offersAssigned;
  }

  private static Integer assignWaitlistStatus(
    List<AcademicInterest> records,
    List<LotteryStatusChange> transitions
  ) {
    Integer waitlistedCount = 0;
    for (AcademicInterest record : records) {
      if (record.Status == STATUS_ELIGIBLE) {
        transitions.add(
          new LotteryStatusChange(
            record.Id,
            record.Status,
            STATUS_WAITLISTED,
            LotteryConstants.TRANSITION_REASON_NO_SEATS,
            record.Current_Priority_Group__c
          )
        );
        record.Status = STATUS_WAITLISTED;
        waitlistedCount++;
      }
    }
    return waitlistedCount;
  }

  private void publishWaitlistEvents(Set<Id> capacityIds) {
    List<Waitlist_Recalculation_Event__e> events = new List<Waitlist_Recalculation_Event__e>();
    for (Id capacityId : capacityIds) {
      events.add(
        new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = String.valueOf(capacityId))
      );
    }
    if (!events.isEmpty()) {
      this.eventBusRepo.publish(events);
    }
  }

  public Integer randomizeApplications(Set<Id> lotteryCapacityIds, Date startDate, Date endDate) {
    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return 0;
    }

    List<AcademicInterest> eligibleRecords = queryEligibleRecords(
      lotteryCapacityIds,
      startDate,
      endDate
    );

    if (eligibleRecords.isEmpty()) {
      return 0;
    }

    // Stamp original priority group before any processing
    for (AcademicInterest ai : eligibleRecords) {
      ai.Original_Priority_Group__c = ai.Current_Priority_Group__c;
    }

    sortService.assignRandomizedSortKeys(eligibleRecords);
    databaseRepo.updateSObjects(eligibleRecords);

    return eligibleRecords.size();
  }

  public AssignPreOffersResult assignPreOffers(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate
  ) {
    AssignPreOffersResult result = new AssignPreOffersResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      Map<Id, Lottery_Capacity__c> capacitiesById = queryCapacities(lotteryCapacityIds);
      List<AcademicInterest> eligibleRecords = queryEligibleRecords(
        lotteryCapacityIds,
        startDate,
        endDate
      );

      if (eligibleRecords.isEmpty()) {
        return result;
      }

      Map<Id, List<AcademicInterest>> recordsByCapacity = groupByCapacity(eligibleRecords);
      List<AcademicInterest> recordsToUpdate = new List<AcademicInterest>();
      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

      for (Id capacityId : recordsByCapacity.keySet()) {
        Lottery_Capacity__c capacity = capacitiesById.get(capacityId);
        if (capacity == null) {
          continue;
        }

        List<AcademicInterest> capacityRecords = recordsByCapacity.get(capacityId);
        Integer availableSeats = getAvailableSeats(capacity);

        List<AcademicInterest> sortedRecords = sortService.sortByLotteryOrder(capacityRecords);
        Integer offersAssigned = assignPreOffers(sortedRecords, availableSeats, transitions);
        result.preOfferCount += offersAssigned;

        recordsToUpdate.addAll(sortedRecords);
      }

      databaseRepo.updateSObjects(recordsToUpdate);
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  public OptimizeOffersResult optimizeOffers(Id runLogId) {
    OptimizeOffersResult result = new OptimizeOffersResult();

    if (runLogId == null) {
      return result;
    }

    try {
      String capacityQuery = 'SELECT Id FROM Lottery_Capacity__c WHERE Lottery_Run_Log__c = :runLogId';
      List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
        capacityQuery,
        new Map<String, Object>{ 'runLogId' => runLogId }
      );

      if (capacities.isEmpty()) {
        return result;
      }

      Set<Id> capacityIds = new Map<Id, Lottery_Capacity__c>(capacities).keySet();
      String query =
        'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
        'Current_Priority_Group__c, Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, CreatedDate ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capacityIds AND Status = :status';

      List<AcademicInterest> preOfferRecords = (List<AcademicInterest>) databaseRepo.queryWithBinds(
        query,
        new Map<String, Object>{ 'capacityIds' => capacityIds, 'status' => STATUS_PRE_OFFER }
      );

      if (preOfferRecords.isEmpty()) {
        return result;
      }

      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
      List<AcademicInterest> rescindedRecords = optimizerService.optimizeOffers(
        preOfferRecords,
        transitions
      );
      result.rescindedCount = rescindedRecords.size();

      // Withdraw lower-ranked applications for remaining offered students
      List<AcademicInterest> remainingOffers = filterByStatus(preOfferRecords, STATUS_PRE_OFFER);
      Set<Id> excludeIds = new Map<Id, AcademicInterest>(preOfferRecords).keySet();
      List<AcademicInterest> withdrawn = withdrawalService.withdrawLowerRankedApplications(
        remainingOffers,
        excludeIds,
        transitions
      );
      result.withdrawnCount = withdrawn.size();
      List<AcademicInterest> allToUpdate = new List<AcademicInterest>(preOfferRecords);
      allToUpdate.addAll(withdrawn);
      databaseRepo.updateSObjects(allToUpdate);
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  public FinalizeResult finalizeLottery(Set<Id> lotteryCapacityIds, Id runLogId) {
    FinalizeResult result = new FinalizeResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      List<AcademicInterest> eligibleRecords = queryEligibleRecords(lotteryCapacityIds, null, null);

      if (!eligibleRecords.isEmpty()) {
        List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
        result.waitlistCount = assignWaitlistStatus(eligibleRecords, transitions);
        databaseRepo.updateSObjects(eligibleRecords);
      }

      publishWaitlistEvents(lotteryCapacityIds);
      result.eventsPublished = lotteryCapacityIds.size();
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  // ==================== Batched Methods (for large datasets) ====================

  public RandomizeBatchResult randomizeApplicationsBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    RandomizeBatchResult result = new RandomizeBatchResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      List<AcademicInterest> records = queryEligibleRecordsBatch(
        lotteryCapacityIds,
        startDate,
        endDate,
        lastRecordId,
        batchSize
      );

      if (records.isEmpty()) {
        result.hasMore = false;
        return result;
      }

      // Stamp original priority group before any processing
      for (AcademicInterest ai : records) {
        ai.Original_Priority_Group__c = ai.Current_Priority_Group__c;
      }

      sortService.assignRandomizedSortKeys(records);
      databaseRepo.updateSObjects(records);

      result.processedCount = records.size();
      result.lastRecordId = records[records.size() - 1].Id;
      result.hasMore = records.size() == batchSize;
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  public AssignPreOffersResult assignPreOffersBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    AssignPreOffersResult result = new AssignPreOffersResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      Map<Id, Lottery_Capacity__c> capacitiesById = queryCapacities(lotteryCapacityIds);

      // Query randomized records (those with sort keys) in batch
      List<AcademicInterest> records = queryRandomizedRecordsBatch(
        lotteryCapacityIds,
        startDate,
        endDate,
        lastRecordId,
        batchSize
      );

      if (records.isEmpty()) {
        result.hasMore = false;
        return result;
      }

      Map<Id, List<AcademicInterest>> recordsByCapacity = groupByCapacity(records);
      List<AcademicInterest> recordsToUpdate = new List<AcademicInterest>();
      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

      for (Id capacityId : recordsByCapacity.keySet()) {
        Lottery_Capacity__c capacity = capacitiesById.get(capacityId);
        if (capacity == null) {
          continue;
        }

        List<AcademicInterest> capacityRecords = recordsByCapacity.get(capacityId);
        Integer availableSeats = getAvailableSeats(capacity);

        List<AcademicInterest> sortedRecords = sortService.sortByLotteryOrder(capacityRecords);
        Integer offersAssigned = assignPreOffers(sortedRecords, availableSeats, transitions);
        result.preOfferCount += offersAssigned;

        recordsToUpdate.addAll(sortedRecords);
      }

      AcademicInterestTriggerHandler.enableBypass();
      try {
        databaseRepo.updateSObjects(recordsToUpdate);
      } finally {
        AcademicInterestTriggerHandler.disableBypass();
      }

      result.lastRecordId = records[records.size() - 1].Id;
      result.hasMore = records.size() == batchSize;
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  public OptimizeOffersResult optimizeOffersBatch(Id runLogId, Id lastRecordId, Integer batchSize) {
    OptimizeOffersResult result = new OptimizeOffersResult();

    if (runLogId == null) {
      return result;
    }

    try {
      String capacityQuery = 'SELECT Id FROM Lottery_Capacity__c WHERE Lottery_Run_Log__c = :runLogId';
      List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
        capacityQuery,
        new Map<String, Object>{ 'runLogId' => runLogId }
      );

      if (capacities.isEmpty()) {
        return result;
      }

      Set<Id> capacityIds = new Map<Id, Lottery_Capacity__c>(capacities).keySet();

      // Query PRE_OFFER records in batch with keyset pagination
      List<AcademicInterest> preOfferRecords = queryPreOfferRecordsBatch(
        capacityIds,
        lastRecordId,
        batchSize
      );

      if (preOfferRecords.isEmpty()) {
        result.hasMore = false;
        return result;
      }

      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
      List<AcademicInterest> rescindedRecords = optimizerService.optimizeOffers(
        preOfferRecords,
        transitions
      );
      result.rescindedCount = rescindedRecords.size();

      // Withdraw lower-ranked applications for remaining offered students
      List<AcademicInterest> remainingOffers = filterByStatus(preOfferRecords, STATUS_PRE_OFFER);
      Set<Id> excludeIds = new Map<Id, AcademicInterest>(preOfferRecords).keySet();
      List<AcademicInterest> withdrawn = withdrawalService.withdrawLowerRankedApplications(
        remainingOffers,
        excludeIds,
        transitions
      );
      result.withdrawnCount = withdrawn.size();
      List<AcademicInterest> allToUpdate = new List<AcademicInterest>(preOfferRecords);
      allToUpdate.addAll(withdrawn);

      AcademicInterestTriggerHandler.enableBypass();
      try {
        databaseRepo.updateSObjects(allToUpdate);
      } finally {
        AcademicInterestTriggerHandler.disableBypass();
      }

      result.lastRecordId = preOfferRecords[preOfferRecords.size() - 1].Id;
      result.hasMore = preOfferRecords.size() == batchSize;
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  public FinalizeResult finalizeLotteryBatch(
    Set<Id> lotteryCapacityIds,
    Id runLogId,
    Id lastRecordId,
    Integer batchSize
  ) {
    FinalizeResult result = new FinalizeResult();

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return result;
    }

    try {
      List<AcademicInterest> eligibleRecords = queryEligibleRecordsBatch(
        lotteryCapacityIds,
        null, // no date filter for finalize
        null,
        lastRecordId,
        batchSize
      );

      if (eligibleRecords.isEmpty()) {
        // No more records - perform final rollup and publish events
        LotteryCapacityRollupServiceImpl rollupService = new LotteryCapacityRollupServiceImpl();
        rollupService.recalculate(lotteryCapacityIds);
        publishWaitlistEvents(lotteryCapacityIds);
        result.eventsPublished = lotteryCapacityIds.size();
        result.hasMore = false;
        return result;
      }

      List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
      result.waitlistCount = assignWaitlistStatus(eligibleRecords, transitions);

      // Bypass trigger to prevent cross-transaction UNABLE_TO_LOCK_ROW from
      // platform events and cascading DML during batch operations.
      // Rollups and waitlist events are handled explicitly on the last batch.
      AcademicInterestTriggerHandler.enableBypass();
      try {
        databaseRepo.updateSObjects(eligibleRecords);
      } finally {
        AcademicInterestTriggerHandler.disableBypass();
      }

      result.lastRecordId = eligibleRecords[eligibleRecords.size() - 1].Id;
      result.hasMore = eligibleRecords.size() == batchSize;

      // Only perform rollup and publish events when there are no more records
      if (!result.hasMore) {
        LotteryCapacityRollupServiceImpl rollupService = new LotteryCapacityRollupServiceImpl();
        rollupService.recalculate(lotteryCapacityIds);
        publishWaitlistEvents(lotteryCapacityIds);
        result.eventsPublished = lotteryCapacityIds.size();
      }
    } catch (Exception e) {
      result.isSuccess = false;
      result.errorMessage = e.getMessage() + '\n' + e.getStackTraceString();
    }

    return result;
  }

  // ==================== Batch Query Helpers ====================

  private List<AcademicInterest> queryEligibleRecordsBatch(
    Set<Id> capacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    String query =
      'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
      'Current_Priority_Group__c, Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, CreatedDate ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds AND Status = :status';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'status' => STATUS_ELIGIBLE
    };

    if (lastRecordId != null) {
      query += ' AND Id > :lastRecordId';
      binds.put('lastRecordId', lastRecordId);
    }

    if (startDate != null) {
      query += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      query += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    query += ' ORDER BY Id ASC LIMIT :batchSize';
    binds.put('batchSize', batchSize);

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds);
  }

  private List<AcademicInterest> queryRandomizedRecordsBatch(
    Set<Id> capacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    // Query eligible records that have been randomized (have sort key)
    String query =
      'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
      'Current_Priority_Group__c, Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, CreatedDate ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds AND Status = :status ' +
      'AND Randomized_Sort_Key__c != null';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'status' => STATUS_ELIGIBLE
    };

    if (lastRecordId != null) {
      query += ' AND Id > :lastRecordId';
      binds.put('lastRecordId', lastRecordId);
    }

    if (startDate != null) {
      query += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      query += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    query += ' ORDER BY Id ASC LIMIT :batchSize';
    binds.put('batchSize', batchSize);

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds);
  }

  private List<AcademicInterest> queryPreOfferRecordsBatch(
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  ) {
    String query =
      'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
      'Current_Priority_Group__c, Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, CreatedDate ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds AND Status = :status';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'status' => STATUS_PRE_OFFER
    };

    if (lastRecordId != null) {
      query += ' AND Id > :lastRecordId';
      binds.put('lastRecordId', lastRecordId);
    }

    query += ' ORDER BY Id ASC LIMIT :batchSize';
    binds.put('batchSize', batchSize);

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds);
  }

  private static Integer withdrawLowerRankedFromList(
    List<AcademicInterest> records,
    List<LotteryStatusChange> transitions
  ) {
    Map<Id, Decimal> bestRankByApp = new Map<Id, Decimal>();
    for (AcademicInterest record : records) {
      if (record.IndividualApplicationId == null || record.Status != STATUS_PRE_OFFER) {
        continue;
      }
      Decimal currentBest = bestRankByApp.get(record.IndividualApplicationId);
      if (
        record.School_Rank__c != null &&
        (currentBest == null ||
        record.School_Rank__c < currentBest)
      ) {
        bestRankByApp.put(record.IndividualApplicationId, record.School_Rank__c);
      }
    }

    Integer withdrawnCount = 0;
    for (AcademicInterest record : records) {
      if (record.IndividualApplicationId == null || record.Status != STATUS_ELIGIBLE) {
        continue;
      }
      Decimal bestRank = bestRankByApp.get(record.IndividualApplicationId);
      if (bestRank != null && (record.School_Rank__c == null || record.School_Rank__c > bestRank)) {
        transitions.add(
          new LotteryStatusChange(
            record.Id,
            record.Status,
            STATUS_WITHDRAWN_DECLINED,
            LotteryConstants.TRANSITION_REASON_SEAT_OFFER_WITHDRAWAL,
            record.Current_Priority_Group__c
          )
        );
        record.Status = STATUS_WITHDRAWN_DECLINED;
        record.Rescinded_Reason__c = LotteryConstants.WITHDRAWN_REASON_SEAT_OFFER;
        withdrawnCount++;
      }
    }
    return withdrawnCount;
  }

  private static List<AcademicInterest> filterByStatus(
    List<AcademicInterest> records,
    String status
  ) {
    List<AcademicInterest> filtered = new List<AcademicInterest>();
    for (AcademicInterest record : records) {
      if (record.Status == status) {
        filtered.add(record);
      }
    }
    return filtered;
  }
}