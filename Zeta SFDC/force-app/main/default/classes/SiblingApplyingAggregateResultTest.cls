/**
 * Tests for {@link SiblingApplyingAggregateResult}.
 */
@IsTest(IsParallel=true)
private class SiblingApplyingAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    SiblingApplyingAggregateResult.isReturningFakeData = true;
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

    SiblingApplyingAggregateResult result = new SiblingApplyingAggregateResult(aggregateResult);

    Assert.isNotNull(result);
    Assert.isNull(result.applicationId);
    Assert.areEqual(0, result.count);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Decimal count = 3;

    SiblingApplyingAggregateResult result = new SiblingApplyingAggregateResult(appId, count);

    Assert.isNotNull(result);
    Assert.areEqual(appId, result.applicationId);
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

    List<SiblingApplyingAggregateResult> results = SiblingApplyingAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ aggregateResult }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].applicationId);
    Assert.areEqual(0, results[0].count);
  }
}