/**
 * Tests for {@link OptimizeOffersResult}.
 */
@IsTest(IsParallel=true)
private class OptimizeOffersResultTest {
  @IsTest
  private static void constructor_initializesDefaults() {
    OptimizeOffersResult result = new OptimizeOffersResult();

    Assert.areEqual(0, result.rescindedCount, 'rescindedCount should default to 0');
    Assert.isTrue(result.isSuccess, 'isSuccess should default to true');
    Assert.isNull(result.errorMessage, 'errorMessage should default to null');
    Assert.areEqual(0, result.withdrawnCount, 'withdrawnCount should default to 0');
  }

  @IsTest
  private static void properties_canBeSetAndRead() {
    OptimizeOffersResult result = new OptimizeOffersResult();

    result.rescindedCount = 5;
    result.withdrawnCount = 3;
    result.isSuccess = false;
    result.errorMessage = 'Test error';

    Assert.areEqual(5, result.rescindedCount, 'rescindedCount should be settable');
    Assert.areEqual(3, result.withdrawnCount, 'withdrawnCount should be settable');
    Assert.isFalse(result.isSuccess, 'isSuccess should be settable');
    Assert.areEqual('Test error', result.errorMessage, 'errorMessage should be settable');
  }
}