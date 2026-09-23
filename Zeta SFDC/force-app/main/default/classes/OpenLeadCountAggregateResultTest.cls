/**
 * Tests for {@link OpenLeadCountAggregateResult}.
 */
@IsTest(IsParallel=true)
private class OpenLeadCountAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    OpenLeadCountAggregateResult.isReturningFakeData = true;
  }

  @IsTest
  private static void constructor_withAggregateResult_assignsFakeValues() {
    Map<String, Object> aggMap = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'AggregateResult' }
    };
    AggregateResult aggregateResult = (AggregateResult) JSON.deserialize(
      JSON.serialize(aggMap),
      AggregateResult.class
    );

    OpenLeadCountAggregateResult result = new OpenLeadCountAggregateResult(aggregateResult);

    Assert.isNotNull(result);
    Assert.isNull(result.ownerId);
    Assert.areEqual(0, result.count);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Decimal count = 3;

    OpenLeadCountAggregateResult result = new OpenLeadCountAggregateResult(ownerId, count);

    Assert.isNotNull(result);
    Assert.areEqual(ownerId, result.ownerId);
    Assert.areEqual(count, result.count);
  }

  @IsTest
  private static void fromAggregateResults_returnsExpectedValues() {
    Map<String, Object> aggMap = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'AggregateResult' }
    };
    AggregateResult aggregateResult = (AggregateResult) JSON.deserialize(
      JSON.serialize(aggMap),
      AggregateResult.class
    );

    List<OpenLeadCountAggregateResult> results = OpenLeadCountAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ aggregateResult }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].ownerId);
    Assert.areEqual(0, results[0].count);
  }
}