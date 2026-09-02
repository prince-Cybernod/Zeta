/**
 * Tests for {@link CurrentPriorityCalcServiceImpl}.
 */
@IsTest(IsParallel=true)
private class CurrentPriorityCalcServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final CurrentPriorityCalcServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new CurrentPriorityCalcServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void calculateForRecords_nullList_handlesGracefully() {
    SERVICE.calculateForRecords(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void calculateForRecords_emptyList_handlesGracefully() {
    List<AcademicInterest> emptyList = new List<AcademicInterest>();

    SERVICE.calculateForRecords(emptyList);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void calculateForRecords_noParentApplication_setsToGeneral() {
    List<AcademicInterest> academicInterests = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = null, In_District_Priority__c = false)
    };

    SERVICE.calculateForRecords(academicInterests);

    Assert.areEqual(
      4,
      academicInterests[0].Current_Priority_Group__c,
      'Should set to general priority when no parent application'
    );
    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void calculateForRecords_withParentPriority1_setsTo1() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<AcademicInterest> academicInterests = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = appId, In_District_Priority__c = false)
    };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 1.0
    );

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp });

    SERVICE.calculateForRecords(academicInterests);

    Assert.areEqual(
      1,
      academicInterests[0].Current_Priority_Group__c,
      'Should set to priority group 1 from parent application'
    );
  }

  @IsTest
  private static void calculateForRecords_multipleRecords_stampsAll() {
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<AcademicInterest> academicInterests = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = appId1, In_District_Priority__c = false),
      new AcademicInterest(IndividualApplicationId = appId2, In_District_Priority__c = true),
      new AcademicInterest(IndividualApplicationId = appId1, In_District_Priority__c = true)
    };

    List<IndividualApplication> parentApps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId1, Relationship_Priority_Group__c = 1.0),
      new IndividualApplication(Id = appId2, Relationship_Priority_Group__c = null)
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(parentApps);

    SERVICE.calculateForRecords(academicInterests);

    Assert.areEqual(
      1,
      academicInterests[0].Current_Priority_Group__c,
      'First interest should have priority 1'
    );
    Assert.areEqual(
      3,
      academicInterests[1].Current_Priority_Group__c,
      'Second interest should have priority 3 (in-district)'
    );
    Assert.areEqual(
      1,
      academicInterests[2].Current_Priority_Group__c,
      'Third interest should have priority 1 (parent priority beats in-district)'
    );
  }

  @IsTest
  private static void recalculateForApplications_nullSet_handlesGracefully() {
    SERVICE.recalculateForApplications(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculateForApplications_emptySet_handlesGracefully() {
    Set<Id> emptySet = new Set<Id>();

    SERVICE.recalculateForApplications(emptySet);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculateForApplications_updatesChildRecords() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id interestId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 2.0
    );

    // Original priority is set (lottery has run) and differs from new priority
    List<AcademicInterest> childInterests = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId1,
        IndividualApplicationId = appId,
        In_District_Priority__c = false,
        Current_Priority_Group__c = 4,
        Original_Priority_Group__c = 4
      ),
      new AcademicInterest(
        Id = interestId2,
        IndividualApplicationId = appId,
        In_District_Priority__c = true,
        Current_Priority_Group__c = 3,
        Original_Priority_Group__c = 3
      )
    };

    MOCK_REPO.reset();
    MOCK_REPO
      .when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp })
      .thenReturn(childInterests);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculateForApplications(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(2, updatedRecords.size(), 'Should update both child records');

    Map<Id, Integer> priorityById = new Map<Id, Integer>();
    for (SObject record : updatedRecords) {
      AcademicInterest interest = (AcademicInterest) record;
      priorityById.put(interest.Id, (Integer) interest.Current_Priority_Group__c);
    }

    Assert.areEqual(
      2,
      priorityById.get(interestId1),
      'First interest should be updated to priority 2'
    );
    Assert.areEqual(
      2,
      priorityById.get(interestId2),
      'Second interest should be updated to priority 2'
    );

    for (SObject record : updatedRecords) {
      AcademicInterest interest = (AcademicInterest) record;
      Assert.isNotNull(
        interest.Date_of_Current_Priority_Change__c,
        'Date should be stamped when Original != null and Original != new priority'
      );
    }
  }

  @IsTest
  private static void recalculateForApplications_originalPriorityNull_doesNotStampDate() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 1.0
    );

    // Original priority is null (lottery has NOT run yet)
    List<AcademicInterest> childInterests = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId,
        IndividualApplicationId = appId,
        In_District_Priority__c = false,
        Current_Priority_Group__c = 4,
        Original_Priority_Group__c = null
      )
    };

    MOCK_REPO.reset();
    MOCK_REPO
      .when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp })
      .thenReturn(childInterests);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculateForApplications(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    AcademicInterest updated = (AcademicInterest) updatedRecords[0];
    Assert.areEqual(1, updated.Current_Priority_Group__c, 'Priority should be updated to 1');
    Assert.isNull(
      updated.Date_of_Current_Priority_Change__c,
      'Date should NOT be stamped when Original_Priority_Group__c is null (pre-lottery)'
    );
  }

  @IsTest
  private static void recalculateForApplications_originalEqualsNewPriority_doesNotStampDate() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 1.0
    );

    // Original priority equals the NEW priority (no actual change from original)
    List<AcademicInterest> childInterests = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId,
        IndividualApplicationId = appId,
        In_District_Priority__c = false,
        Current_Priority_Group__c = 4,
        Original_Priority_Group__c = 1
      )
    };

    MOCK_REPO.reset();
    MOCK_REPO
      .when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp })
      .thenReturn(childInterests);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculateForApplications(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    AcademicInterest updated = (AcademicInterest) updatedRecords[0];
    Assert.areEqual(1, updated.Current_Priority_Group__c, 'Priority should be updated to 1');
    Assert.isNull(
      updated.Date_of_Current_Priority_Change__c,
      'Date should NOT be stamped when new priority equals original (no actual change from lottery)'
    );
  }

  @IsTest
  private static void recalculateForApplications_noChangeNeeded_skipsUpdate() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 2.0
    );

    List<AcademicInterest> childInterests = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId,
        IndividualApplicationId = appId,
        In_District_Priority__c = false,
        Current_Priority_Group__c = 2
      )
    };

    MOCK_REPO.reset();
    MOCK_REPO
      .when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp })
      .thenReturn(childInterests);

    SERVICE.recalculateForApplications(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculateForApplications_noChildren_noUpdate() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ appId };

    IndividualApplication parentApp = new IndividualApplication(
      Id = appId,
      Relationship_Priority_Group__c = 2.0
    );

    List<AcademicInterest> emptyChildren = new List<AcademicInterest>();

    MOCK_REPO.reset();
    MOCK_REPO
      .when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ parentApp })
      .thenReturn(emptyChildren);

    SERVICE.recalculateForApplications(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    CurrentPriorityCalcServiceImpl service = new CurrentPriorityCalcServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}