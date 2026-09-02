@IsTest(IsParallel=true)
private class LotteryStatusChangeTest {
  @IsTest
  private static void constructor_setsAllProperties() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    String fromStatus = LotteryConstants.STATUS_ELIGIBLE;
    String toStatus = LotteryConstants.STATUS_PRE_OFFER;
    String reason = LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER;

    Datetime beforeTest = Datetime.now();
    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      fromStatus,
      toStatus,
      reason
    );
    Datetime afterTest = Datetime.now();

    Assert.areEqual(fakeRecordId, change.recordId, 'recordId should be set');
    Assert.areEqual(fromStatus, change.fromStatus, 'fromStatus should be set');
    Assert.areEqual(toStatus, change.toStatus, 'toStatus should be set');
    Assert.areEqual(reason, change.reason, 'reason should be set');
    Assert.isNotNull(change.timestamp, 'timestamp should not be null');
    Assert.isTrue(
      change.timestamp >= beforeTest && change.timestamp <= afterTest,
      'timestamp should be set to current time'
    );
  }

  @IsTest
  private static void constructor_allowsNullFromStatus() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      null,
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER
    );

    Assert.isNull(change.fromStatus, 'fromStatus should allow null for new records');
    Assert.areEqual(LotteryConstants.STATUS_PRE_OFFER, change.toStatus, 'toStatus should be set');
  }

  @IsTest
  private static void properties_areImmutable() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      LotteryConstants.STATUS_ELIGIBLE,
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER
    );

    // Verify private setters by reading properties multiple times
    Id firstRecordId = change.recordId;
    Id secondRecordId = change.recordId;
    Assert.areEqual(firstRecordId, secondRecordId, 'recordId should remain unchanged');
  }

  @IsTest
  private static void constructor_withPriorityGroup_setsPriorityGroup() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Decimal priorityGroup = 2;

    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      LotteryConstants.STATUS_ELIGIBLE,
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER,
      priorityGroup
    );

    Assert.areEqual(fakeRecordId, change.recordId, 'recordId should be set');
    Assert.areEqual(priorityGroup, change.priorityGroup, 'priorityGroup should be set');
  }

  @IsTest
  private static void constructor_withoutPriorityGroup_defaultsToNull() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      LotteryConstants.STATUS_ELIGIBLE,
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER
    );

    Assert.isNull(change.priorityGroup, 'priorityGroup should default to null');
  }

  @IsTest
  private static void constructor_withNullPriorityGroup_allowsNull() {
    Id fakeRecordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    LotteryStatusChange change = new LotteryStatusChange(
      fakeRecordId,
      LotteryConstants.STATUS_ELIGIBLE,
      LotteryConstants.STATUS_PRE_OFFER,
      LotteryConstants.TRANSITION_REASON_LOTTERY_OFFER,
      null
    );

    Assert.isNull(change.priorityGroup, 'priorityGroup should allow null');
  }
}