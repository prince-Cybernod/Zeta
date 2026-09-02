/**
 * Wrapper for AggregateResult from {@link LotteryCapacityRollupServiceImpl}.
 */
public with sharing class LotteryCapacityAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id lotteryCapacityId;
  public final String status;
  public final Integer count;

  public LotteryCapacityAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.lotteryCapacityId = isReturningFakeData ? null : (Id) aggregateResult.get('Lottery_Capacity__c');
    // prettier-ignore
    this.status = isReturningFakeData ? null : (String) aggregateResult.get('Status');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Integer) aggregateResult.get('cnt');
  }

  @TestVisible
  private LotteryCapacityAggregateResult(Id lotteryCapacityId, String status, Integer count) {
    this.lotteryCapacityId = lotteryCapacityId;
    this.status = status;
    this.count = count;
  }

  public static List<LotteryCapacityAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<LotteryCapacityAggregateResult> results = new List<LotteryCapacityAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new LotteryCapacityAggregateResult(aggregateResult));
    }
    return results;
  }
}