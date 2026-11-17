/**
 * Tests for {@link CharterRollupBatch}.
 */
@IsTest(IsParallel=true)
private class CharterRollupBatchTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final CharterRollupServiceMock ROLLUP_MOCK;
  private static final CharterRollupBatch BATCH;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    ROLLUP_MOCK = new CharterRollupServiceMock();
    BATCH = new CharterRollupBatch(MOCK_REPO, ROLLUP_MOCK);
  }

  @IsTest
  private static void getCharterRecordTypeId_returnsCharterRecordType() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

    Id result = CharterRollupBatch.getCharterRecordTypeId();

    Assert.areEqual(recordTypeInfos.get('Charter').getRecordTypeId(), result);
  }

  @IsTest
  private static void start_scopesTheQueryToTheCharterRecordType() {
    MOCK_REPO.when(MOCK_REPO.method.getQueryLocatorWithBinds())
      .thenReturn(Database.getQueryLocator('SELECT Id FROM Account LIMIT 1'));

    BATCH.start(null);

    MOCK_REPO.verify(MOCK_REPO.method.getQueryLocatorWithBinds(), 1);
    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.getQueryLocatorWithBinds())[0];
    Assert.isTrue(
      ((String) call.get('query')).contains('RecordTypeId = :charterRecordTypeId'),
      'Should filter on the Charter RecordType'
    );

    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(
      CharterRollupBatch.getCharterRecordTypeId(),
      bindMap.get('charterRecordTypeId'),
      'Should bind the Charter RecordType id'
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
      .get('charterAccountIds');
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
    Assert.isNotNull(new CharterRollupBatch(), 'Should create with default constructor');
  }
}