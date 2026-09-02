/**
 * Tests for {@link SiblingApplyingRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class SiblingApplyingRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final SiblingApplyingRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new SiblingApplyingRollupServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void processAggregateResults_withApprovedSiblingApplying_calculatesCorrectCount() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<SiblingApplyingAggregateResult> wrappedResults = new List<SiblingApplyingAggregateResult>{
      new SiblingApplyingAggregateResult(appId1, 3)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    IndividualApplication updatedApp = (IndividualApplication) updatedRecords[0];
    Assert.areEqual(appId1, updatedApp.Id, 'Should update the correct application');
    Assert.areEqual(3, updatedApp.Count_of_Sibling_Applying__c, 'Should set count to 3');
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsCountToZero() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<SiblingApplyingAggregateResult> emptyResults = new List<SiblingApplyingAggregateResult>();

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, emptyResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    IndividualApplication updatedApp = (IndividualApplication) updatedRecords[0];
    Assert.areEqual(appId1, updatedApp.Id, 'Should update the correct application');
    Assert.areEqual(
      0,
      updatedApp.Count_of_Sibling_Applying__c,
      'Should set count to 0 when no matches'
    );
  }

  @IsTest
  private static void processAggregateResults_withMultipleApplications_updatesAllRecords() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId3 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1, appId2, appId3 };

    List<SiblingApplyingAggregateResult> wrappedResults = new List<SiblingApplyingAggregateResult>{
      new SiblingApplyingAggregateResult(appId1, 2),
      new SiblingApplyingAggregateResult(appId2, 5)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(3, updatedRecords.size(), 'Should update all three applications');

    Map<Id, Decimal> countsById = new Map<Id, Decimal>();
    for (SObject record : updatedRecords) {
      IndividualApplication app = (IndividualApplication) record;
      countsById.put(app.Id, app.Count_of_Sibling_Applying__c);
    }

    Assert.areEqual(2, countsById.get(appId1), 'App 1 should have count of 2');
    Assert.areEqual(5, countsById.get(appId2), 'App 2 should have count of 5');
    Assert.areEqual(0, countsById.get(appId3), 'App 3 should have count of 0 (no matches)');
  }

  @IsTest
  private static void recalculate_withEmptySet_doesNotQuery() {
    Set<Id> emptySet = new Set<Id>();

    SERVICE.recalculate(emptySet);

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
  private static void recalculate_withValidIds_queriesAndProcesses() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1, appId2 };

    List<AggregateResult> mockResults = new List<AggregateResult>();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockResults);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, updatedRecords.size(), 'Should update both applications');
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    SiblingApplyingRollupServiceImpl service = new SiblingApplyingRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}