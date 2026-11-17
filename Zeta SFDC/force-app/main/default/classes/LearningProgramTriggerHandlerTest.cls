/**
 * Tests for {@link LearningProgramTriggerHandler}.
 */
@IsTest(IsParallel=true)
private class LearningProgramTriggerHandlerTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final CharterRollupServiceMock ROLLUP_MOCK;
  private static final LearningProgramTriggerHandler HANDLER;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    ROLLUP_MOCK = new CharterRollupServiceMock();
    HANDLER = new LearningProgramTriggerHandler(MOCK_REPO, ROLLUP_MOCK);
  }

  private static Account buildSchool(Id schoolId, Id charterId) {
    return new Account(Id = schoolId, ParentId = charterId);
  }

  @IsTest
  private static void getSObjectType_returnsLearningProgram() {
    Assert.areEqual(Schema.LearningProgram.SObjectType, HANDLER.getSObjectType());
  }

  @IsTest
  private static void onAfterInsert_resolvesCharterAndRecalculates() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, charterId) });
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterInsert(
      new List<SObject>{ new LearningProgram(Id = lpId, School__c = schoolId) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> passedIds = (Set<Id>) ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate())[0]
      .get('charterAccountIds');
    Assert.isTrue(passedIds.contains(charterId), 'Should recalculate the Charter parent');
  }

  @IsTest
  private static void onAfterInsert_withNoSchool_doesNotQueryOrRecalculate() {
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    HANDLER.onAfterInsert(new List<SObject>{ new LearningProgram(Id = lpId) });

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    ROLLUP_MOCK.never(ROLLUP_MOCK.method.recalculate());
  }

  @IsTest
  private static void onAfterUpdate_whenEmployeePriorityCountChanges_recalculates() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, charterId) });
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    LearningProgram newLp = new LearningProgram(
      Id = lpId,
      School__c = schoolId,
      Count_Lottery_Employee_Priority__c = 2
    );
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      lpId => new LearningProgram(
        Id = lpId,
        School__c = schoolId,
        Count_Lottery_Employee_Priority__c = 1
      )
    };

    HANDLER.onAfterUpdate(new List<SObject>{ newLp }, oldMap);

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
  }

  @IsTest
  private static void onAfterUpdate_whenAvailableSeatsChanges_recalculates() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, charterId) });
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    LearningProgram newLp = new LearningProgram(
      Id = lpId,
      School__c = schoolId,
      Total_Available_Seats_for_School_Year__c = 20
    );
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      lpId => new LearningProgram(
        Id = lpId,
        School__c = schoolId,
        Total_Available_Seats_for_School_Year__c = 10
      )
    };

    HANDLER.onAfterUpdate(new List<SObject>{ newLp }, oldMap);

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
  }

  @IsTest
  private static void onAfterUpdate_whenUnrelatedFieldChanges_doesNotRecalculate() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id schoolIdStamp = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // Simulates the Learning_Program_Update_School_Id flow's re-save (it
    // stamps School_Id__c on insert or School__c change) touching no
    // rollup field.
    LearningProgram newLp = new LearningProgram(
      Id = lpId,
      School__c = schoolId,
      School_Id__c = schoolIdStamp
    );
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      lpId => new LearningProgram(Id = lpId, School__c = schoolId, School_Id__c = null)
    };

    HANDLER.onAfterUpdate(new List<SObject>{ newLp }, oldMap);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    ROLLUP_MOCK.never(ROLLUP_MOCK.method.recalculate());
  }

  @IsTest
  private static void onAfterInsert_withSchoolThatHasNoParent_doesNotRecalculate() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, null) });

    HANDLER.onAfterInsert(
      new List<SObject>{ new LearningProgram(Id = lpId, School__c = schoolId) }
    );

    ROLLUP_MOCK.never(ROLLUP_MOCK.method.recalculate());
  }

  @IsTest
  private static void onAfterUpdate_whenReparented_collectsOldAndNewSchoolCharters() {
    Id oldSchoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id newSchoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id oldCharterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id newCharterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          buildSchool(oldSchoolId, oldCharterId),
          buildSchool(newSchoolId, newCharterId)
        }
      );
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    LearningProgram newLp = new LearningProgram(Id = lpId, School__c = newSchoolId);
    Map<Id, SObject> oldMap = new Map<Id, SObject>{
      lpId => new LearningProgram(Id = lpId, School__c = oldSchoolId)
    };

    HANDLER.onAfterUpdate(new List<SObject>{ newLp }, oldMap);

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> passedIds = (Set<Id>) ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate())[0]
      .get('charterAccountIds');
    Assert.isTrue(passedIds.contains(oldCharterId), 'Should include the old Charter');
    Assert.isTrue(passedIds.contains(newCharterId), 'Should include the new Charter');

    Map<String, Object> queryCall = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())[0];
    Set<Id> queriedSchoolIds = (Set<Id>) ((Map<String, Object>) queryCall.get('bindMap'))
      .get('schoolIds');
    Assert.isTrue(queriedSchoolIds.contains(oldSchoolId), 'Should query the old School');
    Assert.isTrue(queriedSchoolIds.contains(newSchoolId), 'Should query the new School');
  }

  @IsTest
  private static void onAfterDelete_usesOldSchoolAndRecalculates() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, charterId) });
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterDelete(
      new List<SObject>{ new LearningProgram(Id = lpId, School__c = schoolId) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
    Set<Id> passedIds = (Set<Id>) ROLLUP_MOCK.getCalls(ROLLUP_MOCK.method.recalculate())[0]
      .get('charterAccountIds');
    Assert.isTrue(passedIds.contains(charterId));
  }

  @IsTest
  private static void onAfterUndelete_recalculates() {
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildSchool(schoolId, charterId) });
    ROLLUP_MOCK.when(ROLLUP_MOCK.method.recalculate()).thenReturnVoid();

    HANDLER.onAfterUndelete(
      new List<SObject>{ new LearningProgram(Id = lpId, School__c = schoolId) }
    );

    ROLLUP_MOCK.verify(ROLLUP_MOCK.method.recalculate(), 1);
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    Assert.isNotNull(new LearningProgramTriggerHandler(), 'Should create with default constructor');
  }
}