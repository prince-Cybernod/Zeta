/**
 * Tests for {@link ActiveEnrollmentsRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class ActiveEnrollmentsRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ActiveEnrollmentsRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new ActiveEnrollmentsRollupServiceImpl(MOCK_REPO);
  }

  private static Map<Id, Decimal> getUpdatedCounts() {
    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    Map<Id, Decimal> countsById = new Map<Id, Decimal>();
    for (SObject record : (List<SObject>) updateCalls[0].get('sobjects')) {
      Account account = (Account) record;
      countsById.put(account.Id, account.Active_Enrollments__c);
    }
    return countsById;
  }

  @IsTest
  private static void processAggregateResults_withLearnerEnrollments_calculatesCorrectCount() {
    Id learnerId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ learnerId },
      new List<ActiveEnrollmentsAggregateResult>{
        new ActiveEnrollmentsAggregateResult(learnerId, 2)
      }
    );

    Assert.areEqual(2, getUpdatedCounts().get(learnerId), 'Should set the learner count to 2');
  }

  @IsTest
  private static void processAggregateResults_withGuardianInBothLookups_sumsBothTallies() {
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    // One tally from the Primary_Guardian__c path, one from Secondary_Guardian__c
    SERVICE.processAggregateResults(
      new Set<Id>{ guardianId },
      new List<ActiveEnrollmentsAggregateResult>{
        new ActiveEnrollmentsAggregateResult(guardianId, 2),
        new ActiveEnrollmentsAggregateResult(guardianId, 1)
      }
    );

    Assert.areEqual(3, getUpdatedCounts().get(guardianId), 'Should sum both guardian tallies');
  }

  @IsTest
  private static void processAggregateResults_withOneEnrollmentAcrossThreeAccounts_countsEachOnce() {
    Id primaryGuardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id secondaryGuardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id learnerId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ primaryGuardianId, secondaryGuardianId, learnerId },
      new List<ActiveEnrollmentsAggregateResult>{
        new ActiveEnrollmentsAggregateResult(primaryGuardianId, 1),
        new ActiveEnrollmentsAggregateResult(secondaryGuardianId, 1),
        new ActiveEnrollmentsAggregateResult(learnerId, 1)
      }
    );

    Map<Id, Decimal> countsById = getUpdatedCounts();
    Assert.areEqual(1, countsById.get(primaryGuardianId), 'Primary guardian should have 1');
    Assert.areEqual(1, countsById.get(secondaryGuardianId), 'Secondary guardian should have 1');
    Assert.areEqual(1, countsById.get(learnerId), 'Learner should have 1');
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsCountToZero() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ accountId },
      new List<ActiveEnrollmentsAggregateResult>()
    );

    Assert.areEqual(
      0,
      getUpdatedCounts().get(accountId),
      'Should set count to 0 when no enrollments match'
    );
  }

  @IsTest
  private static void processAggregateResults_withUnrequestedAccount_ignoresIt() {
    Id requestedId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id unrequestedId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(
      new Set<Id>{ requestedId },
      new List<ActiveEnrollmentsAggregateResult>{
        new ActiveEnrollmentsAggregateResult(unrequestedId, 9)
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
      new List<ActiveEnrollmentsAggregateResult>{
        new ActiveEnrollmentsAggregateResult(accountId1, 2),
        new ActiveEnrollmentsAggregateResult(accountId2, 4)
      }
    );

    Map<Id, Decimal> countsById = getUpdatedCounts();
    Assert.areEqual(3, countsById.size(), 'Should update all three Accounts');
    Assert.areEqual(2, countsById.get(accountId1), 'Account 1 should have a count of 2');
    Assert.areEqual(4, countsById.get(accountId2), 'Account 2 should have a count of 4');
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
  private static void recalculate_queriesAllThreeLookupPaths() {
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
      String field : new List<String>{
        'LearnerAccountId',
        'LearnerAccount.Primary_Guardian__c',
        'LearnerAccount.Secondary_Guardian__c'
      }
    ) {
      Boolean isFound = false;
      for (String query : queried) {
        isFound = isFound || query.contains('GROUP BY ' + field);
      }
      Assert.isTrue(isFound, 'Should group by ' + field);
    }
  }

  /**
   * Canary: every query must restrict to Active__c = true. If the filter is
   * ever dropped, withdrawn/inactive enrollments would inflate the count and
   * this assertion fails.
   */
  @IsTest
  private static void recalculate_everyQueryFiltersOnActiveTrue() {
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ SObjectIds.generateFakeId(Schema.Account.SObjectType) });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 3);
    for (Map<String, Object> call : MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())) {
      Assert.isTrue(
        ((String) call.get('query')).contains('AND Active__c = true'),
        'Every query should filter to active enrollments only'
      );
    }
  }

  @IsTest
  private static void recalculate_withBulkIds_handlesTwoHundredAccounts() {
    Set<Id> accountIds = new Set<Id>();
    for (Integer i = 0; i < 200; i++) {
      accountIds.add(SObjectIds.generateFakeId(Schema.Account.SObjectType));
    }

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>())
      .thenReturn(new List<AggregateResult>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(accountIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 3);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
    Assert.areEqual(200, getUpdatedCounts().size(), 'Should update all 200 Accounts');
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    ActiveEnrollmentsRollupServiceImpl service = new ActiveEnrollmentsRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}