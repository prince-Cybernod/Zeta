/**
 * Wrapper for AggregateResult from {@link OpenLeadCountQueueable}.
 */
public with sharing class OpenLeadCountAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id ownerId;
  public final Decimal count;

  public OpenLeadCountAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.ownerId = isReturningFakeData ? null : (Id) aggregateResult.get('OwnerId');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private OpenLeadCountAggregateResult(Id ownerId, Decimal count) {
    this.ownerId = ownerId;
    this.count = count;
  }

  public static List<OpenLeadCountAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<OpenLeadCountAggregateResult> results = new List<OpenLeadCountAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new OpenLeadCountAggregateResult(aggregateResult));
    }
    return results;
  }
}