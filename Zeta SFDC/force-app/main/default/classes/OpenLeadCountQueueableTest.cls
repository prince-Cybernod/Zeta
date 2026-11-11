/**
 * Tests for {@link OpenLeadCountQueueable}.
 */
@IsTest(IsParallel=true)
private class OpenLeadCountQueueableTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void execute_withEmptySet_doesNotQuery() {
    new OpenLeadCountQueueable(new Set<Id>(), DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withNullSet_doesNotQuery() {
    new OpenLeadCountQueueable(null, DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withUserIds_queriesOpenLeadsGroupedByOwner() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);

    new OpenLeadCountQueueable(new Set<Id>{ userId }, DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 1);
    List<Map<String, Object>> queryCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    );
    String query = (String) queryCalls[0].get('query');
    Assert.isTrue(query.contains('Is_Open_Status__c'), 'Should filter on open status');
    Assert.isTrue(query.contains('GROUP BY OwnerId'), 'Should group by owner');
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');
    Assert.areEqual(
      new Set<Id>{ userId },
      bindMap.get('userIds'),
      'Should bind the requested User ids'
    );
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingLeads_stampsZeroForEachUser() {
    Id userId1 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id userId2 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    OpenLeadCountQueueable queueable = new OpenLeadCountQueueable(
      new Set<Id>{ userId1, userId2 },
      DATABASE_REPO_MOCK
    );

    queueable.processAggregateResults(new List<OpenLeadCountAggregateResult>());

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, updatedUsers.size(), 'Should stamp both Users');
    for (User updatedUser : updatedUsers) {
      Assert.areEqual(
        0,
        updatedUser.Open_Lead_Count__c,
        'A User with no matching open Leads should be stamped zero, not skipped'
      );
    }
  }

  @IsTest
  private static void processAggregateResults_withCountForOneUser_overlaysCountAndKeepsOtherAtZero() {
    Id userId1 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id userId2 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    OpenLeadCountQueueable queueable = new OpenLeadCountQueueable(
      new Set<Id>{ userId1, userId2 },
      DATABASE_REPO_MOCK
    );

    queueable.processAggregateResults(
      new List<OpenLeadCountAggregateResult>{ new OpenLeadCountAggregateResult(userId1, 4) }
    );

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Map<Id, Decimal> countsByUserId = new Map<Id, Decimal>();
    for (User updatedUser : updatedUsers) {
      countsByUserId.put(updatedUser.Id, updatedUser.Open_Lead_Count__c);
    }
    Assert.areEqual(4, countsByUserId.get(userId1), 'Should overlay the aggregated count');
    Assert.areEqual(
      0,
      countsByUserId.get(userId2),
      'A User with no matching open Leads should be zero, not skipped'
    );
  }

  @IsTest
  private static void execute_withRealLeadDml_stampsRealAggregateCountOnUser() {
    Id currentUserId = UserInfo.getUserId();
    insert new Lead(
      LastName = 'OpenLeadCountQueueableTest',
      Company = 'OpenLeadCountQueueableTest',
      Phone = '5551234567',
      Status = 'Open – Working',
      OwnerId = currentUserId
    );

    Test.startTest();
    System.enqueueJob(new OpenLeadCountQueueable(new Set<Id>{ currentUserId }));
    Test.stopTest();

    User updatedUser = [SELECT Open_Lead_Count__c FROM User WHERE Id = :currentUserId];
    Assert.areEqual(
      1,
      updatedUser.Open_Lead_Count__c,
      'A real open Lead owned by this User should produce a real aggregate count of 1'
    );
  }
}