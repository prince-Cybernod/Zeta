/**
 * Tests for {@link EmployeePriorityRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class EmployeePriorityRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final EmployeePriorityRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new EmployeePriorityRollupServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void processResults_withApprovedEmployeePriority_calculatesCorrectCount() {
    Id programId1 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> programIds = new Set<Id>{ programId1 };

    Map<Id, Set<Id>> applicationIdsByProgramId = new Map<Id, Set<Id>>{
      programId1 => new Set<Id>{ appId1, appId2 }
    };

    Map<Id, Integer> countsByApplicationId = new Map<Id, Integer>{ appId1 => 2, appId2 => 1 };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processResults(programIds, applicationIdsByProgramId, countsByApplicationId);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    LearningProgram updatedProgram = (LearningProgram) updatedRecords[0];
    Assert.areEqual(programId1, updatedProgram.Id, 'Should update the correct program');
    Assert.areEqual(
      3,
      updatedProgram.Count_Lottery_Employee_Priority__c,
      'Should set count to sum of app counts (2 + 1 = 3)'
    );
  }

  @IsTest
  private static void processResults_withNoMatchingRecords_setsCountToZero() {
    Id programId1 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Set<Id> programIds = new Set<Id>{ programId1 };

    Map<Id, Set<Id>> applicationIdsByProgramId = new Map<Id, Set<Id>>{
      programId1 => new Set<Id>()
    };

    Map<Id, Integer> emptyCountsMap = new Map<Id, Integer>();

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processResults(programIds, applicationIdsByProgramId, emptyCountsMap);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one record');

    LearningProgram updatedProgram = (LearningProgram) updatedRecords[0];
    Assert.areEqual(programId1, updatedProgram.Id, 'Should update the correct program');
    Assert.areEqual(
      0,
      updatedProgram.Count_Lottery_Employee_Priority__c,
      'Should set count to 0 when no matches'
    );
  }

  @IsTest
  private static void processResults_withMultiplePrograms_updatesAllRecords() {
    Id programId1 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id programId2 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> programIds = new Set<Id>{ programId1, programId2 };

    Map<Id, Set<Id>> applicationIdsByProgramId = new Map<Id, Set<Id>>{
      programId1 => new Set<Id>{ appId1 },
      programId2 => new Set<Id>{ appId2 }
    };

    Map<Id, Integer> countsByApplicationId = new Map<Id, Integer>{ appId1 => 4, appId2 => 2 };

    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processResults(programIds, applicationIdsByProgramId, countsByApplicationId);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update records once');

    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, updatedRecords.size(), 'Should update both programs');

    Map<Id, Decimal> countsById = new Map<Id, Decimal>();
    for (SObject record : updatedRecords) {
      LearningProgram program = (LearningProgram) record;
      countsById.put(program.Id, program.Count_Lottery_Employee_Priority__c);
    }

    Assert.areEqual(4, countsById.get(programId1), 'Program 1 should have count of 4');
    Assert.areEqual(2, countsById.get(programId2), 'Program 2 should have count of 2');
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

    // First query returns empty (no programs found), so service returns early
    List<AcademicInterest> mockAcademicInterests = new List<AcademicInterest>();

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockAcademicInterests);

    SERVICE.recalculate(appIds);

    // Should query once to find programs, then return early since none found
    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withProgramsFound_calculatesAndUpdates() {
    Id programId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<AcademicInterest> firstQueryResult = new List<AcademicInterest>{
      buildAcademicInterest(programId, appId1),
      buildAcademicInterest(programId, appId2)
    };

    List<AcademicInterest> secondQueryResult = new List<AcademicInterest>{
      buildAcademicInterest(programId, appId1),
      buildAcademicInterest(programId, appId2)
    };

    EmployeePriorityAggregateResult.isReturningFakeData = true;
    Map<String, Object> aggMap = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'AggregateResult' }
    };
    AggregateResult fakeAgg = (AggregateResult) JSON.deserialize(
      JSON.serialize(aggMap),
      AggregateResult.class
    );
    List<AggregateResult> thirdQueryResult = new List<AggregateResult>{ fakeAgg };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(firstQueryResult)
      .thenReturn(secondQueryResult)
      .thenReturn(thirdQueryResult);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ appId1 });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 3);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one program');

    LearningProgram updatedProgram = (LearningProgram) updatedRecords[0];
    Assert.areEqual(programId, updatedProgram.Id, 'Should update the correct program');
  }

  @IsTest
  private static void recalculate_withProgramsButNoPriorityItems_setsCountsToZero() {
    Id programId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<AcademicInterest> firstQueryResult = new List<AcademicInterest>{
      buildAcademicInterest(programId, appId1)
    };

    List<AcademicInterest> secondQueryResult = new List<AcademicInterest>{
      buildAcademicInterest(programId, appId1)
    };

    List<AggregateResult> emptyAggregateResults = new List<AggregateResult>();

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(firstQueryResult)
      .thenReturn(secondQueryResult)
      .thenReturn(emptyAggregateResults);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ appId1 });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 3);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updatedRecords.size(), 'Should update one program');

    LearningProgram updatedProgram = (LearningProgram) updatedRecords[0];
    Assert.areEqual(programId, updatedProgram.Id, 'Should update the correct program');
    Assert.areEqual(
      0,
      updatedProgram.Count_Lottery_Employee_Priority__c,
      'Should set count to 0 when no approved priority items'
    );
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    EmployeePriorityRollupServiceImpl service = new EmployeePriorityRollupServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }

  private static AcademicInterest buildAcademicInterest(Id programId, Id applicationId) {
    String jsonStr = JSON.serialize(
      new Map<String, Object>{
        'attributes' => new Map<String, Object>{ 'type' => 'AcademicInterest' },
        'IndividualApplicationId' => applicationId,
        'Lottery_Capacity__r' => new Map<String, Object>{
          'attributes' => new Map<String, Object>{ 'type' => 'Lottery_Capacity__c' },
          'Program_Term_Application_Timeline__r' => new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'hed__Term__c' },
            'LearningProgramId' => programId
          }
        }
      }
    );
    return (AcademicInterest) JSON.deserialize(jsonStr, AcademicInterest.class);
  }
}