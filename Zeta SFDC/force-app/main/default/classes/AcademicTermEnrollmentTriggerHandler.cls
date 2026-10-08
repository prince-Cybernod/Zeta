/**
 * {@link TriggerHandler} that handles {@link AcademicTermEnrollment} DML operations.
 *
 * Keeps {@link Account.Active_Enrollments__c} in step with the learner's own
 * Account and both of the learner's guardian Accounts.
 */
public with sharing class AcademicTermEnrollmentTriggerHandler extends NoOpTriggerHandler {
  private final DatabaseRepo databaseRepo;
  private final ActiveEnrollmentsRollupService activeEnrollmentsRollupService;

  public AcademicTermEnrollmentTriggerHandler() {
    this(new SystemModeDatabaseRepo(), new ActiveEnrollmentsRollupServiceImpl());
  }

  @TestVisible
  private AcademicTermEnrollmentTriggerHandler(
    DatabaseRepo databaseRepo,
    ActiveEnrollmentsRollupService activeEnrollmentsRollupService
  ) {
    this.databaseRepo = databaseRepo;
    this.activeEnrollmentsRollupService = activeEnrollmentsRollupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.AcademicTermEnrollment.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    recalculate(collectLearnerAccountIds(sobjects));
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Set<Id> learnerAccountIds = new Set<Id>();

    for (AcademicTermEnrollment enrollment : (List<AcademicTermEnrollment>) sobjects) {
      SObject oldEnrollment = oldSObjectsByIds.get(enrollment.Id);

      SObjectFieldDiffResponse diff = SObjectFieldDiffer.getFieldDiff(
        enrollment,
        oldEnrollment,
        new List<SObjectField>{
          Schema.AcademicTermEnrollment.Active__c,
          Schema.AcademicTermEnrollment.LearnerAccountId
        }
      );
      if (diff.isDifferent()) {
        learnerAccountIds.addAll(
          collectLearnerAccountIds(new List<SObject>{ enrollment, oldEnrollment })
        );
      }
    }

    recalculate(learnerAccountIds);
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    recalculate(collectLearnerAccountIds(oldSObjects));
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    recalculate(collectLearnerAccountIds(sobjects));
  }

  private void recalculate(Set<Id> learnerAccountIds) {
    if (learnerAccountIds.isEmpty()) {
      return;
    }
    activeEnrollmentsRollupService.recalculate(expandToGuardians(learnerAccountIds));
  }

  /**
   * A learner's guardians aren't on the enrollment record itself, only on the
   * learner's Account, so refreshing a guardian's count after a learner's
   * enrollment changes takes one extra query.
   */
  private Set<Id> expandToGuardians(Set<Id> learnerAccountIds) {
    Set<Id> accountIds = new Set<Id>(learnerAccountIds);

    List<Account> learnerAccounts = databaseRepo.queryWithBinds(
      'SELECT Primary_Guardian__c, Secondary_Guardian__c FROM Account WHERE Id IN :learnerAccountIds',
      new Map<String, Object>{ 'learnerAccountIds' => learnerAccountIds }
    );
    for (Account learnerAccount : learnerAccounts) {
      if (learnerAccount.Primary_Guardian__c != null) {
        accountIds.add(learnerAccount.Primary_Guardian__c);
      }
      if (learnerAccount.Secondary_Guardian__c != null) {
        accountIds.add(learnerAccount.Secondary_Guardian__c);
      }
    }
    return accountIds;
  }

  private static Set<Id> collectLearnerAccountIds(List<SObject> records) {
    Set<Id> learnerAccountIds = new Set<Id>();
    for (SObject record : records) {
      if (record == null) {
        continue;
      }
      Id learnerAccountId = (Id) record.get(Schema.AcademicTermEnrollment.LearnerAccountId);
      if (learnerAccountId != null) {
        learnerAccountIds.add(learnerAccountId);
      }
    }
    return learnerAccountIds;
  }
}