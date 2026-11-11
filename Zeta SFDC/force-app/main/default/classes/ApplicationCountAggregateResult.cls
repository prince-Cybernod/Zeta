/**
 * Wrapper for AggregateResult from {@link ApplicationCountRollupServiceImpl}.
 * Holds the Account the count is grouped by, the aggregate count, and the
 * Status the rows in that count share.
 *
 * The impl groups by three different lookups, so each query aliases its
 * grouped field to {@code acctId} and one wrapper serves all three.
 */
public with sharing class ApplicationCountAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id accountId;
  public final Decimal count;
  public final String status;

  public ApplicationCountAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.accountId = isReturningFakeData ? null : (Id) aggregateResult.get('acctId');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
    // prettier-ignore
    this.status = isReturningFakeData ? null : (String) aggregateResult.get('st');
  }

  @TestVisible
  private ApplicationCountAggregateResult(Id accountId, Decimal count) {
    this(accountId, count, null);
  }

  @TestVisible
  private ApplicationCountAggregateResult(Id accountId, Decimal count, String status) {
    this.accountId = accountId;
    this.count = count;
    this.status = status;
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