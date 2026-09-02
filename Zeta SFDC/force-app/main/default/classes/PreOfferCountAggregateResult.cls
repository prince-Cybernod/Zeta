/**
 * Wrapper for AggregateResult from {@link PreOfferCountRollupServiceImpl}.
 */
public with sharing class PreOfferCountAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id individualApplicationId;
  public final Decimal count;

  public PreOfferCountAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.individualApplicationId = isReturningFakeData ? null : (Id) aggregateResult.get('IndividualApplicationId');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private PreOfferCountAggregateResult(Id individualApplicationId, Decimal count) {
    this.individualApplicationId = individualApplicationId;
    this.count = count;
  }

  public static List<PreOfferCountAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<PreOfferCountAggregateResult> results = new List<PreOfferCountAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new PreOfferCountAggregateResult(aggregateResult));
    }
    return results;
  }
}