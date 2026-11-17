/**
 * {@link TriggerHandler} that handles {@link LearningProgram} DML operations.
 *
 * Keeps the Charter-level rollup (see {@link CharterRollupService}) in step
 * with the LearningProgram fields it sums. The trigger record carries no
 * relationship fields, so the Charter parent is resolved by querying
 * Account.ParentId for the affected School ids.
 */
public with sharing class LearningProgramTriggerHandler extends NoOpTriggerHandler {
  /**
   * Only these fields feed the Charter rollup. The
   * Learning_Program_Update_School_Id flow re-saves the record on insert and
   * whenever School__c changes (entry: ISNEW() || ISCHANGED(School__c)) to
   * stamp School_Id__c; leaving that field out of this list makes that
   * re-save a no-op for this trigger.
   */
  private static final List<SObjectField> ROLLUP_FIELDS = new List<SObjectField>{
    Schema.LearningProgram.Count_Lottery_Employee_Priority__c,
    Schema.LearningProgram.Total_Available_Seats_for_School_Year__c,
    Schema.LearningProgram.School__c
  };

  private final DatabaseRepo databaseRepo;
  private final CharterRollupService charterRollupService;

  public LearningProgramTriggerHandler() {
    this(new SystemModeDatabaseRepo(), new CharterRollupServiceImpl());
  }

  @TestVisible
  private LearningProgramTriggerHandler(
    DatabaseRepo databaseRepo,
    CharterRollupService charterRollupService
  ) {
    this.databaseRepo = databaseRepo;
    this.charterRollupService = charterRollupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.LearningProgram.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    recalculateIfAny(collectSchoolIds((List<LearningProgram>) sobjects));
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Set<Id> schoolIds = new Set<Id>();

    for (LearningProgram learningProgram : (List<LearningProgram>) sobjects) {
      LearningProgram oldLearningProgram = (LearningProgram) oldSObjectsByIds.get(
        learningProgram.Id
      );

      SObjectFieldDiffResponse diff = SObjectFieldDiffer.getFieldDiff(
        learningProgram,
        oldLearningProgram,
        ROLLUP_FIELDS
      );
      if (!diff.isDifferent()) {
        continue;
      }

      if (learningProgram.School__c != null) {
        schoolIds.add(learningProgram.School__c);
      }
      // Reparenting to a new School leaves the old Charter stale, so both
      // the old and the new School are collected.
      if (oldLearningProgram.School__c != learningProgram.School__c) {
        if (oldLearningProgram.School__c != null) {
          schoolIds.add(oldLearningProgram.School__c);
        }
      }
    }

    recalculateIfAny(schoolIds);
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    recalculateIfAny(collectSchoolIds((List<LearningProgram>) oldSObjects));
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    recalculateIfAny(collectSchoolIds((List<LearningProgram>) sobjects));
  }

  private void recalculateIfAny(Set<Id> schoolIds) {
    if (schoolIds.isEmpty()) {
      return;
    }

    Set<Id> charterIds = resolveCharterIds(schoolIds);
    if (!charterIds.isEmpty()) {
      charterRollupService.recalculate(charterIds);
    }
  }

  private Set<Id> resolveCharterIds(Set<Id> schoolIds) {
    List<Account> schools = databaseRepo.queryWithBinds(
      'SELECT ParentId FROM Account WHERE Id IN :schoolIds AND ParentId != null',
      new Map<String, Object>{ 'schoolIds' => schoolIds }
    );

    Set<Id> charterIds = new Set<Id>();
    for (Account school : schools) {
      if (school.ParentId != null) {
        charterIds.add(school.ParentId);
      }
    }
    return charterIds;
  }

  private static Set<Id> collectSchoolIds(List<LearningProgram> records) {
    Set<Id> schoolIds = new Set<Id>();
    for (LearningProgram learningProgram : records) {
      if (learningProgram.School__c != null) {
        schoolIds.add(learningProgram.School__c);
      }
    }
    return schoolIds;
  }
}