/**
 * Tests for {@link LeadOwnerEventHandler}.
 */
@IsTest(IsParallel=true)
private class LeadOwnerEventHandlerTest {
  private static final LeadOwnerEventHandler HANDLER;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    HANDLER = new LeadOwnerEventHandler(new OpenLeadCountRecalculator(DATABASE_REPO_MOCK));
  }

  @IsTest
  private static void getSObjectType_returnsLeadOwnerEvent() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Lead_Owner_Event__e.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_withValidOwnerId_recalculatesCount() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId))
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 1);
    List<Map<String, Object>> queryCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    );
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');
    Assert.areEqual(
      new Set<Id>{ ownerId },
      bindMap.get('userIds'),
      'Should recalculate for the owner'
    );
  }

  @IsTest
  private static void onAfterInsert_withDuplicateOwnerIds_deduplicates() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId)),
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId))
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    List<Map<String, Object>> queryCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    );
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');
    Assert.areEqual(
      new Set<Id>{ ownerId },
      bindMap.get('userIds'),
      'Should deduplicate to one owner id'
    );
  }

  @IsTest
  private static void onAfterInsert_withEmptyOwnerId_doesNotRecalculate() {
    List<SObject> events = new List<SObject>{ new Lead_Owner_Event__e(Owner_Id__c = '') };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void onAfterInsert_withInvalidOwnerId_skipsInvalidAndContinues() {
    Id validOwnerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = 'invalid-id'),
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(validOwnerId))
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    List<Map<String, Object>> queryCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    );
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');
    Assert.areEqual(
      new Set<Id>{ validOwnerId },
      bindMap.get('userIds'),
      'Should recalculate for the valid owner id only'
    );
  }

  @IsTest
  private static void onAfterInsert_withEmptyList_doesNotRecalculate() {
    List<SObject> events = new List<SObject>();

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void onAfterInsert_withLaterEventFirst_stillStampsLatestInOneUpdate() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Datetime earlier = Datetime.newInstance(2026, 1, 1, 0, 0, 0);
    Datetime later = Datetime.newInstance(2026, 1, 2, 0, 0, 0);
    // The later stamp comes ahead of the earlier one, so a handler that keeps the last
    // event rather than the maximum fails.
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId), Assigned_At__c = later),
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId), Assigned_At__c = earlier)
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 1);
    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedUsers.size(), 'Should update the owner once');
    Assert.areEqual(
      later,
      updatedUsers[0].Last_Lead_Assigned__c,
      'Should stamp the latest Assigned_At__c seen in the batch'
    );
    Assert.isNotNull(
      updatedUsers[0].Open_Lead_Count__c,
      'Should recount in the same update that stamps the assignment'
    );
  }

  @IsTest
  private static void onAfterInsert_withUnstampedEventAfterStampedOne_doesNotOverwriteTheStamp() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    Datetime assignedAt = Datetime.newInstance(2026, 1, 1, 0, 0, 0);
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId), Assigned_At__c = assignedAt),
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId))
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Assert.areEqual(
      assignedAt,
      updatedUsers[0].Last_Lead_Assigned__c,
      'A later event with no Assigned_At__c should not blank out an earlier stamp'
    );
  }

  @IsTest
  private static void onAfterInsert_withNoAssignedAt_leavesLastLeadAssignedUnset() {
    Id ownerId = SObjectIds.generateFakeId(Schema.User.SObjectType);
    List<SObject> events = new List<SObject>{
      new Lead_Owner_Event__e(Owner_Id__c = String.valueOf(ownerId))
    };

    Test.startTest();
    HANDLER.onAfterInsert(events);
    Test.stopTest();

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<User> updatedUsers = (List<User>) updateCalls[0].get('sobjects');
    Assert.isNull(
      updatedUsers[0].Last_Lead_Assigned__c,
      'Should not stamp when no event carried an assignment time'
    );
  }
}