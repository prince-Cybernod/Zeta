/**
 * Tests for {@link OpenLeadCountServiceImpl}.
 */
@IsTest(IsParallel=true)
private class OpenLeadCountServiceImplTest {
  @IsTest
  private static void recalculateOpenLeadCount_withUserIds_enqueuesJob() {
    OpenLeadCountServiceImpl service = new OpenLeadCountServiceImpl();
    Set<Id> userIds = new Set<Id>{ SObjectIds.generateFakeId(Schema.User.SObjectType) };

    Test.startTest();
    service.recalculateOpenLeadCount(userIds);
    Test.stopTest();

    Assert.isTrue(service.hasEnqueuedJob, 'Should have enqueued a job');
  }

  @IsTest
  private static void recalculateOpenLeadCount_withEmptySet_doesNotEnqueueJob() {
    OpenLeadCountServiceImpl service = new OpenLeadCountServiceImpl();

    Test.startTest();
    service.recalculateOpenLeadCount(new Set<Id>());
    Test.stopTest();

    Assert.isFalse(service.hasEnqueuedJob, 'Should not have enqueued a job');
  }

  @IsTest
  private static void recalculateOpenLeadCount_withNullSet_doesNotEnqueueJob() {
    OpenLeadCountServiceImpl service = new OpenLeadCountServiceImpl();

    Test.startTest();
    service.recalculateOpenLeadCount(null);
    Test.stopTest();

    Assert.isFalse(service.hasEnqueuedJob, 'Should not have enqueued a job');
  }
}