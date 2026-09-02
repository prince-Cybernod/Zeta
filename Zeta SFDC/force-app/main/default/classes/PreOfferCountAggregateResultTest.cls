/**
 * Tests for {@link PreOfferCountAggregateResult}.
 */
@IsTest(IsParallel=true)
private class PreOfferCountAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    PreOfferCountAggregateResult.isReturningFakeData = true;
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

    PreOfferCountAggregateResult result = new PreOfferCountAggregateResult(aggregateResult);

    Assert.isNotNull(result);
    Assert.isNull(result.individualApplicationId);
    Assert.areEqual(0, result.count);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Decimal count = 5;

    PreOfferCountAggregateResult result = new PreOfferCountAggregateResult(appId, count);

    Assert.isNotNull(result);
    Assert.areEqual(appId, result.individualApplicationId);
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

    List<PreOfferCountAggregateResult> results = PreOfferCountAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ aggregateResult }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].individualApplicationId);
    Assert.areEqual(0, results[0].count);
  }
}