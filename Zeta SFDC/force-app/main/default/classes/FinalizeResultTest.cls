/**
 * Tests for {@link FinalizeResult}.
 */
@IsTest(IsParallel=true)
private class FinalizeResultTest {
  @IsTest
  private static void constructor_initializesDefaults() {
    FinalizeResult result = new FinalizeResult();

    Assert.areEqual(0, result.waitlistCount, 'waitlistCount should default to 0');
    Assert.areEqual(0, result.eventsPublished, 'eventsPublished should default to 0');
    Assert.isTrue(result.isSuccess, 'isSuccess should default to true');
    Assert.isNull(result.errorMessage, 'errorMessage should default to null');
  }

  @IsTest
  private static void properties_canBeSetAndRead() {
    FinalizeResult result = new FinalizeResult();

    result.waitlistCount = 25;
    result.eventsPublished = 3;
    result.isSuccess = false;
    result.errorMessage = 'Test error';

    Assert.areEqual(25, result.waitlistCount, 'waitlistCount should be settable');
    Assert.areEqual(3, result.eventsPublished, 'eventsPublished should be settable');
    Assert.isFalse(result.isSuccess, 'isSuccess should be settable');
    Assert.areEqual('Test error', result.errorMessage, 'errorMessage should be settable');
  }
}