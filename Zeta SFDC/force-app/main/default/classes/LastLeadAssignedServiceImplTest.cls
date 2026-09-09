/**
 * Tests for {@link LastLeadAssignedServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LastLeadAssignedServiceImplTest {
  @IsTest
  private static void stampLastLeadAssigned_withUserIds_enqueuesJob() {
    LastLeadAssignedServiceImpl service = new LastLeadAssignedServiceImpl();
    Set<Id> userIds = new Set<Id>{ SObjectIds.generateFakeId(Schema.User.SObjectType) };

    Test.startTest();
    service.stampLastLeadAssigned(userIds, System.now());
    Test.stopTest();

    Assert.isTrue(service.hasEnqueuedJob, 'Should have enqueued a job');
  }

  @IsTest
  private static void stampLastLeadAssigned_withEmptySet_doesNotEnqueueJob() {
    LastLeadAssignedServiceImpl service = new LastLeadAssignedServiceImpl();

    Test.startTest();
    service.stampLastLeadAssigned(new Set<Id>(), System.now());
    Test.stopTest();

    Assert.isFalse(service.hasEnqueuedJob, 'Should not have enqueued a job');
  }

  @IsTest
  private static void stampLastLeadAssigned_withNullSet_doesNotEnqueueJob() {
    LastLeadAssignedServiceImpl service = new LastLeadAssignedServiceImpl();

    Test.startTest();
    service.stampLastLeadAssigned(null, System.now());
    Test.stopTest();

    Assert.isFalse(service.hasEnqueuedJob, 'Should not have enqueued a job');
  }
}