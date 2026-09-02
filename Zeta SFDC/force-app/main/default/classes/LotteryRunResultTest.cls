@IsTest(IsParallel=true)
private class LotteryRunResultTest {
  @IsTest
  private static void constructor_initializesDefaults() {
    LotteryRunResult result = new LotteryRunResult();

    Assert.areEqual(0, result.totalEligible, 'totalEligible should default to 0');
    Assert.areEqual(0, result.preOffersAssigned, 'preOffersAssigned should default to 0');
    Assert.areEqual(0, result.offersRescinded, 'offersRescinded should default to 0');
    Assert.areEqual(0, result.waitlisted, 'waitlisted should default to 0');
    Assert.isNotNull(result.capacitiesProcessed, 'capacitiesProcessed should not be null');
    Assert.areEqual(0, result.capacitiesProcessed.size(), 'capacitiesProcessed should be empty');
    Assert.isTrue(result.isSuccess, 'isSuccess should default to true');
    Assert.isNull(result.errorMessage, 'errorMessage should default to null');
    Assert.areEqual(0, result.withdrawnCount, 'withdrawnCount should default to 0');
  }

  @IsTest
  private static void properties_canBeSetAndRead() {
    LotteryRunResult result = new LotteryRunResult();
    Id fakeCapacityId = SObjectIds.generateFakeId(Lottery_Capacity__c.SObjectType);

    result.totalEligible = 100;
    result.preOffersAssigned = 50;
    result.offersRescinded = 5;
    result.waitlisted = 45;
    result.withdrawnCount = 10;
    result.capacitiesProcessed.add(fakeCapacityId);
    result.isSuccess = false;
    result.errorMessage = 'Test error';

    Assert.areEqual(100, result.totalEligible, 'totalEligible should be settable');
    Assert.areEqual(50, result.preOffersAssigned, 'preOffersAssigned should be settable');
    Assert.areEqual(5, result.offersRescinded, 'offersRescinded should be settable');
    Assert.areEqual(45, result.waitlisted, 'waitlisted should be settable');
    Assert.areEqual(10, result.withdrawnCount, 'withdrawnCount should be settable');
    Assert.areEqual(
      1,
      result.capacitiesProcessed.size(),
      'capacitiesProcessed should contain one item'
    );
    Assert.areEqual(
      fakeCapacityId,
      result.capacitiesProcessed[0],
      'capacitiesProcessed should contain the added ID'
    );
    Assert.isFalse(result.isSuccess, 'isSuccess should be settable');
    Assert.areEqual('Test error', result.errorMessage, 'errorMessage should be settable');
  }
}