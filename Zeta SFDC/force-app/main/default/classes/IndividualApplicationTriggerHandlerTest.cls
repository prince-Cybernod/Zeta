/**
 * Tests for {@link IndividualApplicationTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class IndividualApplicationTriggerHandlerTest {
  private static final IndividualApplicationTriggerHandler HANDLER;
  private static final CurrentPriorityCalcServiceMock SERVICE_MOCK;

  static {
    SERVICE_MOCK = new CurrentPriorityCalcServiceMock();
    HANDLER = new IndividualApplicationTriggerHandler(SERVICE_MOCK);
  }

  @IsTest
  private static void getSObjectType_returnsIndividualApplication() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.IndividualApplication.SObjectType, result);
  }

  @IsTest
  private static void onAfterUpdate_whenPriorityGroupChanges_callsService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new IndividualApplication(Id = applicationId, Relationship_Priority_Group__c = 1)
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      applicationId => new IndividualApplication(
        Id = applicationId,
        Relationship_Priority_Group__c = null
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.recalculateForApplications(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.recalculateForApplications()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.isTrue(capturedIds.contains(applicationId), 'Should include the application ID');
    Assert.areEqual(1, capturedIds.size(), 'Should have exactly one application ID');
  }

  @IsTest
  private static void onAfterUpdate_whenPriorityGroupChangesFromOneValueToAnother_callsService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new IndividualApplication(Id = applicationId, Relationship_Priority_Group__c = 2)
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      applicationId => new IndividualApplication(
        Id = applicationId,
        Relationship_Priority_Group__c = 1
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.recalculateForApplications(), 1);
  }

  @IsTest
  private static void onAfterUpdate_whenNoRelevantFieldsChange_doesNotCallService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new IndividualApplication(Id = applicationId, Relationship_Priority_Group__c = 1)
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      applicationId => new IndividualApplication(
        Id = applicationId,
        Relationship_Priority_Group__c = 1
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.recalculateForApplications(), 0);
  }

  @IsTest
  private static void onAfterUpdate_withMultipleApplicationsAndMixedChanges_callsServiceWithOnlyChangedRecords() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    Id applicationId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id applicationId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id applicationId3 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new IndividualApplication(Id = applicationId1, Relationship_Priority_Group__c = 1),
      new IndividualApplication(Id = applicationId2, Relationship_Priority_Group__c = 2),
      new IndividualApplication(Id = applicationId3, Relationship_Priority_Group__c = null)
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      applicationId1 => new IndividualApplication(
        Id = applicationId1,
        Relationship_Priority_Group__c = 1
      ),
      applicationId2 => new IndividualApplication(
        Id = applicationId2,
        Relationship_Priority_Group__c = null
      ),
      applicationId3 => new IndividualApplication(
        Id = applicationId3,
        Relationship_Priority_Group__c = 1
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.recalculateForApplications(), 1);
    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.recalculateForApplications()
    );
    Set<Id> capturedIds = (Set<Id>) calls[0].get('individualApplicationIds');
    Assert.areEqual(2, capturedIds.size(), 'Should have two application IDs (changed ones only)');
    Assert.isTrue(capturedIds.contains(applicationId2), 'Should include app 2');
    Assert.isTrue(capturedIds.contains(applicationId3), 'Should include app 3');
    Assert.isFalse(capturedIds.contains(applicationId1), 'Should not include app 1 (unchanged)');
  }

  @IsTest
  private static void onAfterUpdate_whenAllRecordsUnchanged_doesNotCallService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    Id applicationId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id applicationId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<SObject> newRecords = new List<SObject>{
      new IndividualApplication(Id = applicationId1, Relationship_Priority_Group__c = 1),
      new IndividualApplication(Id = applicationId2, Relationship_Priority_Group__c = 2)
    };
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      applicationId1 => new IndividualApplication(
        Id = applicationId1,
        Relationship_Priority_Group__c = 1
      ),
      applicationId2 => new IndividualApplication(
        Id = applicationId2,
        Relationship_Priority_Group__c = 2
      )
    };

    HANDLER.onAfterUpdate(newRecords, oldMap);

    SERVICE_MOCK.verify(SERVICE_MOCK.method.recalculateForApplications(), 0);
  }
}