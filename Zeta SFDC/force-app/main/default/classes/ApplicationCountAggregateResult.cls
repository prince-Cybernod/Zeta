/**
 * Wrapper for AggregateResult from {@link ApplicationCountRollupServiceImpl}.
 * Holds the Account the count is grouped by and the aggregate count.
 *
 * The impl groups by three different lookups, so each query aliases its
 * grouped field to {@code acctId} and one wrapper serves all three.
 */
public with sharing class ApplicationCountAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id accountId;
  public final Decimal count;

  public ApplicationCountAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.accountId = isReturningFakeData ? null : (Id) aggregateResult.get('acctId');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private ApplicationCountAggregateResult(Id accountId, Decimal count) {
    this.accountId = accountId;
    this.count = count;
  }

  public static List<ApplicationCountAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<ApplicationCountAggregateResult> results = new List<ApplicationCountAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new ApplicationCountAggregateResult(aggregateResult));
    }
    return results;
  }
}