/**
 * Tests for {@link EventBusRepoImpl}.
 */
@IsTest(IsParallel=true)
private class EventBusRepoImplTest {
  private static final EventBusRepoImpl EVENT_BUS_REPO;
  private static final SObject PLATFORM_EVENT;

  static {
    EVENT_BUS_REPO = new EventBusRepoImpl();
    PLATFORM_EVENT = findPlatformEvent();
  }

  private static SObject findPlatformEvent() {
    for (Schema.SObjectType sot : Schema.getGlobalDescribe().values()) {
      String name = sot.getDescribe().getName();
      if (name.endsWith('__e')) {
        return sot.newSObject();
      }
    }
    return null;
  }

  @IsTest
  private static void publishSingle_publishesEvent() {
    if (PLATFORM_EVENT == null) {
      return;
    }

    Test.startTest();
    Database.SaveResult result = EVENT_BUS_REPO.publish(PLATFORM_EVENT);
    Test.stopTest();

    Assert.isNotNull(result);
  }

  @IsTest
  private static void publishList_publishesEvents() {
    if (PLATFORM_EVENT == null) {
      return;
    }
    List<SObject> events = new List<SObject>{ PLATFORM_EVENT };

    Test.startTest();
    List<Database.SaveResult> results = EVENT_BUS_REPO.publish(events);
    Test.stopTest();

    Assert.isNotNull(results);
    Assert.areEqual(1, results.size());
  }
}