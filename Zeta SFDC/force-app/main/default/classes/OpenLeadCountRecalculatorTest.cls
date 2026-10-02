/**
 * Tests for {@link OpenLeadCountRecalculator}.
 */
@IsTest(IsParallel=true)
private class OpenLeadCountRecalculatorTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void recalculate_withEmptySet_doesNotQuery() {
    new OpenLeadCountRecalculator(DATABASE_REPO_MOCK)
      .recalculate(new Set<Id>(), new Map<Id, Datetime>());

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withNullSet_doesNotQuery() {
    new OpenLeadCountRecalculator(DATABASE_REPO_MOCK).recalculate(null, null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withUserIds_queriesOpenLeadsGroupedByOwner() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);

    new OpenLeadCountRecalculator(DATABASE_REPO_MOCK)
      .recalculate(new Set<Id>{ userId }, new Map<Id, Datetime>());

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
  private static void recalculate_withNullStampMap_doesNotThrow() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);

    new OpenLeadCountRecalculator(DATABASE_REPO_MOCK).recalculate(new Set<Id>{ userId }, null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 1);
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingLeads_stampsZeroForEachUser() {
    Id userId1 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id userId2 = SObjectIds.generateFakeId(Schema.User.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    OpenLeadCountRecalculator recalculator = new OpenLeadCountRecalculator(DATABASE_REPO_MOCK);

    recalculator.processAggregateResults(
      new Set<Id>{ userId1, userId2 },
      new List<OpenLeadCountAggregateResult>(),
      new Map<Id, Datetime>()
    );

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
    OpenLeadCountRecalculator recalculator = new OpenLeadCountRecalculator(DATABASE_REPO_MOCK);

    recalculator.processAggregateResults(
      new Set<Id>{ userId1, userId2 },
      new List<OpenLeadCountAggregateResult>{ new OpenLeadCountAggregateResult(userId1, 4) },
      new Map<Id, Datetime>()
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
  private static void processAggregateResults_withStampForOneUser_setsLastLeadAssignedOnlyForThatUser() {
    Id stampedUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Id unstampedUserId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Datetime assignedAt = System.now();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    OpenLeadCountRecalculator recalculator = new OpenLeadCountRecalculator(DATABASE_REPO_MOCK);

    recalculator.processAggregateResults(
      new Set<Id>{ stampedUserId, unstampedUserId },
      new List<OpenLeadCountAggregateResult>(),
      new Map<Id, Datetime>{ stampedUserId => assignedAt }
    );

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updateCalls.size(), 'Should write both fields in a single update');
    Map<Id, User> usersById = new Map<Id, User>(updatedUsers);
    Assert.areEqual(
      assignedAt,
      usersById.get(stampedUserId).Last_Lead_Assigned__c,
      'Should stamp the requested User'
    );
    Assert.isNull(
      usersById.get(unstampedUserId).Last_Lead_Assigned__c,
      'Should leave a User with no stamp untouched'
    );
  }

  @IsTest
  private static void recalculate_withLockExceptionUnderRetryCap_throwsRetryableException() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenThrow(new DmlException('UNABLE_TO_LOCK_ROW: unable to obtain exclusive access'));
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    OpenLeadCountRecalculator.retryCountOverride = 0;

    Boolean threwRetryable = false;
    try {
      new OpenLeadCountRecalculator(DATABASE_REPO_MOCK)
        .recalculate(new Set<Id>{ userId }, new Map<Id, Datetime>());
    } catch (EventBus.RetryableException e) {
      threwRetryable = true;
    }

    Assert.isTrue(threwRetryable, 'Should throw a RetryableException under the retry cap');
  }

  @IsTest
  private static void recalculate_withLockExceptionAtRetryCap_rethrowsDmlException() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenThrow(new DmlException('UNABLE_TO_LOCK_ROW: unable to obtain exclusive access'));
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    OpenLeadCountRecalculator.retryCountOverride = 9;

    Boolean threwDml = false;
    try {
      new OpenLeadCountRecalculator(DATABASE_REPO_MOCK)
        .recalculate(new Set<Id>{ userId }, new Map<Id, Datetime>());
    } catch (DmlException e) {
      threwDml = true;
    }

    Assert.isTrue(threwDml, 'Should let the error surface once at the retry cap');
  }

  @IsTest
  private static void recalculate_withNonLockDmlException_rethrowsWithoutRetry() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects())
      .thenThrow(new DmlException('FIELD_CUSTOM_VALIDATION_EXCEPTION: some other error'));
    Id userId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    OpenLeadCountRecalculator.retryCountOverride = 0;

    Boolean threwDml = false;
    try {
      new OpenLeadCountRecalculator(DATABASE_REPO_MOCK)
        .recalculate(new Set<Id>{ userId }, new Map<Id, Datetime>());
    } catch (EventBus.RetryableException e) {
      Assert.fail('A non-lock DmlException should not be retried');
    } catch (DmlException e) {
      threwDml = true;
    }

    Assert.isTrue(threwDml, 'A non-lock DmlException should be rethrown unchanged');
  }
}