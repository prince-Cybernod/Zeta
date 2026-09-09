/**
 * Tests for {@link ApplicationCountRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class ApplicationCountRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ApplicationCountRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new ApplicationCountRollupServiceImpl(MOCK_REPO);
  }

  private static Map<Id, Decimal> getUpdatedCounts() {
    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    Map<Id, Decimal> countsById = new Map<Id, Decimal>();
    for (SObject record : (List<SObject>) updateCalls[0].get('sobjects')) {
      Account account = (Account) record;
      countsById.put(account.Id, account.Application_Count__c);
    }
    return countsById;
  }

  @IsTest
  private static void processAggregateResults_withStudentApplications_calculatesCorrectCount() {
    Id studentId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ studentId },
      new List<ApplicationCountAggregateResult>{ new ApplicationCountAggregateResult(studentId, 4) }
    );

    Assert.areEqual(4, getUpdatedCounts().get(studentId), 'Should set the student count to 4');
  }

  @IsTest
  private static void processAggregateResults_withGuardianInBothLookups_sumsBothTallies() {
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    // One tally from the Primary_Guardian__c query, one from Secondary_Guardian__c
    SERVICE.processAggregateResults(
      new Set<Id>{ guardianId },
      new List<ApplicationCountAggregateResult>{
        new ApplicationCountAggregateResult(guardianId, 3),
        new ApplicationCountAggregateResult(guardianId, 2)
      }
    );

    Assert.areEqual(5, getUpdatedCounts().get(guardianId), 'Should sum both guardian tallies');
  }

  @IsTest
  private static void processAggregateResults_withOneApplicationAcrossThreeAccounts_countsEachOnce() {
    Id primaryGuardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id secondaryGuardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ primaryGuardianId, secondaryGuardianId, studentId },
      new List<ApplicationCountAggregateResult>{
        new ApplicationCountAggregateResult(primaryGuardianId, 1),
        new ApplicationCountAggregateResult(secondaryGuardianId, 1),
        new ApplicationCountAggregateResult(studentId, 1)
      }
    );

    Map<Id, Decimal> countsById = getUpdatedCounts();
    Assert.areEqual(1, countsById.get(primaryGuardianId), 'Primary guardian should have 1');
    Assert.areEqual(1, countsById.get(secondaryGuardianId), 'Secondary guardian should have 1');
    Assert.areEqual(1, countsById.get(studentId), 'Student should have 1');
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsCountToZero() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ accountId },
      new List<ApplicationCountAggregateResult>()
    );

    Assert.areEqual(
      0,
      getUpdatedCounts().get(accountId),
      'Should set count to 0 when no applications match'
    );
  }

  @IsTest
  private static void processAggregateResults_withUnrequestedAccount_ignoresIt() {
    Id requestedId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id unrequestedId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ requestedId },
      new List<ApplicationCountAggregateResult>{
        new ApplicationCountAggregateResult(unrequestedId, 9)
      }
    );

    Map<Id, Decimal> countsById = getUpdatedCounts();
    Assert.areEqual(1, countsById.size(), 'Should only update the requested Account');
    Assert.areEqual(0, countsById.get(requestedId), 'Requested Account should be zeroed');
  }

  @IsTest
  private static void processAggregateResults_withMultipleAccounts_updatesAllRecords() {
    Id accountId1 = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accountId2 = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accountId3 = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ accountId1, accountId2, accountId3 },
      new List<ApplicationCountAggregateResult>{
        new ApplicationCountAggregateResult(accountId1, 2),
        new ApplicationCountAggregateResult(accountId2, 5)
      }
    );

    Map<Id, Decimal> countsById = getUpdatedCounts();
    Assert.areEqual(3, countsById.size(), 'Should update all three Accounts');
    Assert.areEqual(2, countsById.get(accountId1), 'Account 1 should have a count of 2');
    Assert.areEqual(5, countsById.get(accountId2), 'Account 2 should have a count of 5');
    Assert.areEqual(0, countsById.get(accountId3), 'Account 3 should have a count of 0');
  }

  @IsTest
  private static void recalculate_withEmptySet_doesNotQuery() {
    SERVICE.recalculate(new Set<Id>());

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withNullSet_doesNotQuery() {
    SERVICE.recalculate(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withValidIds_queriesEachLookupOnce() {
    Id accountId1 = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accountId2 = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ accountId1, accountId2 });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 3);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
    Assert.areEqual(2, getUpdatedCounts().size(), 'Should update both Accounts');
  }

  @IsTest
  private static void recalculate_queriesAllThreeLookupFields() {
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ SObjectIds.generateFakeId(Schema.Account.SObjectType) });

    Set<String> queried = new Set<String>();
    for (Map<String, Object> call : MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())) {
      queried.add((String) call.get('query'));
    }

    Assert.areEqual(3, queried.size(), 'Should issue three distinct queries');
    for (
      String field : new List<String>{ 'Primary_Guardian__c', 'Secondary_Guardian__c', 'AccountId' }
    ) {
      Boolean isFound = false;
      for (String query : queried) {
        isFound = isFound || query.contains('GROUP BY ' + field);
      }
      Assert.isTrue(isFound, 'Should group by ' + field);
    }
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    ApplicationCountRollupServiceImpl service = new ApplicationCountRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}