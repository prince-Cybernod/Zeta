/**
 * Wrapper for AggregateResult from {@link SiblingApplyingRollupServiceImpl}.
 * Holds the application the count is grouped by (the applicant's
 * Related_Application__c) and the aggregate count.
 */
public with sharing class SiblingApplyingAggregateResult {
  @TestVisible
  private static Boolean isReturningFakeData = false;

  public final Id applicationId;
  public final Decimal count;

  public SiblingApplyingAggregateResult(AggregateResult aggregateResult) {
    // prettier-ignore
    this.applicationId = isReturningFakeData ? null : (Id) aggregateResult.get('Related_Application__c');
    // prettier-ignore
    this.count = isReturningFakeData ? 0 : (Decimal) aggregateResult.get('cnt');
  }

  @TestVisible
  private SiblingApplyingAggregateResult(Id applicationId, Decimal count) {
    this.applicationId = applicationId;
    this.count = count;
  }

  public static List<SiblingApplyingAggregateResult> fromAggregateResults(
    List<AggregateResult> aggregateResults
  ) {
    List<SiblingApplyingAggregateResult> results = new List<SiblingApplyingAggregateResult>();
    for (AggregateResult aggregateResult : aggregateResults) {
      results.add(new SiblingApplyingAggregateResult(aggregateResult));
    }
    return results;
  }
}