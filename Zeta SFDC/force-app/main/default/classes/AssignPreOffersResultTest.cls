/**
 * Tests for {@link AssignPreOffersResult}.
 */
@IsTest(IsParallel=true)
private class AssignPreOffersResultTest {
  @IsTest
  private static void constructor_initializesDefaults() {
    AssignPreOffersResult result = new AssignPreOffersResult();

    Assert.areEqual(0, result.preOfferCount, 'preOfferCount should default to 0');
    Assert.isTrue(result.isSuccess, 'isSuccess should default to true');
    Assert.isNull(result.errorMessage, 'errorMessage should default to null');
  }

  @IsTest
  private static void properties_canBeSetAndRead() {
    AssignPreOffersResult result = new AssignPreOffersResult();

    result.preOfferCount = 42;
    result.isSuccess = false;
    result.errorMessage = 'Test error';

    Assert.areEqual(42, result.preOfferCount, 'preOfferCount should be settable');
    Assert.isFalse(result.isSuccess, 'isSuccess should be settable');
    Assert.areEqual('Test error', result.errorMessage, 'errorMessage should be settable');
  }
}