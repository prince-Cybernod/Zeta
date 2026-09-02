/**
 * Tests for {@link PriorityGroupAggregateResult}.
 */
@IsTest(IsParallel=true)
private class PriorityGroupAggregateResultTest {
  static {
    PriorityGroupAggregateResult.isReturningFakeData = true;
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

    PriorityGroupAggregateResult result = new PriorityGroupAggregateResult(aggregateResult);

    Assert.isNotNull(result);
    Assert.isNull(result.relatedApplicationId);
    Assert.isNull(result.minPriorityGroup);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Decimal minPriorityGroup = 2;

    PriorityGroupAggregateResult result = new PriorityGroupAggregateResult(appId, minPriorityGroup);

    Assert.isNotNull(result);
    Assert.areEqual(appId, result.relatedApplicationId);
    Assert.areEqual(minPriorityGroup, result.minPriorityGroup);
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

    List<PriorityGroupAggregateResult> results = PriorityGroupAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ aggregateResult }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].relatedApplicationId);
    Assert.isNull(results[0].minPriorityGroup);
  }
}