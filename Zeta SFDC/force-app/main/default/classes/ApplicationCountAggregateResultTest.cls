/**
 * Tests for {@link ApplicationCountAggregateResult}.
 */
@IsTest(IsParallel=true)
private class ApplicationCountAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    ApplicationCountAggregateResult.isReturningFakeData = true;
  }

  private static AggregateResult buildAggregateResult() {
    Map<String, Object> aggMap = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'AggregateResult' }
    };
    return (AggregateResult) JSON.deserialize(JSON.serialize(aggMap), AggregateResult.class);
  }

  @IsTest
  private static void constructor_withAggregateResult_assignsFakeValues() {
    ApplicationCountAggregateResult result = new ApplicationCountAggregateResult(
      buildAggregateResult()
    );

    Assert.isNotNull(result);
    Assert.isNull(result.accountId);
    Assert.areEqual(0, result.count);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Decimal count = 3;

    ApplicationCountAggregateResult result = new ApplicationCountAggregateResult(accountId, count);

    Assert.isNotNull(result);
    Assert.areEqual(accountId, result.accountId);
    Assert.areEqual(count, result.count);
  }

  @IsTest
  private static void fromAggregateResults_returnsExpectedValues() {
    List<ApplicationCountAggregateResult> results = ApplicationCountAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ buildAggregateResult() }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].accountId);
    Assert.areEqual(0, results[0].count);
  }
}