/**
 * Tests for {@link WaitlistConstants}.
 */
@IsTest(IsParallel=true)
private class WaitlistConstantsTest {
  @IsTest
  private static void statusWaitlisted_isNotNull() {
    Assert.isNotNull(WaitlistConstants.STATUS_WAITLISTED);
  }

  @IsTest
  private static void statusEligible_isNotNull() {
    Assert.isNotNull(WaitlistConstants.STATUS_ELIGIBLE);
  }

  @IsTest
  private static void historyTrackedFields_isNotNull() {
    Assert.isNotNull(WaitlistConstants.HISTORY_TRACKED_FIELDS);
  }

  @IsTest
  private static void historyTrackedFields_containsExpectedFields() {
    List<SObjectField> fields = WaitlistConstants.HISTORY_TRACKED_FIELDS;
    Assert.areEqual(3, fields.size(), 'Expected 3 tracked fields');
  }
}