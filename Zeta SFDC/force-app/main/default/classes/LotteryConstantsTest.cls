/**
 * Tests for {@link LotteryConstants}.
 */
@IsTest(IsParallel=true)
private class LotteryConstantsTest {
  @IsTest
  private static void STATUS_ELIGIBLE_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_ELIGIBLE);
  }

  @IsTest
  private static void STATUS_PRE_OFFER_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_PRE_OFFER);
  }

  @IsTest
  private static void STATUS_SEAT_OFFERED_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_SEAT_OFFERED);
  }

  @IsTest
  private static void STATUS_WAITLISTED_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_WAITLISTED);
  }

  @IsTest
  private static void STATUS_RESCINDED_OPTIMIZATION_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_RESCINDED_OPTIMIZATION);
  }

  @IsTest
  private static void STATUS_RESCINDED_isNotNull() {
    Assert.isNotNull(LotteryConstants.STATUS_RESCINDED);
  }

  @IsTest
  private static void LOTTERY_RUN_STATUS_DRAFT_isNotNull() {
    Assert.isNotNull(LotteryConstants.LOTTERY_RUN_STATUS_DRAFT);
  }

  @IsTest
  private static void LOTTERY_RUN_STATUS_PUBLISHED_isNotNull() {
    Assert.isNotNull(LotteryConstants.LOTTERY_RUN_STATUS_PUBLISHED);
  }
}