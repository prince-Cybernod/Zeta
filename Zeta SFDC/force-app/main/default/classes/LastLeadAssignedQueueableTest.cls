/**
 * Tests for {@link LastLeadAssignedQueueable}.
 */
@IsTest(IsParallel=true)
private class LastLeadAssignedQueueableTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void execute_withUserIds_stampsLastLeadAssignedOnEachUser() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    Id userId1 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id userId2 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Datetime assignedAt = System.now();

    new LastLeadAssignedQueueable(
        new Set<Id>{ userId1, userId2 },
        assignedAt,
        DATABASE_REPO_MOCK
      )
      .execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 1);
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) calls[0].get('sobjects');
    Assert.areEqual(2, updatedUsers.size(), 'Should update both Users');
    for (User updatedUser : updatedUsers) {
      Assert.areEqual(
        assignedAt,
        updatedUser.Last_Lead_Assigned__c,
        'Should stamp the captured assignment time'
      );
    }
  }

  @IsTest
  private static void execute_withEmptySet_doesNotUpdate() {
    new LastLeadAssignedQueueable(new Set<Id>(), System.now(), DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withNullSet_doesNotUpdate() {
    new LastLeadAssignedQueueable(null, System.now(), DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }
}