/**
 * Tests for {@link PriorityItemConstants}.
 */
@IsTest(IsParallel=true)
private class PriorityItemConstantsTest {
  @IsTest
  private static void priorityTypeSiblingApplying_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING);
  }

  @IsTest
  private static void priorityTypeSiblingAttending_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING);
  }

  @IsTest
  private static void priorityTypeParentIsZetaStaff_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF);
  }

  @IsTest
  private static void reviewStatusApproved_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.REVIEW_STATUS_APPROVED);
  }

  @IsTest
  private static void reviewStatusDenied_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.REVIEW_STATUS_DENIED);
  }

  @IsTest
  private static void reviewStatusPending_isNotNull() {
    Assert.isNotNull(PriorityItemConstants.REVIEW_STATUS_PENDING);
  }
}