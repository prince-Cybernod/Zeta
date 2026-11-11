/**
 * Tests for {@link ApplicationCountRollupBatch}.
 */
@IsTest(IsParallel=true)
private class ApplicationCountRollupBatchTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ApplicationCountRollupServiceMock ROLLUP_MOCK;
  private static final ApplicationCountRollupBatch BATCH;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    ROLLUP_MOCK = new ApplicationCountRollupServiceMock();
    BATCH = new ApplicationCountRollupBatch(MOCK_REPO, ROLLUP_MOCK);
  }

  @IsTest
  private static void getApplicantRecordTypeIds_returnsGuardianAndStudent() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

    Set<Id> recordTypeIds = ApplicationCountRollupBatch.getApplicantRecordTypeIds();

    Assert.areEqual(2, recordTypeIds.size(), 'Should resolve both applicant record types');
    Assert.isTrue(
      recordTypeIds.contains(recordTypeInfos.get('Guardian').getRecordTypeId()),
      'Should include Guardian'
    );
    Assert.isTrue(
      recordTypeIds.contains(recordTypeInfos.get('Student').getRecordTypeId()),
      'Should include Student'
    );
  }

  @IsTest
  private static void start_scopesTheQueryToApplicantRecordTypes() {
    MOCK_REPO.when(MOCK_REPO.method.getQueryLocatorWithBinds())
      .thenReturn(Database.getQueryLocator('SELECT Id FROM Account LIMIT 1'));

    BATCH.start(null);

    MOCK_REPO.verify(MOCK_REPO.method.getQueryLocatorWithBinds(), 1);
    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.getQueryLocatorWithBinds())[0];
    Assert.isTrue(
      ((String) call.get('query')).contains('RecordTypeId IN :recordTypeIds'),
      'Should filter on record type'
    );

    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(
      2,
      ((Set<Id>) bindMap.get('recordTypeIds')).size(),
      'Should bind both applicant record types'
    );
  }

  @IsTest
  private static void execute_delegatesScopeIdsToTheService() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id accountId1 = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accountId2 = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    BATCH.execute(
      null,
      new List<SObject>{ new Account(Id = accountId1), new Account(Id = accountId2) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = (Set<Id>) ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate())[0]
      .get('accountIds');
    Assert.areEqual(2, capturedIds.size(), 'Should pass both Account IDs');
    Assert.isTrue(capturedIds.contains(accountId1), 'Should include the first Account');
    Assert.isTrue(capturedIds.contains(accountId2), 'Should include the second Account');
  }

  @IsTest
  private static void finish_doesNotThrow() {
    BATCH.finish(null);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    Assert.isNotNull(new ApplicationCountRollupBatch(), 'Should create with default constructor');
  }
}