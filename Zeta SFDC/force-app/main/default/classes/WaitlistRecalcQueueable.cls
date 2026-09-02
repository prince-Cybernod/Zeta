/**
 * Queueable job for async waitlist recalculation and offer-making.
 *
 * Uses FOR UPDATE locking on Lottery_Capacity__c to prevent concurrent
 * recalculations on the same capacity.
 *
 * When available seats exist (via formula or override), promotes top
 * waitlisted students through a two-DML flow to satisfy the
 * Status_Progression_Lottery_Validation rule (Waitlisted -> Pre-Offer -> Seat Offered).
 *
 * Bypasses the AcademicInterest after-trigger during DML to prevent cascading
 * DML and platform event lock contention. Explicitly calls rollup and history
 * services after bypass-protected DML.
 */
public with sharing class WaitlistRecalcQueueable implements Queueable {
  private final Set<Id> capacityIds;
  private final WaitlistRecalcService recalcService;
  private final OfferOptimizerService optimizerService;
  private final DatabaseRepo databaseRepo;
  private final Map<Id, Integer> seatsOverrideByCapacity;
  private final SeatOfferWithdrawalService withdrawalService;
  private final LotteryCapacityRollupService rollupService;
  private final WaitlistHistoryService historyService;

  public WaitlistRecalcQueueable(Set<Id> capacityIds) {
    this(
      capacityIds,
      new WaitlistRecalcServiceImpl(),
      new OfferOptimizerServiceImpl(),
      new SeatOfferWithdrawalServiceImpl(),
      new SystemModeDatabaseRepo(),
      new Map<Id, Integer>(),
      new LotteryCapacityRollupServiceImpl(),
      new WaitlistHistoryServiceImpl()
    );
  }

  public WaitlistRecalcQueueable(Set<Id> capacityIds, Map<Id, Integer> seatsOverride) {
    this(
      capacityIds,
      new WaitlistRecalcServiceImpl(),
      new OfferOptimizerServiceImpl(),
      new SeatOfferWithdrawalServiceImpl(),
      new SystemModeDatabaseRepo(),
      seatsOverride != null ? seatsOverride : new Map<Id, Integer>(),
      new LotteryCapacityRollupServiceImpl(),
      new WaitlistHistoryServiceImpl()
    );
  }

  @TestVisible
  private WaitlistRecalcQueueable(
    Set<Id> capacityIds,
    WaitlistRecalcService recalcService,
    OfferOptimizerService optimizerService,
    SeatOfferWithdrawalService withdrawalService,
    DatabaseRepo databaseRepo,
    Map<Id, Integer> seatsOverride,
    LotteryCapacityRollupService rollupService,
    WaitlistHistoryService historyService
  ) {
    this.capacityIds = capacityIds;
    this.recalcService = recalcService;
    this.optimizerService = optimizerService;
    this.withdrawalService = withdrawalService;
    this.databaseRepo = databaseRepo;
    this.seatsOverrideByCapacity = seatsOverride != null ? seatsOverride : new Map<Id, Integer>();
    this.rollupService = rollupService;
    this.historyService = historyService;
  }

  public void execute(QueueableContext context) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return;
    }

    Savepoint sp = databaseRepo.setSavepoint();
    try {
      executeRecalculation();
    } catch (Exception e) {
      databaseRepo.rollback(sp);
      reportError(e);
    }
  }

  private void executeRecalculation() {
    List<Lottery_Capacity__c> lockedCapacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      'SELECT Id, Remaining_Available_Seats__c FROM Lottery_Capacity__c WHERE Id IN :capacityIds FOR UPDATE',
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );

    if (lockedCapacities.isEmpty()) {
      return;
    }

    // Set status to Processing after lock acquired
    for (Lottery_Capacity__c cap : lockedCapacities) {
      cap.Last_Recalculation_Status__c = 'Processing';
      cap.Last_Recalculation_Date__c = Datetime.now();
      cap.Last_Recalculation_Error__c = null;
    }
    databaseRepo.updateSObjects(lockedCapacities);

    Map<Id, Lottery_Capacity__c> capacitiesById = new Map<Id, Lottery_Capacity__c>(
      lockedCapacities
    );

    List<AcademicInterest> waitlistedRecords = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Lottery_Capacity__c, Status, Current_Priority_Group__c, ' +
        'Date_of_Current_Priority_Change__c, Randomized_Sort_Key__c, Waitlist_Position__c, ' +
        'IndividualApplicationId, School_Rank__c, CreatedDate ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :capacityIds AND Status IN :statuses',
      new Map<String, Object>{
        'capacityIds' => capacityIds,
        'statuses' => new Set<String>{
          WaitlistConstants.STATUS_WAITLISTED,
          LotteryConstants.STATUS_ELIGIBLE
        }
      }
    );

    if (waitlistedRecords.isEmpty()) {
      setCompleted(lockedCapacities);
      return;
    }

    // Capture old positions for WMH diff
    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>();
    for (AcademicInterest record : waitlistedRecords) {
      oldRecordsById.put(
        record.Id,
        new AcademicInterest(
          Id = record.Id,
          Status = record.Status,
          Waitlist_Position__c = record.Waitlist_Position__c,
          Current_Priority_Group__c = record.Current_Priority_Group__c,
          Randomized_Sort_Key__c = record.Randomized_Sort_Key__c
        )
      );
    }

    List<AcademicInterest> changedRecords = recalcService.recalculatePositionsByCapacity(
      waitlistedRecords
    );

    Set<Id> changedRecordIds = new Set<Id>();
    for (AcademicInterest record : changedRecords) {
      changedRecordIds.add(record.Id);
    }

    Map<Id, List<AcademicInterest>> recordsByCapacity = groupByCapacity(waitlistedRecords);
    List<AcademicInterest> allRecordsToUpdate = new List<AcademicInterest>();
    Set<Id> promotedApplicationIds = new Set<Id>();
    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();

    for (Id capacityId : recordsByCapacity.keySet()) {
      List<AcademicInterest> capacityRecords = recordsByCapacity.get(capacityId);
      Integer availableSeats = determineAvailableSeats(capacityId, capacitiesById);

      if (availableSeats > 0) {
        List<AcademicInterest> sorted = new List<AcademicInterest>(capacityRecords);
        sorted.sort(new WaitlistPositionComparator());
        List<AcademicInterest> toPromote = recalcService.getRecordsToPromote(
          sorted,
          availableSeats
        );

        for (AcademicInterest record : toPromote) {
          transitions.add(
            new LotteryStatusChange(
              record.Id,
              record.Status,
              LotteryConstants.STATUS_PRE_OFFER,
              WaitlistConstants.TRANSITION_REASON_WAITLIST_PROMOTION,
              record.Current_Priority_Group__c
            )
          );
          record.Status = LotteryConstants.STATUS_PRE_OFFER;
          record.Waitlist_Position__c = null;
          if (record.IndividualApplicationId != null) {
            promotedApplicationIds.add(record.IndividualApplicationId);
          }
        }

        Integer position = 1;
        for (AcademicInterest record : sorted) {
          if (
            record.Status == WaitlistConstants.STATUS_WAITLISTED ||
            record.Status == LotteryConstants.STATUS_ELIGIBLE
          ) {
            record.Waitlist_Position__c = position;
            position++;
          }
        }

        allRecordsToUpdate.addAll(capacityRecords);
      } else {
        for (AcademicInterest record : capacityRecords) {
          if (changedRecordIds.contains(record.Id)) {
            allRecordsToUpdate.add(record);
          }
        }
      }
    }

    if (!allRecordsToUpdate.isEmpty()) {
      AcademicInterestTriggerHandler.enableBypass();
      try {
        databaseRepo.updateSObjects(allRecordsToUpdate);
      } finally {
        AcademicInterestTriggerHandler.disableBypass();
      }
    }

    if (!promotedApplicationIds.isEmpty()) {
      finalizeOffers(promotedApplicationIds, transitions);
    }

    // Explicitly call side effects skipped by bypass
    rollupService.recalculate(capacityIds);

    List<AcademicInterest> remainingWaitlisted = new List<AcademicInterest>();
    for (AcademicInterest record : allRecordsToUpdate) {
      if (
        (record.Status == WaitlistConstants.STATUS_WAITLISTED ||
        record.Status == LotteryConstants.STATUS_ELIGIBLE) && record.Waitlist_Position__c != null
      ) {
        remainingWaitlisted.add(record);
      }
    }
    if (!remainingWaitlisted.isEmpty()) {
      historyService.createHistoryRecords(oldRecordsById, remainingWaitlisted);
    }

    setCompleted(lockedCapacities);
  }

  private void finalizeOffers(
    Set<Id> promotedApplicationIds,
    List<LotteryStatusChange> transitions
  ) {
    List<AcademicInterest> activeOfferRecords = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Status, IndividualApplicationId, Lottery_Capacity__c, School_Rank__c, ' +
        'Current_Priority_Group__c, Randomized_Sort_Key__c, CreatedDate ' +
        'FROM AcademicInterest ' +
        'WHERE IndividualApplicationId IN :applicationIds AND Status IN :statuses',
      new Map<String, Object>{
        'applicationIds' => promotedApplicationIds,
        'statuses' => new Set<String>{
          LotteryConstants.STATUS_PRE_OFFER,
          LotteryConstants.STATUS_SEAT_OFFERED
        }
      }
    );

    if (activeOfferRecords.isEmpty()) {
      return;
    }

    optimizerService.optimizeOffers(activeOfferRecords, transitions);

    // Withdraw lower-ranked applications for offered students
    List<AcademicInterest> remainingOffers = new List<AcademicInterest>();
    for (AcademicInterest r : activeOfferRecords) {
      if (
        r.Status == LotteryConstants.STATUS_PRE_OFFER ||
        r.Status == LotteryConstants.STATUS_SEAT_OFFERED
      ) {
        remainingOffers.add(r);
      }
    }
    Set<Id> excludeIds = new Map<Id, AcademicInterest>(activeOfferRecords).keySet();
    List<LotteryStatusChange> withdrawTransitions = new List<LotteryStatusChange>();
    List<AcademicInterest> withdrawn = withdrawalService.withdrawLowerRankedApplications(
      remainingOffers,
      excludeIds,
      withdrawTransitions
    );

    List<AcademicInterest> recordsToUpdate = new List<AcademicInterest>();
    for (AcademicInterest record : activeOfferRecords) {
      if (record.Status == LotteryConstants.STATUS_PRE_OFFER) {
        transitions.add(
          new LotteryStatusChange(
            record.Id,
            record.Status,
            LotteryConstants.STATUS_SEAT_OFFERED,
            WaitlistConstants.TRANSITION_REASON_WAITLIST_OFFER_FINALIZED,
            record.Current_Priority_Group__c
          )
        );
        record.Status = LotteryConstants.STATUS_SEAT_OFFERED;
      }
      recordsToUpdate.add(record);
    }
    recordsToUpdate.addAll(withdrawn);

    if (!recordsToUpdate.isEmpty()) {
      ensureRescindReasons(recordsToUpdate);
      AcademicInterestTriggerHandler.enableBypass();
      try {
        databaseRepo.updateSObjects(recordsToUpdate);
      } finally {
        AcademicInterestTriggerHandler.disableBypass();
      }
    }
  }

  /**
   * Safety check: ensures all records being set to a withdrawal status have
   * the correct reason field populated to satisfy the
   * Require_Withdraw_Rescind_Reason validation rule.
   *
   * Withdrawn/Declined requires Declined_Withdrawn_Reason__c.
   * Rescinded requires Rescinded_Reason__c.
   */
  private static void ensureRescindReasons(List<AcademicInterest> records) {
    for (AcademicInterest record : records) {
      if (
        record.Status == LotteryConstants.STATUS_WITHDRAWN_DECLINED &&
        String.isBlank(record.Declined_Withdrawn_Reason__c)
      ) {
        record.Declined_Withdrawn_Reason__c = 'System: Waitlist Recalculation';
      } else if (
        record.Status == LotteryConstants.STATUS_RESCINDED &&
        String.isBlank(record.Rescinded_Reason__c)
      ) {
        record.Rescinded_Reason__c = 'System: Waitlist Recalculation';
      }
    }
  }

  private void setCompleted(List<Lottery_Capacity__c> lockedCapacities) {
    for (Lottery_Capacity__c cap : lockedCapacities) {
      cap.Last_Recalculation_Status__c = 'Completed';
      cap.Last_Recalculation_Date__c = Datetime.now();
    }
    databaseRepo.updateSObjects(lockedCapacities);
  }

  private void reportError(Exception e) {
    String errorMsg = e.getMessage() + '\n' + e.getStackTraceString();
    List<Lottery_Capacity__c> capsToUpdate = new List<Lottery_Capacity__c>();
    for (Id capId : capacityIds) {
      capsToUpdate.add(
        new Lottery_Capacity__c(
          Id = capId,
          Last_Recalculation_Status__c = 'Failed',
          Last_Recalculation_Date__c = Datetime.now(),
          Last_Recalculation_Error__c = errorMsg.left(32768)
        )
      );
    }
    try {
      databaseRepo.updateSObjects(capsToUpdate);
    } catch (Exception reportEx) {
      System.debug(LoggingLevel.ERROR, 'Failed to report recalc error: ' + reportEx.getMessage());
    }
  }

  private Integer determineAvailableSeats(
    Id capacityId,
    Map<Id, Lottery_Capacity__c> capacitiesById
  ) {
    if (seatsOverrideByCapacity.containsKey(capacityId)) {
      Integer overrideVal = seatsOverrideByCapacity.get(capacityId);
      return overrideVal != null && overrideVal > 0 ? overrideVal : 0;
    }
    Lottery_Capacity__c capacity = capacitiesById.get(capacityId);
    if (capacity == null || capacity.Remaining_Available_Seats__c == null) {
      return 0;
    }
    Decimal remaining = capacity.Remaining_Available_Seats__c;
    return remaining > 0 ? remaining.intValue() : 0;
  }

  private static Map<Id, List<AcademicInterest>> groupByCapacity(List<AcademicInterest> records) {
    Map<Id, List<AcademicInterest>> result = new Map<Id, List<AcademicInterest>>();
    for (AcademicInterest record : records) {
      Id capacityId = record.Lottery_Capacity__c;
      if (capacityId == null) {
        continue;
      }
      if (!result.containsKey(capacityId)) {
        result.put(capacityId, new List<AcademicInterest>());
      }
      result.get(capacityId).add(record);
    }
    return result;
  }
}