/**
 * Tests for {@link AcademicTermEnrollmentTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class AcademicTermEnrollmentTriggerHandlerTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ActiveEnrollmentsRollupServiceMock ROLLUP_MOCK;
  private static final AcademicTermEnrollmentTriggerHandler HANDLER;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    ROLLUP_MOCK = new ActiveEnrollmentsRollupServiceMock();
    HANDLER = new AcademicTermEnrollmentTriggerHandler(MOCK_REPO, ROLLUP_MOCK);
  }

  // Active__c is read-only (a formula field), so it can't be set via the
  // constructor — build via JSON.deserialize, as SiblingSectionControllerTest does.
  private static AcademicTermEnrollment buildEnrollment(
    Id enrollmentId,
    Id learnerAccountId,
    Boolean isActive
  ) {
    return (AcademicTermEnrollment) JSON.deserialize(
      '{"Id":"' +
        enrollmentId +
        '","LearnerAccountId":"' +
        learnerAccountId +
        '","Active__c":' +
        isActive +
        '}',
      AcademicTermEnrollment.class
    );
  }

  private static Id fakeAccountId() {
    return SObjectIds.generateFakeId(Schema.Account.SObjectType);
  }

  private static void stubNoGuardians() {
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<Account>());
  }

  private static Set<Id> capturedRollupIds() {
    List<Map<String, Object>> calls = ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate());
    return (Set<Id>) calls[0].get('accountIds');
  }

  @IsTest
  private static void getSObjectType_returnsAcademicTermEnrollment() {
    Assert.areEqual(Schema.AcademicTermEnrollment.SObjectType, HANDLER.getSObjectType());
  }

  @IsTest
  private static void onAfterInsert_collectsLearnerAndBothGuardians() {
    Id learnerId = fakeAccountId();
    Id primaryGuardianId = fakeAccountId();
    Id secondaryGuardianId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          new Account(
            Id = learnerId,
            Primary_Guardian__c = primaryGuardianId,
            Secondary_Guardian__c = secondaryGuardianId
          )
        }
      );

    HANDLER.onAfterInsert(
      new List<SObject>{
        buildEnrollment(
          SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType),
          learnerId,
          true
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = capturedRollupIds();
    Assert.areEqual(3, capturedIds.size(), 'One enrollment should touch three Accounts');
    Assert.isTrue(capturedIds.contains(learnerId), 'Should include the learner');
    Assert.isTrue(capturedIds.contains(primaryGuardianId), 'Should include the primary guardian');
    Assert.isTrue(
      capturedIds.contains(secondaryGuardianId),
      'Should include the secondary guardian'
    );
  }

  @IsTest
  private static void onAfterInsert_withTwoHundredRecords_callsServiceOnce() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    stubNoGuardians();

    List<SObject> enrollments = new List<SObject>();
    for (Integer i = 0; i < 200; i++) {
      enrollments.add(
        buildEnrollment(
          SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType),
          fakeAccountId(),
          true
        )
      );
    }

    HANDLER.onAfterInsert(enrollments);

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    Assert.areEqual(200, capturedRollupIds().size(), 'Should collect all 200 learners in one call');
  }

  @IsTest
  private static void onAfterInsert_withNoLearnerAccount_doesNotCallService() {
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterInsert(
      new List<SObject>{
        new AcademicTermEnrollment(
          Id = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType)
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 0);
    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void onAfterDelete_collectsLearnerAccount() {
    Id learnerId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    stubNoGuardians();

    HANDLER.onAfterDelete(
      new List<SObject>{
        buildEnrollment(
          SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType),
          learnerId,
          true
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Assert.isTrue(capturedRollupIds().contains(learnerId), 'Should include the learner');
  }

  @IsTest
  private static void onAfterUndelete_collectsLearnerAccount() {
    Id learnerId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    stubNoGuardians();

    HANDLER.onAfterUndelete(
      new List<SObject>{
        buildEnrollment(
          SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType),
          learnerId,
          true
        )
      }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Assert.isTrue(capturedRollupIds().contains(learnerId), 'Should include the learner');
  }

  /**
   * The "active" boundary: crossing Active__c from true to false (withdrawal)
   * must trigger recalculation even though the learner never changes.
   */
  @IsTest
  private static void onAfterUpdate_whenActiveFlagCrossesTheBoundary_recalculates() {
    Id enrollmentId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);
    Id learnerId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    stubNoGuardians();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildEnrollment(enrollmentId, learnerId, false) },
      new Map<Id, SObject>{ enrollmentId => buildEnrollment(enrollmentId, learnerId, true) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Assert.isTrue(
      capturedRollupIds().contains(learnerId),
      'Should recalculate the learner on the active-flag boundary'
    );
  }

  @IsTest
  private static void onAfterUpdate_whenLearnerRepointed_collectsBothOldAndNewAccounts() {
    Id enrollmentId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);
    Id oldLearnerId = fakeAccountId();
    Id newLearnerId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();
    stubNoGuardians();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildEnrollment(enrollmentId, newLearnerId, true) },
      new Map<Id, SObject>{ enrollmentId => buildEnrollment(enrollmentId, oldLearnerId, true) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> capturedIds = capturedRollupIds();
    Assert.isTrue(capturedIds.contains(oldLearnerId), 'Should refresh the learner left behind');
    Assert.isTrue(capturedIds.contains(newLearnerId), 'Should refresh the newly linked learner');
  }

  @IsTest
  private static void onAfterUpdate_whenNeitherActiveNorLearnerChanges_doesNotCallService() {
    Id enrollmentId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);
    Id learnerId = fakeAccountId();
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterUpdate(
      new List<SObject>{ buildEnrollment(enrollmentId, learnerId, true) },
      new Map<Id, SObject>{ enrollmentId => buildEnrollment(enrollmentId, learnerId, true) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 0);
    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    AcademicTermEnrollmentTriggerHandler handler = new AcademicTermEnrollmentTriggerHandler();

    Assert.areEqual(Schema.AcademicTermEnrollment.SObjectType, handler.getSObjectType());
  }
}