/**
 * Wrapper for AggregateResult from {@link EmployeePriorityRollupServiceImpl}.
 */
public with sharing class EmployeePriorityAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id relatedApplicationId;
  public final Decimal count;

  public EmployeePriorityAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.relatedApplicationId = isReturningFakeData ? null : (Id) aggregateResult.get('Related_Application__c');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private EmployeePriorityAggregateResult(Id relatedApplicationId, Decimal count) {
    this.relatedApplicationId = relatedApplicationId;
    this.count = count;
  }

  public static List<EmployeePriorityAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<EmployeePriorityAggregateResult> results = new List<EmployeePriorityAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new EmployeePriorityAggregateResult(aggregateResult));
    }
    return results;
  }
}