/**
 * Tests for {@link IndividualApplicationTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class IndividualApplicationTriggerHandlerTest {
  private static final IndividualApplicationTriggerHandler HANDLER;
  private static final CurrentPriorityCalcServiceMock SERVICE_MOCK;
  private static final ApplicationCountRollupServiceMock ROLLUP_MOCK;

  static {
    SERVICE_MOCK = new CurrentPriorityCalcServiceMock();
    ROLLUP_MOCK = new ApplicationCountRollupServiceMock();
    HANDLER = new IndividualApplicationTriggerHandler(SERVICE_MOCK, ROLLUP_MOCK);
  }

  private static IndividualApplication buildApplication(
    Id applicationId,
    Id studentId,
    Id primaryGuardianId,
    Id secondaryGuardianId
  ) {
    return new IndividualApplication(
      Id = applicationId,
      AccountId = studentId,
      Primary_Guardian__c = primaryGuardianId,
      Secondary_Guardian__c = secondaryGuardianId
    );
  }

  private static Id fakeAccountId() {
    return SObjectIds.generateFakeId(Schema.Account.SObjectType);
  }

  private static Set<Id> capturedRollupIds() {
    List<Map<String, Object>> calls = ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate());
    return (Set<Id>) calls[0].get('accountIds');
  }

  @IsTest
  private static void getSObjectType_returnsIndividualApplication() {
    SObjectType result = HANDLER.getSObjectType();

    Assert.areEqual(Schema.IndividualApplication.SObjectType, result);
  }

  @IsTest
  private static void onAfterUpdate_whenPriorityGroupChanges_callsService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
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
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
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
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
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
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
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
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
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

  @IsTest
  private static void onAfterInsert_collectsStudentAndBothGuardians() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id studentId = fakeAccountId();
    Id primaryGuardianId = fakeAccountId();
    Id secondaryGuardianId = fakeAccountId();

    HANDLER.onAfterInsert(
      new List<SObject>{
        buildApplication(
          SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
          studentId,
          primaryGuardianId,
          secondaryGuardianId
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = capturedRollupIds();
    Assert.areEqual(3, capturedIds.size(), 'One application should touch three Accounts');
    Assert.isTrue(capturedIds.contains(studentId), 'Should include the student');
    Assert.isTrue(capturedIds.contains(primaryGuardianId), 'Should include the primary guardian');
    Assert.isTrue(
      capturedIds.contains(secondaryGuardianId),
      'Should include the secondary guardian'
    );
  }

  @IsTest
  private static void onAfterInsert_withNoAccountLookups_doesNotCallService() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterInsert(
      new List<SObject>{
        new IndividualApplication(
          Id = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType)
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void onAfterDelete_collectsAccountsFromDeletedRecords() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id studentId = fakeAccountId();
    Id primaryGuardianId = fakeAccountId();

    HANDLER.onAfterDelete(
      new List<SObject>{
        buildApplication(
          SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
          studentId,
          primaryGuardianId,
          null
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = capturedRollupIds();
    Assert.areEqual(2, capturedIds.size(), 'Should collect the two populated lookups');
    Assert.isTrue(capturedIds.contains(studentId), 'Should include the student');
    Assert.isTrue(capturedIds.contains(primaryGuardianId), 'Should include the primary guardian');
  }

  @IsTest
  private static void onAfterUndelete_collectsAccountsFromRestoredRecords() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id studentId = fakeAccountId();

    HANDLER.onAfterUndelete(
      new List<SObject>{
        buildApplication(
          SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
          studentId,
          null,
          null
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Assert.isTrue(capturedRollupIds().contains(studentId), 'Should include the student');
  }

  @IsTest
  private static void onAfterUpdate_whenStudentRepointed_collectsBothOldAndNewAccounts() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id oldStudentId = fakeAccountId();
    Id newStudentId = fakeAccountId();
    Id guardianId = fakeAccountId();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildApplication(applicationId, newStudentId, guardianId, null) },
      new Map<Id, SObject>{
        applicationId => buildApplication(applicationId, oldStudentId, guardianId, null)
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = capturedRollupIds();
    Assert.isTrue(capturedIds.contains(oldStudentId), 'Should refresh the student left behind');
    Assert.isTrue(capturedIds.contains(newStudentId), 'Should refresh the newly linked student');
    Assert.isTrue(capturedIds.contains(guardianId), 'Should refresh the unchanged guardian');
  }

  @IsTest
  private static void onAfterUpdate_whenGuardianCleared_collectsTheClearedAccount() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id secondaryGuardianId = fakeAccountId();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildApplication(applicationId, null, null, null) },
      new Map<Id, SObject>{
        applicationId => buildApplication(applicationId, null, null, secondaryGuardianId)
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Assert.isTrue(
      capturedRollupIds().contains(secondaryGuardianId),
      'Should refresh the guardian that was removed'
    );
  }

  @IsTest
  private static void onAfterUpdate_whenNoAccountLookupChanges_doesNotCallRollupService() {
    SERVICE_MOCK.when(SERVICE_MOCK.method.recalculateForApplications()).thenReturnVoid();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentId = fakeAccountId();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildApplication(applicationId, studentId, null, null) },
      new Map<Id, SObject>{
        applicationId => buildApplication(applicationId, studentId, null, null)
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 0);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    IndividualApplicationTriggerHandler handler = new IndividualApplicationTriggerHandler();

    Assert.areEqual(Schema.IndividualApplication.SObjectType, handler.getSObjectType());
  }
}