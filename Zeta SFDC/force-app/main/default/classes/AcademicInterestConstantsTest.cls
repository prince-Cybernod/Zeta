/**
 * Tests for {@link AcademicInterestConstants}.
 */
@IsTest(IsParallel=true)
private class AcademicInterestConstantsTest {
  @IsTest
  private static void statusPreOffer_isNotNull() {
    Assert.isNotNull(AcademicInterestConstants.STATUS_PRE_OFFER);
  }

  @IsTest
  private static void statusSeatOffered_isNotNull() {
    Assert.isNotNull(AcademicInterestConstants.STATUS_SEAT_OFFERED);
  }

  @IsTest
  private static void statusSeatAccepted_isNotNull() {
    Assert.isNotNull(AcademicInterestConstants.STATUS_SEAT_ACCEPTED);
  }

  @IsTest
  private static void statusRescinded_isNotNull() {
    Assert.isNotNull(AcademicInterestConstants.STATUS_RESCINDED);
  }

  @IsTest
  private static void statusWithdrawnDeclined_isNotNull() {
    Assert.isNotNull(AcademicInterestConstants.STATUS_WITHDRAWN_DECLINED);
  }
}