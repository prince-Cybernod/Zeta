/**
 * Tests for {@link SchoolRankValidationServiceImpl}.
 * Tests the AFTER trigger validation with FOR UPDATE locking.
 */
@IsTest(IsParallel=true)
private class SchoolRankValidationServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final SchoolRankValidationServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new SchoolRankValidationServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void validateUniqueRanks_withNullList_doesNotQuery() {
    SERVICE.validateUniqueRanks(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void validateUniqueRanks_withEmptyList_doesNotQuery() {
    List<AcademicInterest> emptyList = new List<AcademicInterest>();

    SERVICE.validateUniqueRanks(emptyList);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void validateUniqueRanks_withNullRanks_doesNotQuery() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = appId, School_Rank__c = null)
    };

    SERVICE.validateUniqueRanks(records);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void validateUniqueRanks_withNullApplication_doesNotQuery() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = null, School_Rank__c = 1)
    };

    SERVICE.validateUniqueRanks(records);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void validateUniqueRanks_queriesWithForUpdate() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId, IndividualApplicationId = appId, School_Rank__c = 1)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<AcademicInterest>());

    SERVICE.validateUniqueRanks(records);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);

    // Verify query uses FOR UPDATE for row locking
    // Note: Salesforce doesn't allow ORDER BY with FOR UPDATE queries
    List<Map<String, Object>> queryCalls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    String query = (String) queryCalls[0].get('query');
    Assert.isTrue(query.contains('FOR UPDATE'), 'Query should include FOR UPDATE for row locking');
  }

  @IsTest
  private static void validateUniqueRanks_queriesAllApplications() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId1, School_Rank__c = 1),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId2, School_Rank__c = 1)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<AcademicInterest>());

    SERVICE.validateUniqueRanks(records);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds());

    List<Map<String, Object>> queryCalls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');
    Set<Id> queriedAppIds = (Set<Id>) bindMap.get('applicationIds');
    Assert.areEqual(2, queriedAppIds.size(), 'Should query for both application IDs');
    Assert.isTrue(queriedAppIds.contains(appId1), 'Should include first application ID');
    Assert.isTrue(queriedAppIds.contains(appId2), 'Should include second application ID');
  }

  @IsTest
  private static void validateUniqueRanks_noDuplicates_noError() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> triggerRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 1),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 2)
    };

    // Query returns both records with different ranks - no duplicates
    List<AcademicInterest> queryResults = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 1),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 2)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(queryResults);

    SERVICE.validateUniqueRanks(triggerRecords);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
  }

  @IsTest
  private static void validateUniqueRanks_sameRankDifferentApps_noError() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Both have rank 1, but for different applications - should be allowed
    List<AcademicInterest> triggerRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId1, School_Rank__c = 1),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId2, School_Rank__c = 1)
    };

    // Query returns both, each grouped by their own app
    List<AcademicInterest> queryResults = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId1, School_Rank__c = 1),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId2, School_Rank__c = 1)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(queryResults);

    SERVICE.validateUniqueRanks(triggerRecords);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
  }

  @IsTest
  private static void validateUniqueRanks_swapTwoRecords_noError() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> triggerRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 2),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 1)
    };

    List<AcademicInterest> queryResults = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 2),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 1)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(queryResults);

    SERVICE.validateUniqueRanks(triggerRecords);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
  }

  @IsTest
  private static void validateUniqueRanks_tripleRotation_noError() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId3 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> triggerRecords = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 2),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 3),
      new AcademicInterest(Id = recordId3, IndividualApplicationId = appId, School_Rank__c = 1)
    };

    List<AcademicInterest> queryResults = new List<AcademicInterest>{
      new AcademicInterest(Id = recordId1, IndividualApplicationId = appId, School_Rank__c = 2),
      new AcademicInterest(Id = recordId2, IndividualApplicationId = appId, School_Rank__c = 3),
      new AcademicInterest(Id = recordId3, IndividualApplicationId = appId, School_Rank__c = 1)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(queryResults);

    SERVICE.validateUniqueRanks(triggerRecords);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    SchoolRankValidationServiceImpl service = new SchoolRankValidationServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}