/**
 * Wrapper for AggregateResult from {@link ActiveEnrollmentsRollupServiceImpl}.
 * Holds the Account the count is grouped by and the aggregate count.
 *
 * The impl groups by three different paths to an Account, so each query
 * aliases its grouped field to {@code acctId} and one wrapper serves all three.
 */
public with sharing class ActiveEnrollmentsAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id accountId;
  public final Decimal count;

  public ActiveEnrollmentsAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.accountId = isReturningFakeData ? null : (Id) aggregateResult.get('acctId');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private ActiveEnrollmentsAggregateResult(Id accountId, Decimal count) {
    this.accountId = accountId;
    this.count = count;
  }

  public static List<ActiveEnrollmentsAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<ActiveEnrollmentsAggregateResult> results = new List<ActiveEnrollmentsAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new ActiveEnrollmentsAggregateResult(aggregateResult));
    }
    return results;
  }
}