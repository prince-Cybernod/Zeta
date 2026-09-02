/**
 * Wrapper for AggregateResult from {@link PriorityGroupRollupServiceImpl}.
 */
public with sharing class PriorityGroupAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id relatedApplicationId;
  public final Decimal minPriorityGroup;

  public PriorityGroupAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.relatedApplicationId = isReturningFakeData ? null : (Id) aggregateResult.get('Related_Application__c');
    // prettier-ignore
    this.minPriorityGroup = isReturningFakeData ? null : (Decimal) aggregateResult.get('minGroup');
  }

  @TestVisible
  private PriorityGroupAggregateResult(Id relatedApplicationId, Decimal minPriorityGroup) {
    this.relatedApplicationId = relatedApplicationId;
    this.minPriorityGroup = minPriorityGroup;
  }

  public static List<PriorityGroupAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<PriorityGroupAggregateResult> results = new List<PriorityGroupAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new PriorityGroupAggregateResult(aggregateResult));
    }
    return results;
  }
}