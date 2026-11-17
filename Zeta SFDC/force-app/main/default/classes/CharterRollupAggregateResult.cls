/**
 * Wrapper for AggregateResult from {@link CharterRollupServiceImpl}.
 */
public with sharing class CharterRollupAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id charterId;
  public final Decimal employeePriorityCount;
  public final Decimal availableSeats;

  public CharterRollupAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.charterId = isReturningFakeData ? null : (Id) aggregateResult.get('charterId');
    // prettier-ignore
    this.employeePriorityCount = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('emp');
    // prettier-ignore
    this.availableSeats = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('seats');
  }

  @TestVisible
  private CharterRollupAggregateResult(
    Id charterId,
    Decimal employeePriorityCount,
    Decimal availableSeats
  ) {
    this.charterId = charterId;
    this.employeePriorityCount = employeePriorityCount;
    this.availableSeats = availableSeats;
  }

  public static List<CharterRollupAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<CharterRollupAggregateResult> results = new List<CharterRollupAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new CharterRollupAggregateResult(aggregateResult));
    }
    return results;
  }
}