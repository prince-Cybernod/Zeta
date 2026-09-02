/**
 * Tests for {@link LotteryCapacityAggregateResult}.
 */
@IsTest(IsParallel=true)
private class LotteryCapacityAggregateResultTest {
  static {
    // Setting aggregate result values throws, so we use the fake data flag
    LotteryCapacityAggregateResult.isReturningFakeData = true;
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

    LotteryCapacityAggregateResult result = new LotteryCapacityAggregateResult(aggregateResult);

    Assert.isNotNull(result);
    Assert.isNull(result.lotteryCapacityId);
    Assert.isNull(result.status);
    Assert.areEqual(0, result.count);
  }

  @IsTest
  private static void visibleConstructor_assignsValues() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    String status = 'Pre-Offer';
    Integer count = 5;

    LotteryCapacityAggregateResult result = new LotteryCapacityAggregateResult(
      capacityId,
      status,
      count
    );

    Assert.isNotNull(result);
    Assert.areEqual(capacityId, result.lotteryCapacityId);
    Assert.areEqual(status, result.status);
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

    List<LotteryCapacityAggregateResult> results = LotteryCapacityAggregateResult.fromAggregateResults(
      new List<AggregateResult>{ aggregateResult }
    );

    Assert.areEqual(1, results.size());
    Assert.isNull(results[0].lotteryCapacityId);
    Assert.isNull(results[0].status);
    Assert.areEqual(0, results[0].count);
  }
}