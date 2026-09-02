/**
 * Tests for {@link PriorityGroupRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class PriorityGroupRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final PriorityGroupRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new PriorityGroupRollupServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void processAggregateResults_withResults_setsMinPriorityGroup() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PriorityGroupAggregateResult> wrappedResults = new List<PriorityGroupAggregateResult>{
      new PriorityGroupAggregateResult(appId1, 2.0)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    IndividualApplication updatedApp = (IndividualApplication) updatedRecords[0];
    Assert.areEqual(appId1, updatedApp.Id, 'Should update the correct application');
    Assert.areEqual(
      2.0,
      updatedApp.Relationship_Priority_Group__c,
      'Should set priority group to 2.0'
    );
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsToNull() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PriorityGroupAggregateResult> emptyResults = new List<PriorityGroupAggregateResult>();

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, emptyResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    IndividualApplication updatedApp = (IndividualApplication) updatedRecords[0];
    Assert.areEqual(appId1, updatedApp.Id, 'Should update the correct application');
    Assert.areEqual(
      null,
      updatedApp.Relationship_Priority_Group__c,
      'Should set priority group to null when no approved priority items'
    );
  }

  @IsTest
  private static void processAggregateResults_withMultipleApplications_updatesAll() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId3 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1, appId2, appId3 };

    List<PriorityGroupAggregateResult> wrappedResults = new List<PriorityGroupAggregateResult>{
      new PriorityGroupAggregateResult(appId1, 1.0),
      new PriorityGroupAggregateResult(appId2, 3.0)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(3, updatedRecords.size(), 'Should update all three applications');

    Map<Id, Decimal> priorityGroupById = new Map<Id, Decimal>();
    for (SObject record : updatedRecords) {
      IndividualApplication app = (IndividualApplication) record;
      priorityGroupById.put(app.Id, app.Relationship_Priority_Group__c);
    }

    Assert.areEqual(1.0, priorityGroupById.get(appId1), 'App 1 should have priority group 1.0');
    Assert.areEqual(3.0, priorityGroupById.get(appId2), 'App 2 should have priority group 3.0');
    Assert.areEqual(
      null,
      priorityGroupById.get(appId3),
      'App 3 should have null (no approved priority items)'
    );
  }

  @IsTest
  private static void processAggregateResults_selectsMinimumValue() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };
    List<PriorityGroupAggregateResult> wrappedResults = new List<PriorityGroupAggregateResult>{
      new PriorityGroupAggregateResult(appId1, 1.5)
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    IndividualApplication updatedApp = (IndividualApplication) updatedRecords[0];

    Assert.areEqual(
      1.5,
      updatedApp.Relationship_Priority_Group__c,
      'Should use the MIN value from aggregate result'
    );
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
    PriorityGroupRollupServiceImpl service = new PriorityGroupRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}