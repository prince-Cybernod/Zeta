/**
 * Implementation of {@link LotteryCapacityRollupService}.
 */
public without sharing class LotteryCapacityRollupServiceImpl implements LotteryCapacityRollupService {
  private final DatabaseRepo databaseRepo;

  // Bypass flag to skip rollup during batch operations (prevents UNABLE_TO_LOCK_ROW)
  private static Boolean bypassRollup = false;

  /**
   * Enables bypass mode to skip rollup calculations.
   * Use during batch operations to prevent row lock contention.
   */
  public static void enableBypass() {
    bypassRollup = true;
  }

  /**
   * Disables bypass mode to resume normal rollup calculations.
   */
  public static void disableBypass() {
    bypassRollup = false;
  }

  /**
   * Returns whether bypass mode is currently enabled.
   */
  @TestVisible
  private static Boolean isBypassEnabled() {
    return bypassRollup;
  }

  public LotteryCapacityRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryCapacityRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> lotteryCapacityIds) {
    if (bypassRollup) {
      return;
    }

    if (lotteryCapacityIds == null || lotteryCapacityIds.isEmpty()) {
      return;
    }

    List<AggregateResult> results = databaseRepo.queryWithBinds(
      'SELECT Lottery_Capacity__c, Status, COUNT(Id) cnt ' +
        'FROM AcademicInterest ' +
        'WHERE Lottery_Capacity__c IN :lotteryCapacityIds ' +
        'GROUP BY Lottery_Capacity__c, Status',
      new Map<String, Object>{ 'lotteryCapacityIds' => lotteryCapacityIds }
    );

    List<LotteryCapacityAggregateResult> wrappedResults = LotteryCapacityAggregateResult.fromAggregateResults(
      results
    );
    processAggregateResults(lotteryCapacityIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> lotteryCapacityIds,
    List<LotteryCapacityAggregateResult> wrappedResults
  ) {
    Map<Id, Map<String, Integer>> countsByCapacityAndStatus = new Map<Id, Map<String, Integer>>();
    for (LotteryCapacityAggregateResult result : wrappedResults) {
      if (!countsByCapacityAndStatus.containsKey(result.lotteryCapacityId)) {
        countsByCapacityAndStatus.put(result.lotteryCapacityId, new Map<String, Integer>());
      }
      countsByCapacityAndStatus.get(result.lotteryCapacityId).put(result.status, result.count);
    }

    List<Lottery_Capacity__c> capacitiesToUpdate = new List<Lottery_Capacity__c>();
    for (Id capacityId : lotteryCapacityIds) {
      Map<String, Integer> statusCounts = countsByCapacityAndStatus.get(capacityId);
      if (statusCounts == null) {
        statusCounts = new Map<String, Integer>();
      }

      Integer preOfferCount = statusCounts.get(AcademicInterestConstants.STATUS_PRE_OFFER) != null
        ? statusCounts.get(AcademicInterestConstants.STATUS_PRE_OFFER)
        : 0;
      Integer seatOfferedCount = statusCounts.get(AcademicInterestConstants.STATUS_SEAT_OFFERED) !=
        null
        ? statusCounts.get(AcademicInterestConstants.STATUS_SEAT_OFFERED)
        : 0;
      Integer seatAcceptedCount = statusCounts.get(
          AcademicInterestConstants.STATUS_SEAT_ACCEPTED
        ) != null
        ? statusCounts.get(AcademicInterestConstants.STATUS_SEAT_ACCEPTED)
        : 0;
      Integer submittedCount = statusCounts.get('Submitted') != null
        ? statusCounts.get('Submitted')
        : 0;
      Integer eligibleCount = statusCounts.get('Eligible') != null
        ? statusCounts.get('Eligible')
        : 0;
      Integer waitlistedCount = statusCounts.get('Waitlisted') != null
        ? statusCounts.get('Waitlisted')
        : 0;

      capacitiesToUpdate.add(
        new Lottery_Capacity__c(
          Id = capacityId,
          Seats_Offered__c = preOfferCount + seatOfferedCount,
          Seats_Accepted__c = seatAcceptedCount,
          Count_of_Pre_Offer_School_Applications__c = preOfferCount,
          Total_Applied_Applications__c = submittedCount + eligibleCount + waitlistedCount
        )
      );
    }

    if (!capacitiesToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(capacitiesToUpdate);
    }
  }
}