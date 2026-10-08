/**
 * Tests for {@link ActiveEnrollmentsRollupBatch}.
 */
@IsTest(IsParallel=true)
private class ActiveEnrollmentsRollupBatchTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ActiveEnrollmentsRollupServiceMock ROLLUP_MOCK;
  private static final ActiveEnrollmentsRollupBatch BATCH;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    ROLLUP_MOCK = new ActiveEnrollmentsRollupServiceMock();
    BATCH = new ActiveEnrollmentsRollupBatch(MOCK_REPO, ROLLUP_MOCK);
  }

  @IsTest
  private static void getEnrollmentRecordTypeIds_returnsGuardianAndStudent() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

    Set<Id> recordTypeIds = ActiveEnrollmentsRollupBatch.getEnrollmentRecordTypeIds();

    Assert.areEqual(2, recordTypeIds.size(), 'Should resolve both enrollment record types');
    Assert.isTrue(
      recordTypeIds.contains(recordTypeInfos.get('Guardian').getRecordTypeId()),
      'Should include Guardian'
    );
    Assert.isTrue(
      recordTypeIds.contains(recordTypeInfos.get('Student').getRecordTypeId()),
      'Should include Student'
    );
  }

  @IsTest
  private static void start_scopesTheQueryToEnrollmentRecordTypes() {
    MOCK_REPO.when(MOCK_REPO.method.getQueryLocatorWithBinds())
      .thenReturn(Database.getQueryLocator('SELECT Id FROM Account LIMIT 1'));

    BATCH.start(null);

    MOCK_REPO.verify(MOCK_REPO.method.getQueryLocatorWithBinds(), 1);
    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.getQueryLocatorWithBinds())[0];
    Assert.isTrue(
      ((String) call.get('query')).contains('RecordTypeId IN :recordTypeIds'),
      'Should filter on record type'
    );

    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(
      2,
      ((Set<Id>) bindMap.get('recordTypeIds')).size(),
      'Should bind both enrollment record types'
    );
  }

  @IsTest
  private static void execute_delegatesScopeIdsToTheService() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    Id accountId1 = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accountId2 = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    BATCH.execute(
      null,
      new List<SObject>{ new Account(Id = accountId1), new Account(Id = accountId2) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = (Set<Id>) ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate())[0]
      .get('accountIds');
    Assert.areEqual(2, capturedIds.size(), 'Should pass both Account IDs');
    Assert.isTrue(capturedIds.contains(accountId1), 'Should include the first Account');
    Assert.isTrue(capturedIds.contains(accountId2), 'Should include the second Account');
  }

  @IsTest
  private static void finish_doesNotThrow() {
    BATCH.finish(null);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    Assert.isNotNull(new ActiveEnrollmentsRollupBatch(), 'Should create with default constructor');
  }

  // Active__c needs a term whose dates cover today, checked by the
  // precondition assertion below.
  @IsTest
  private static void execute_afterGuardianRepointedOnLearnerAccount_movesCountToNewGuardian() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    Id guardianRecordTypeId = recordTypeInfos.get('Guardian').getRecordTypeId();
    Id studentRecordTypeId = recordTypeInfos.get('Student').getRecordTypeId();

    Account oldGuardian = new Account(
      LastName = 'OldGuardian',
      RecordTypeId = guardianRecordTypeId,
      PersonEmail = 'oldguardian@example.invalid',
      PersonMobilePhone = '5555550100'
    );
    Account newGuardian = new Account(
      LastName = 'NewGuardian',
      RecordTypeId = guardianRecordTypeId,
      PersonEmail = 'newguardian@example.invalid',
      PersonMobilePhone = '5555550101'
    );
    insert as user new List<Account>{ oldGuardian, newGuardian };

    // The org's Student after-save flow links each guardian through these roles
    // and fails the insert when it can't find them.
    insert as user new List<PartyRoleRelation>{
      new PartyRoleRelation(
        Name = 'Guardian-Student-CCR',
        RoleName = 'Guardian',
        RelatedRoleName = 'Student',
        RelationshipObjectName = 'Contact_Contact_Relationship'
      ),
      new PartyRoleRelation(
        Name = 'Student-Guardian-CCR',
        RoleName = 'Student',
        RelatedRoleName = 'Guardian',
        RelationshipObjectName = 'Contact_Contact_Relationship'
      )
    };

    Account learner = new Account(
      LastName = 'Learner',
      RecordTypeId = studentRecordTypeId,
      PersonBirthdate = Date.today().addYears(-10),
      Primary_Guardian__c = oldGuardian.Id
    );
    insert as user learner;
    Id learnerContactId = [SELECT PersonContactId FROM Account WHERE Id = :learner.Id].PersonContactId;

    AcademicTerm currentTerm = new AcademicTerm(
      Name = 'Current Term',
      StartDate = Datetime.now().addDays(-30),
      EndDate = Datetime.now().addDays(30)
    );
    insert as user currentTerm;

    insert as user new AcademicTermEnrollment(
      AcademicTermId = currentTerm.Id,
      LearnerAccountId = learner.Id,
      LearnerContactId = learnerContactId
    );

    Decimal baselineCount = [
      SELECT Active_Enrollments__c
      FROM Account
      WHERE Id = :oldGuardian.Id
    ]
    .Active_Enrollments__c;
    Assert.isTrue(
      baselineCount > 0,
      'Precondition: the trigger should have already counted the enrollment for the old ' +
      'guardian — if this fails, AcademicTermEnrollment.Active__c did not evaluate true on a ' +
      'bare insert and this test is not exercising the drift case it claims to'
    );

    learner.Primary_Guardian__c = newGuardian.Id;
    update as user learner;

    Test.startTest();
    Database.executeBatch(new ActiveEnrollmentsRollupBatch(), 200);
    Test.stopTest();

    Map<Id, Account> refreshed = new Map<Id, Account>(
      [
        SELECT Id, Active_Enrollments__c
        FROM Account
        WHERE Id IN :new Set<Id>{ oldGuardian.Id, newGuardian.Id }
      ]
    );
    Assert.areEqual(
      0,
      refreshed.get(oldGuardian.Id).Active_Enrollments__c,
      'Old guardian should drop to 0 once the nightly sweep re-reads the learner\'s guardian'
    );
    Assert.areEqual(
      baselineCount,
      refreshed.get(newGuardian.Id).Active_Enrollments__c,
      'New guardian should pick up the count the old guardian had before the repoint'
    );
  }
}