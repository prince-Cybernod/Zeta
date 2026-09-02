/**
 * {@link TriggerHandler} that handles {@link AcademicInterest} DML operations.
 */
public with sharing class AcademicInterestTriggerHandler extends NoOpTriggerHandler {
  // Bypass flag to skip all after-trigger side effects during lottery batch operations.
  // Prevents cross-transaction UNABLE_TO_LOCK_ROW from platform events and cascading DML.
  private static Boolean bypassAfterTrigger = false;

  /**
   * Enables bypass mode to skip after-trigger processing.
   * Use during lottery batch operations to prevent row lock contention.
   */
  public static void enableBypass() {
    bypassAfterTrigger = true;
  }

  /**
   * Disables bypass mode to resume normal after-trigger processing.
   */
  public static void disableBypass() {
    bypassAfterTrigger = false;
  }

  @TestVisible
  private static Boolean isBypassEnabled() {
    return bypassAfterTrigger;
  }

  private final LotteryCapacityRollupService rollupService;
  private final CurrentPriorityCalcService priorityGroupService;
  private final DynamicSiblingPriorityService siblingPriorityService;
  private final PreOfferCountRollupService preOfferCountRollupService;
  private final SchoolRankValidationService rankValidationService;
  private final WaitlistHistoryService waitlistHistoryService;
  private final EventBusRepo eventBusRepo;

  public AcademicInterestTriggerHandler() {
    this(
      new LotteryCapacityRollupServiceImpl(),
      new CurrentPriorityCalcServiceImpl(),
      new DynamicSiblingPriorityServiceImpl(),
      new PreOfferCountRollupServiceImpl(),
      new SchoolRankValidationServiceImpl(),
      new WaitlistHistoryServiceImpl(),
      new EventBusRepoImpl()
    );
  }

  @TestVisible
  private AcademicInterestTriggerHandler(
    LotteryCapacityRollupService rollupService,
    CurrentPriorityCalcService priorityGroupService,
    DynamicSiblingPriorityService siblingPriorityService,
    PreOfferCountRollupService preOfferCountRollupService,
    SchoolRankValidationService rankValidationService,
    WaitlistHistoryService waitlistHistoryService,
    EventBusRepo eventBusRepo
  ) {
    this.rollupService = rollupService;
    this.priorityGroupService = priorityGroupService;
    this.siblingPriorityService = siblingPriorityService;
    this.preOfferCountRollupService = preOfferCountRollupService;
    this.rankValidationService = rankValidationService;
    this.waitlistHistoryService = waitlistHistoryService;
    this.eventBusRepo = eventBusRepo;
  }

  public override SObjectType getSObjectType() {
    return Schema.AcademicInterest.SObjectType;
  }

  public override void onBeforeInsert(List<SObject> sobjects) {
    priorityGroupService.calculateForRecords(sobjects);
  }

  public override void onBeforeUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    List<AcademicInterest> recordsNeedingPriorityRecalculation = new List<AcademicInterest>();

    for (AcademicInterest academicInterest : (List<AcademicInterest>) sobjects) {
      SObjectFieldDiffResponse priorityDiff = SObjectFieldDiffer.getFieldDiff(
        academicInterest,
        oldSObjectsByIds.get(academicInterest.Id),
        new List<SObjectField>{
          Schema.AcademicInterest.In_District_Priority__c,
          Schema.AcademicInterest.IndividualApplicationId
        }
      );
      if (priorityDiff.isDifferent()) {
        recordsNeedingPriorityRecalculation.add(academicInterest);
      }
    }

    if (!recordsNeedingPriorityRecalculation.isEmpty()) {
      priorityGroupService.calculateForRecords(recordsNeedingPriorityRecalculation);
    }
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    if (bypassAfterTrigger) {
      return;
    }

    rankValidationService.validateUniqueRanks((List<AcademicInterest>) sobjects);

    Set<Id> capacityIds = collectCapacityIds(sobjects);
    if (!capacityIds.isEmpty()) {
      rollupService.recalculate(capacityIds);
    }

    Set<Id> applicationIds = collectApplicationIdsForPreOfferCount(
      (List<AcademicInterest>) sobjects
    );
    if (!applicationIds.isEmpty()) {
      preOfferCountRollupService.recalculate(applicationIds);
    }
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    if (bypassAfterTrigger) {
      return;
    }

    List<AcademicInterest> newRecords = (List<AcademicInterest>) sobjects;

    // Register records being processed to prevent self-reference in cascade updates
    PreOfferCountRollupServiceImpl.registerProcessingRecords(oldSObjectsByIds.keySet());

    List<AcademicInterest> recordsNeedingRankValidation = collectRecordsNeedingRankValidation(
      newRecords,
      oldSObjectsByIds
    );
    if (!recordsNeedingRankValidation.isEmpty()) {
      rankValidationService.validateUniqueRanks(recordsNeedingRankValidation);
    }

    Set<Id> capacityIds = collectCapacityIdsForRollup(newRecords, oldSObjectsByIds);
    if (!capacityIds.isEmpty()) {
      rollupService.recalculate(capacityIds);
    }

    StatusChangeResult statusChanges = collectStatusChangeResults(newRecords, oldSObjectsByIds);
    if (!statusChanges.upgradeAppIds.isEmpty()) {
      siblingPriorityService.handleUpgrade(statusChanges.upgradeAppIds);
    }
    if (!statusChanges.downgradeAppIds.isEmpty()) {
      siblingPriorityService.handleDowngrade(statusChanges.downgradeAppIds);
    }
    if (!statusChanges.preOfferCountAppIds.isEmpty()) {
      preOfferCountRollupService.recalculate(statusChanges.preOfferCountAppIds);
    }

    List<AcademicInterest> recordsNeedingWaitlistHistory = collectRecordsNeedingWaitlistHistory(
      newRecords,
      oldSObjectsByIds
    );
    if (!recordsNeedingWaitlistHistory.isEmpty()) {
      invokeWaitlistHistoryService(recordsNeedingWaitlistHistory, oldSObjectsByIds);
    }

    Set<Id> capacityIdsNeedingRecalc = collectCapacityIdsNeedingWaitlistRecalc(
      newRecords,
      oldSObjectsByIds
    );
    if (!capacityIdsNeedingRecalc.isEmpty()) {
      publishWaitlistRecalcEvents(capacityIdsNeedingRecalc);
    }
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    if (bypassAfterTrigger) {
      return;
    }

    Set<Id> capacityIds = collectCapacityIds(oldSObjects);
    if (!capacityIds.isEmpty()) {
      rollupService.recalculate(capacityIds);
    }

    Set<Id> applicationIds = collectApplicationIdsForPreOfferCount(
      (List<AcademicInterest>) oldSObjects
    );
    if (!applicationIds.isEmpty()) {
      preOfferCountRollupService.recalculate(applicationIds);
    }
  }

  private static Set<Id> collectCapacityIds(List<AcademicInterest> records) {
    Set<Id> capacityIds = new Set<Id>();
    for (AcademicInterest academicInterest : records) {
      if (String.isNotBlank(academicInterest.Lottery_Capacity__c)) {
        capacityIds.add(academicInterest.Lottery_Capacity__c);
      }
    }
    return capacityIds;
  }

  private static Set<Id> collectApplicationIdsForPreOfferCount(List<AcademicInterest> records) {
    Set<Id> applicationIds = new Set<Id>();
    for (AcademicInterest academicInterest : records) {
      if (
        academicInterest.Status == AcademicInterestConstants.STATUS_PRE_OFFER &&
        String.isNotBlank(academicInterest.IndividualApplicationId)
      ) {
        applicationIds.add(academicInterest.IndividualApplicationId);
      }
    }
    return applicationIds;
  }

  /**
   * Result container for status change analysis in onAfterUpdate.
   */
  private class StatusChangeResult {
    public Set<Id> upgradeAppIds = new Set<Id>();
    public Set<Id> downgradeAppIds = new Set<Id>();
    public Set<Id> preOfferCountAppIds = new Set<Id>();
  }

  private static List<AcademicInterest> collectRecordsNeedingRankValidation(
    List<AcademicInterest> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    List<AcademicInterest> result = new List<AcademicInterest>();
    for (AcademicInterest academicInterest : newRecords) {
      SObjectFieldDiffResponse rankDiff = SObjectFieldDiffer.getFieldDiff(
        academicInterest,
        oldSObjectsByIds.get(academicInterest.Id),
        new List<SObjectField>{
          Schema.AcademicInterest.School_Rank__c,
          Schema.AcademicInterest.IndividualApplicationId
        }
      );
      if (rankDiff.isDifferent()) {
        result.add(academicInterest);
      }
    }
    return result;
  }

  private static Set<Id> collectCapacityIdsForRollup(
    List<AcademicInterest> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Set<Id> capacityIds = new Set<Id>();
    for (AcademicInterest academicInterest : newRecords) {
      AcademicInterest oldAcademicInterest = (AcademicInterest) oldSObjectsByIds.get(
        academicInterest.Id
      );
      SObjectFieldDiffResponse rollupDiff = SObjectFieldDiffer.getFieldDiff(
        academicInterest,
        oldAcademicInterest,
        new List<SObjectField>{
          Schema.AcademicInterest.Status,
          Schema.AcademicInterest.Lottery_Capacity__c
        }
      );
      if (rollupDiff.isDifferent()) {
        if (String.isNotBlank(academicInterest.Lottery_Capacity__c)) {
          capacityIds.add(academicInterest.Lottery_Capacity__c);
        }
        if (oldAcademicInterest.Lottery_Capacity__c != academicInterest.Lottery_Capacity__c) {
          if (String.isNotBlank(oldAcademicInterest.Lottery_Capacity__c)) {
            capacityIds.add(oldAcademicInterest.Lottery_Capacity__c);
          }
        }
      }
    }
    return capacityIds;
  }

  private static StatusChangeResult collectStatusChangeResults(
    List<AcademicInterest> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    StatusChangeResult result = new StatusChangeResult();
    for (AcademicInterest academicInterest : newRecords) {
      AcademicInterest oldAcademicInterest = (AcademicInterest) oldSObjectsByIds.get(
        academicInterest.Id
      );
      SObjectFieldDiffResponse statusDiff = SObjectFieldDiffer.getFieldDiff(
        academicInterest,
        oldAcademicInterest,
        new List<SObjectField>{ Schema.AcademicInterest.Status }
      );
      if (statusDiff.isDifferent()) {
        String newStatus = academicInterest.Status;
        String oldStatus = oldAcademicInterest.Status;
        if (
          newStatus == AcademicInterestConstants.STATUS_PRE_OFFER ||
          newStatus == AcademicInterestConstants.STATUS_SEAT_OFFERED
        ) {
          if (String.isNotBlank(academicInterest.IndividualApplicationId)) {
            result.upgradeAppIds.add(academicInterest.IndividualApplicationId);
          }
        } else if (
          newStatus == AcademicInterestConstants.STATUS_RESCINDED ||
          newStatus == AcademicInterestConstants.STATUS_WITHDRAWN_DECLINED
        ) {
          if (String.isNotBlank(academicInterest.IndividualApplicationId)) {
            result.downgradeAppIds.add(academicInterest.IndividualApplicationId);
          }
        }
        if (
          newStatus == AcademicInterestConstants.STATUS_PRE_OFFER ||
          oldStatus == AcademicInterestConstants.STATUS_PRE_OFFER
        ) {
          if (String.isNotBlank(academicInterest.IndividualApplicationId)) {
            result.preOfferCountAppIds.add(academicInterest.IndividualApplicationId);
          }
        }
      }
    }
    return result;
  }

  private static List<AcademicInterest> collectRecordsNeedingWaitlistHistory(
    List<AcademicInterest> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    List<AcademicInterest> result = new List<AcademicInterest>();
    for (AcademicInterest academicInterest : newRecords) {
      SObjectFieldDiffResponse waitlistDiff = SObjectFieldDiffer.getFieldDiff(
        academicInterest,
        oldSObjectsByIds.get(academicInterest.Id),
        new List<SObjectField>{
          Schema.AcademicInterest.Status,
          Schema.AcademicInterest.Waitlist_Position__c,
          Schema.AcademicInterest.Current_Priority_Group__c
        }
      );
      if (
        waitlistDiff.isDifferent() &&
        academicInterest.Has_Lottery_Run__c == true &&
        academicInterest.Status == WaitlistConstants.STATUS_WAITLISTED &&
        academicInterest.Waitlist_Position__c != null
      ) {
        result.add(academicInterest);
      }
    }
    return result;
  }

  private void invokeWaitlistHistoryService(
    List<AcademicInterest> recordsNeedingHistory,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Map<Id, AcademicInterest> oldAcademicInterestsById = new Map<Id, AcademicInterest>();
    for (Id recordId : oldSObjectsByIds.keySet()) {
      oldAcademicInterestsById.put(recordId, (AcademicInterest) oldSObjectsByIds.get(recordId));
    }
    waitlistHistoryService.createHistoryRecords(oldAcademicInterestsById, recordsNeedingHistory);
  }

  private static Set<Id> collectCapacityIdsNeedingWaitlistRecalc(
    List<AcademicInterest> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Set<Id> capacityIds = new Set<Id>();
    for (AcademicInterest record : newRecords) {
      AcademicInterest oldRecord = (AcademicInterest) oldSObjectsByIds.get(record.Id);
      if (
        (record.Status == WaitlistConstants.STATUS_WAITLISTED ||
        record.Status == LotteryConstants.STATUS_ELIGIBLE) &&
        oldRecord.Status != record.Status &&
        record.Has_Lottery_Run__c == true &&
        String.isNotBlank(record.Lottery_Capacity__c)
      ) {
        capacityIds.add(record.Lottery_Capacity__c);
      }
    }
    return capacityIds;
  }

  private void publishWaitlistRecalcEvents(Set<Id> capacityIds) {
    List<Waitlist_Recalculation_Event__e> events = new List<Waitlist_Recalculation_Event__e>();
    for (Id capacityId : capacityIds) {
      events.add(
        new Waitlist_Recalculation_Event__e(Lottery_Capacity_Id__c = String.valueOf(capacityId))
      );
    }
    if (!events.isEmpty()) {
      eventBusRepo.publish(events);
    }
  }
}