/**
 * Tests for {@link PriorityItemTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class PriorityItemTriggerHandlerTest {
  private static final PriorityItemTriggerHandler HANDLER;
  private static final SiblingApplyingRollupServiceMock SIBLING_SERVICE_MOCK;
  private static final PriorityGroupRollupServiceMock PRIORITY_GROUP_SERVICE_MOCK;
  private static final EmployeePriorityRollupServiceMock EMPLOYEE_PRIORITY_SERVICE_MOCK;

  static {
    SIBLING_SERVICE_MOCK = new SiblingApplyingRollupServiceMock();
    PRIORITY_GROUP_SERVICE_MOCK = new PriorityGroupRollupServiceMock();
    EMPLOYEE_PRIORITY_SERVICE_MOCK = new EmployeePriorityRollupServiceMock();
    HANDLER = new PriorityItemTriggerHandler(
      SIBLING_SERVICE_MOCK,
      PRIORITY_GROUP_SERVICE_MOCK,
      EMPLOYEE_PRIORITY_SERVICE_MOCK
    );
  }

  @IsTest
  private static void getSObjectType_returnsPriorityItem() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.Priority_Item__c.SObjectType, result);
  }

  @IsTest
  private static void onAfterInsert_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = appId)
    };

    HANDLER.onAfterInsert(records);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterInsert_withNullSiblingApp_doesNotCallService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = null)
    };

    HANDLER.onAfterInsert(records);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_whenRollupFieldsChange_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_PENDING
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterUpdate_whenPriorityTypeChangesOnly_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterUpdate_whenPriorityTypeDowngradesOnly_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterUpdate_whenRollupFieldsUnchanged_doesNotCallService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = appId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_whenReparented_callsServiceWithBothAppIds() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id oldAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id newAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = newAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = oldAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(oldAppId), 'Should include old app ID');
    Assert.isTrue(passedIds.contains(newAppId), 'Should include new app ID');
  }

  @IsTest
  private static void onAfterDelete_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> oldRecords = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = appId)
    };

    HANDLER.onAfterDelete(oldRecords);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterUndelete_callsRollupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = appId)
    };

    HANDLER.onAfterUndelete(records);

    SIBLING_SERVICE_MOCK.verify(SIBLING_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = SIBLING_SERVICE_MOCK.getCalls(
      SIBLING_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(appId), 'Should include the app ID');
  }

  @IsTest
  private static void onAfterInsert_withRelatedApp_callsPriorityGroupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id relatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = relatedAppId)
    };

    HANDLER.onAfterInsert(records);

    PRIORITY_GROUP_SERVICE_MOCK.verify(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = PRIORITY_GROUP_SERVICE_MOCK.getCalls(
      PRIORITY_GROUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(relatedAppId), 'Should include the related app ID');
  }

  @IsTest
  private static void onAfterInsert_withNullRelatedApp_doesNotCallPriorityGroupService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(Id = priorityItemId, Related_Application__c = null)
    };

    HANDLER.onAfterInsert(records);

    PRIORITY_GROUP_SERVICE_MOCK.verify(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_whenRelatedAppReparented_callsPriorityGroupServiceWithBothApps() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id oldRelatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id newRelatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = newRelatedAppId,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = oldRelatedAppId,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    PRIORITY_GROUP_SERVICE_MOCK.verify(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = PRIORITY_GROUP_SERVICE_MOCK.getCalls(
      PRIORITY_GROUP_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(oldRelatedAppId), 'Should include old related app ID');
    Assert.isTrue(passedIds.contains(newRelatedAppId), 'Should include new related app ID');
  }

  @IsTest
  private static void onAfterInsert_withNonZetaStaffType_doesNotCallEmployeePriorityService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    EMPLOYEE_PRIORITY_SERVICE_MOCK.when(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id relatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> records = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = relatedAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING
      )
    };

    HANDLER.onAfterInsert(records);

    EMPLOYEE_PRIORITY_SERVICE_MOCK.verify(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterUpdate_whenZetaStaffReviewStatusChanges_callsEmployeePriorityService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    EMPLOYEE_PRIORITY_SERVICE_MOCK.when(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id relatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = relatedAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_APPROVED
      )
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      priorityItemId => new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = relatedAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF,
        Review_Status__c = PriorityItemConstants.REVIEW_STATUS_PENDING
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    EMPLOYEE_PRIORITY_SERVICE_MOCK.verify(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate(), 1);
    List<Map<String, Object>> calls = EMPLOYEE_PRIORITY_SERVICE_MOCK.getCalls(
      EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate()
    );
    Set<Id> passedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(passedIds.contains(relatedAppId), 'Should include the related app ID');
  }

  @IsTest
  private static void onAfterDelete_withNonZetaStaffType_doesNotCallEmployeePriorityService() {
    SIBLING_SERVICE_MOCK.when(SIBLING_SERVICE_MOCK.method.recalculate()).thenReturnVoid();
    PRIORITY_GROUP_SERVICE_MOCK.when(PRIORITY_GROUP_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    EMPLOYEE_PRIORITY_SERVICE_MOCK.when(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate())
      .thenReturnVoid();
    Id priorityItemId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id relatedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> oldRecords = new List<SObject>{
      new Priority_Item__c(
        Id = priorityItemId,
        Related_Application__c = relatedAppId,
        Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      )
    };

    HANDLER.onAfterDelete(oldRecords);

    EMPLOYEE_PRIORITY_SERVICE_MOCK.verify(EMPLOYEE_PRIORITY_SERVICE_MOCK.method.recalculate(), 0);
  }
}