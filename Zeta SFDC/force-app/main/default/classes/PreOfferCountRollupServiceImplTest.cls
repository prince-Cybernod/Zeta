/**
 * Tests for {@link PreOfferCountRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class PreOfferCountRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final PreOfferCountRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new PreOfferCountRollupServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void processAggregateResults_withPreOfferRecords_updatesParentAndChildren() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PreOfferCountAggregateResult> wrappedResults = new List<PreOfferCountAggregateResult>{
      new PreOfferCountAggregateResult(appId1, 3)
    };

    Id childId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id childId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> mockChildren = new List<AcademicInterest>{
      new AcademicInterest(
        Id = childId1,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 0
      ),
      new AcademicInterest(
        Id = childId2,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 0
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(2, updateCalls.size(), 'Should update parent and children separately');

    List<SObject> parentUpdates = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, parentUpdates.size(), 'Should update one parent');
    IndividualApplication updatedApp = (IndividualApplication) parentUpdates[0];
    Assert.areEqual(
      3,
      updatedApp.Count_of_Pre_Offer_School_Applications__c,
      'Parent should have count 3'
    );

    List<SObject> childUpdates = (List<SObject>) updateCalls[1].get('sobjects');
    Assert.areEqual(2, childUpdates.size(), 'Should update both children');
    for (SObject record : childUpdates) {
      AcademicInterest child = (AcademicInterest) record;
      Assert.areEqual(
        3,
        child.Count_of_Pre_Offer_School_Applications__c,
        'Child should have count 3'
      );
    }
  }

  @IsTest
  private static void processAggregateResults_withNoMatchingRecords_setsCountToZero() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PreOfferCountAggregateResult> emptyResults = new List<PreOfferCountAggregateResult>();

    Id childId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> mockChildren = new List<AcademicInterest>{
      new AcademicInterest(
        Id = childId1,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 5
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);

    SERVICE.processAggregateResults(appIds, emptyResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(2, updateCalls.size(), 'Should update parent and children');

    List<SObject> parentUpdates = (List<SObject>) updateCalls[0].get('sobjects');
    IndividualApplication updatedApp = (IndividualApplication) parentUpdates[0];
    Assert.areEqual(
      0,
      updatedApp.Count_of_Pre_Offer_School_Applications__c,
      'Parent should have count 0 when no matches'
    );

    List<SObject> childUpdates = (List<SObject>) updateCalls[1].get('sobjects');
    AcademicInterest updatedChild = (AcademicInterest) childUpdates[0];
    Assert.areEqual(
      0,
      updatedChild.Count_of_Pre_Offer_School_Applications__c,
      'Child should have count 0 when no matches'
    );
  }

  @IsTest
  private static void processAggregateResults_withMultipleApplications_updatesAllRecords() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1, appId2 };

    List<PreOfferCountAggregateResult> wrappedResults = new List<PreOfferCountAggregateResult>{
      new PreOfferCountAggregateResult(appId1, 2),
      new PreOfferCountAggregateResult(appId2, 4)
    };

    Id childId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id childId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> mockChildren = new List<AcademicInterest>{
      new AcademicInterest(
        Id = childId1,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 0
      ),
      new AcademicInterest(
        Id = childId2,
        IndividualApplicationId = appId2,
        Count_of_Pre_Offer_School_Applications__c = 0
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(2, updateCalls.size(), 'Should update parent and children');

    List<SObject> parentUpdates = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, parentUpdates.size(), 'Should update both parents');

    Map<Id, Decimal> parentCountsById = new Map<Id, Decimal>();
    for (SObject record : parentUpdates) {
      IndividualApplication app = (IndividualApplication) record;
      parentCountsById.put(app.Id, app.Count_of_Pre_Offer_School_Applications__c);
    }
    Assert.areEqual(2, parentCountsById.get(appId1), 'App 1 should have count of 2');
    Assert.areEqual(4, parentCountsById.get(appId2), 'App 2 should have count of 4');
  }

  @IsTest
  private static void processAggregateResults_skipsChildrenWithUnchangedCount() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PreOfferCountAggregateResult> wrappedResults = new List<PreOfferCountAggregateResult>{
      new PreOfferCountAggregateResult(appId1, 3)
    };

    Id childId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> mockChildren = new List<AcademicInterest>{
      new AcademicInterest(
        Id = childId1,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 3
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should only update parent when children unchanged');
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
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<AggregateResult> mockAggregateResults = new List<AggregateResult>();
    List<AcademicInterest> mockChildren = new List<AcademicInterest>();

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockAggregateResults);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    PreOfferCountRollupServiceImpl service = new PreOfferCountRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }

  @IsTest
  private static void processAggregateResults_skipsRecordsBeingProcessed() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId1 };

    List<PreOfferCountAggregateResult> wrappedResults = new List<PreOfferCountAggregateResult>{
      new PreOfferCountAggregateResult(appId1, 3)
    };

    Id childId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id childId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> mockChildren = new List<AcademicInterest>{
      new AcademicInterest(
        Id = childId1,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 0
      ),
      new AcademicInterest(
        Id = childId2,
        IndividualApplicationId = appId1,
        Count_of_Pre_Offer_School_Applications__c = 0
      )
    };

    // Register childId1 as being processed (simulating trigger context)
    PreOfferCountRollupServiceImpl.registerProcessingRecords(new Set<Id>{ childId1 });

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockChildren);

    SERVICE.processAggregateResults(appIds, wrappedResults);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(2, updateCalls.size(), 'Should update parent and children');

    // Second call should only have childId2 since childId1 is being processed
    List<SObject> childUpdates = (List<SObject>) updateCalls[1].get('sobjects');
    Assert.areEqual(
      1,
      childUpdates.size(),
      'Should only update one child (other is being processed)'
    );
    Assert.areEqual(childId2, childUpdates[0].Id, 'Should update childId2 only');

    // Clean up
    PreOfferCountRollupServiceImpl.clearProcessingRecords();
  }
}