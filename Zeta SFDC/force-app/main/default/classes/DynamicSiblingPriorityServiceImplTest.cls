/**
 * Tests for {@link DynamicSiblingPriorityServiceImpl}.
 */
@IsTest(IsParallel=true)
private class DynamicSiblingPriorityServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final DynamicSiblingPriorityServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new DynamicSiblingPriorityServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void handleUpgrade_nullInput_noAction() {
    SERVICE.handleUpgrade(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleUpgrade_emptyInput_noAction() {
    SERVICE.handleUpgrade(new Set<Id>());

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleUpgrade_withApprovedSiblingApplying_updatesToSiblingAttending() {
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id relatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    Priority_Item__c mockPriorityItem = new Priority_Item__c(
      Id = priorityItemId,
      Sibling_Application__c = applicationId,
      Related_Application__c = relatedAppId,
      Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
      Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
    );

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>{ mockPriorityItem });
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleUpgrade(new Set<Id>{ applicationId });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should update one priority item');

    Priority_Item__c updated = (Priority_Item__c) updatedRecords[0];
    Assert.areEqual(priorityItemId, updated.Id, 'Should update correct record');
    Assert.areEqual(
      PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
      updated.Priority_Type__c,
      'Should upgrade to Sibling Attending'
    );
  }

  @IsTest
  private static void handleUpgrade_noPriorityItems_noUpdate() {
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<Priority_Item__c>());

    SERVICE.handleUpgrade(new Set<Id>{ applicationId });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleUpgrade_multipleApplications_updatesBulk() {
    Id app1Id = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id app2Id = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id priorityItem1Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id priorityItem2Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id priorityItem3Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    List<Priority_Item__c> mockPriorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = priorityItem1Id,
        Sibling_Application__c = app1Id,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING
      ),
      new Priority_Item__c(
        Id = priorityItem2Id,
        Sibling_Application__c = app1Id,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING
      ),
      new Priority_Item__c(
        Id = priorityItem3Id,
        Sibling_Application__c = app2Id,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(mockPriorityItems);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleUpgrade(new Set<Id>{ app1Id, app2Id });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(3, updatedRecords.size(), 'Should update all 3 records in single DML');

    for (SObject record : updatedRecords) {
      Priority_Item__c item = (Priority_Item__c) record;
      Assert.areEqual(
        PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
        item.Priority_Type__c,
        'Should upgrade all items to Sibling Attending'
      );
    }
  }

  @IsTest
  private static void handleUpgrade_queryUsesCorrectBindParameters() {
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<Priority_Item__c>());

    SERVICE.handleUpgrade(new Set<Id>{ applicationId });

    List<Map<String, Object>> queryCalls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    Assert.areEqual(1, queryCalls.size(), 'Should make one query call');

    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[0].get('bindMap');

    Set<Id> applicationIds = (Set<Id>) bindMap.get('applicationIds');
    Assert.isTrue(
      applicationIds.contains(applicationId),
      'Should include applicationIds in bind map'
    );

    String priorityType = (String) bindMap.get('priorityType');
    Assert.areEqual(
      PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
      priorityType,
      'Should bind priorityType to Sibling Applying'
    );

    String reviewStatus = (String) bindMap.get('reviewStatus');
    Assert.areEqual(
      PriorityItemConstants.REVIEW_STATUS_APPROVED,
      reviewStatus,
      'Should bind reviewStatus to Approved'
    );
  }

  @IsTest
  private static void handleDowngrade_nullInput_noAction() {
    SERVICE.handleDowngrade(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleDowngrade_emptyInput_noAction() {
    SERVICE.handleDowngrade(new Set<Id>());

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleDowngrade_noPriorityItems_noUpdate() {
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Set<Id> appIds = new Set<Id>{ siblingAppId };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<Priority_Item__c>());

    SERVICE.handleDowngrade(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleDowngrade_hasRemainingOffers_noUpdate() {
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Set<Id> appIds = new Set<Id>{ siblingAppId };

    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = priorityItemId,
        Sibling_Application__c = siblingAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    List<AcademicInterest> remainingOffers = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId,
        IndividualApplicationId = siblingAppId,
        Status = AcademicInterestConstants.STATUS_SEAT_OFFERED
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(priorityItems)
      .thenReturn(remainingOffers);

    SERVICE.handleDowngrade(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void handleDowngrade_noRemainingOffers_updatesToSiblingApplying() {
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Set<Id> appIds = new Set<Id>{ siblingAppId };

    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = priorityItemId,
        Sibling_Application__c = siblingAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    List<AcademicInterest> noOffers = new List<AcademicInterest>();

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(priorityItems)
      .thenReturn(noOffers);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleDowngrade(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should update one priority item');

    Priority_Item__c updated = (Priority_Item__c) updatedRecords[0];
    Assert.areEqual(priorityItemId, updated.Id, 'Should update correct record');
    Assert.areEqual(
      PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
      updated.Priority_Type__c,
      'Should downgrade to Sibling Applying'
    );
  }

  @IsTest
  private static void handleDowngrade_mixedScenario_updatesOnlyEligible() {
    Id siblingWithOffers = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingWithoutOffers = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id itemWithOffersId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id itemWithoutOffersId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    Set<Id> appIds = new Set<Id>{ siblingWithOffers, siblingWithoutOffers };

    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = itemWithOffersId,
        Sibling_Application__c = siblingWithOffers,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      ),
      new Priority_Item__c(
        Id = itemWithoutOffersId,
        Sibling_Application__c = siblingWithoutOffers,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    List<AcademicInterest> remainingOffers = new List<AcademicInterest>{
      new AcademicInterest(
        Id = interestId,
        IndividualApplicationId = siblingWithOffers,
        Status = AcademicInterestConstants.STATUS_PRE_OFFER
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(priorityItems)
      .thenReturn(remainingOffers);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleDowngrade(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should only update one priority item');

    Priority_Item__c updated = (Priority_Item__c) updatedRecords[0];
    Assert.areEqual(
      itemWithoutOffersId,
      updated.Id,
      'Should update only item for sibling without offers'
    );
    Assert.areEqual(
      PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
      updated.Priority_Type__c,
      'Should downgrade to Sibling Applying'
    );
  }

  @IsTest
  private static void handleDowngrade_multipleItemsSameSibling_updatesAll() {
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id itemId1 = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id itemId2 = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Set<Id> appIds = new Set<Id>{ siblingAppId };

    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = itemId1,
        Sibling_Application__c = siblingAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      ),
      new Priority_Item__c(
        Id = itemId2,
        Sibling_Application__c = siblingAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    List<AcademicInterest> noOffers = new List<AcademicInterest>();

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(priorityItems)
      .thenReturn(noOffers);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleDowngrade(appIds);

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(2, updatedRecords.size(), 'Should update both priority items');

    Set<Id> updatedIds = new Set<Id>();
    for (SObject record : updatedRecords) {
      Priority_Item__c item = (Priority_Item__c) record;
      updatedIds.add(item.Id);
      Assert.areEqual(
        PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        item.Priority_Type__c,
        'Should downgrade to Sibling Applying'
      );
    }

    Assert.isTrue(updatedIds.contains(itemId1), 'Should update first item');
    Assert.isTrue(updatedIds.contains(itemId2), 'Should update second item');
  }

  @IsTest
  private static void handleDowngrade_queryUsesCorrectBindParameters() {
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Set<Id> inputAppIds = new Set<Id>{ siblingAppId };

    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = priorityItemId,
        Sibling_Application__c = siblingAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(priorityItems)
      .thenReturn(new List<AcademicInterest>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleDowngrade(inputAppIds);

    List<Map<String, Object>> queryCalls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    Assert.areEqual(2, queryCalls.size(), 'Should make two query calls');

    Map<String, Object> firstQueryBinds = (Map<String, Object>) queryCalls[0].get('bindMap');
    Set<Id> firstQueryAppIds = (Set<Id>) firstQueryBinds.get('individualApplicationIds');
    Assert.isTrue(
      firstQueryAppIds.contains(siblingAppId),
      'First query should bind individualApplicationIds'
    );

    Map<String, Object> secondQueryBinds = (Map<String, Object>) queryCalls[1].get('bindMap');
    Set<Id> secondQueryAppIds = (Set<Id>) secondQueryBinds.get('siblingAppIds');
    Assert.isTrue(
      secondQueryAppIds.contains(siblingAppId),
      'Second query should bind siblingAppIds from Priority_Item records'
    );
  }

  @IsTest
  private static void handleUpgrade_withMixedReviewStatus_onlyUpdatesApproved() {
    Id app1Id = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id app2Id = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id approvedItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    List<Priority_Item__c> approvedOnly = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = approvedItemId,
        Sibling_Application__c = app1Id,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(approvedOnly);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.handleUpgrade(new Set<Id>{ app1Id, app2Id });

    MOCK_REPO.verify(MOCK_REPO.method.updateSObjects(), 1);

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    List<SObject> updatedRecords = (List<SObject>) updateCalls[0].get('sobjects');

    Assert.areEqual(1, updatedRecords.size(), 'Should only update Approved items');
    Assert.areEqual(
      approvedItemId,
      updatedRecords[0].Id,
      'Should only update the Approved Priority_Item'
    );
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    DynamicSiblingPriorityServiceImpl service = new DynamicSiblingPriorityServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }
}