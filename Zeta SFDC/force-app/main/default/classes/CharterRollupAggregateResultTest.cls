/**
 * Tests for {@link CharterRollupAggregateResult}.
 */
@IsTest(IsParallel=true)
private class CharterRollupAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    CharterRollupAggregateResult.isReturningFakeData = true;
  }

  private static AggregateResult buildAggregateResult() {
    Map<String, Object> aggMap = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'AggregateResult' }
    };
    return (AggregateResult) JSON.deserialize(JSON.serialize(aggMap), AggregateResult.class);
  }

  @IsTest
  private static void constructor_withAggregateResult_assignsFakeValues() {
    CharterRollupAggregateResult result = new CharterRollupAggregateResult(buildAggregateResult());

    Assert.isNotNull(result);
    Assert.isNull(result.charterId);
    Assert.areEqual(0, result.employeePriorityCount);
    Assert.areEqual(0, result.availableSeats);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    CharterRollupAggregateResult result = new CharterRollupAggregateResult(charterId, 4, 12);

    Assert.isNotNull(result);
    Assert.areEqual(charterId, result.charterId);
    Assert.areEqual(4, result.employeePriorityCount);
    Assert.areEqual(12, result.availableSeats);
  }

  @IsTest
  private static void fromAggregateResults_returnsExpectedValues() {
    List<CharterRollupAggregateResult> results = CharterRollupAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ buildAggregateResult() }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].charterId);
    Assert.areEqual(0, results[0].employeePriorityCount);
    Assert.areEqual(0, results[0].availableSeats);
  }
}