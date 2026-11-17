/**
 * {@link TriggerHandler} that handles {@link IndividualApplication} DML operations.
 *
 * Kicks off priority-group recalculation on relevant field changes and keeps
 * {@link Account.Application_Count__c} and
 * {@link Account.Post_Draft_Application_Count__c} in step with the
 * applications an Account is attached to. District assignment is driven from
 * Flow via {@link FindDistrictInvocable} — the trigger no longer enqueues
 * anything.
 */
public with sharing class IndividualApplicationTriggerHandler extends NoOpTriggerHandler {
  private static final String STATUS_DRAFT = 'Draft';
  private static final List<String> CLOSED_STATUSES = new List<String>{
    'Cancelled',
    'Withdrawn/Declined'
  };
  @TestVisible
  private static final String REOPEN_BLOCKED_MESSAGE = 'This student already has an active application on this timeline, so this one can\'t be reopened.';

  /**
   * The lookups that tie an application to an Account: the student and both
   * guardians. Every one of them feeds both Application_Count__c and
   * Post_Draft_Application_Count__c.
   */
  private static final List<SObjectField> ACCOUNT_LOOKUPS = new List<SObjectField>{
    Schema.IndividualApplication.AccountId,
    Schema.IndividualApplication.Primary_Guardian__c,
    Schema.IndividualApplication.Secondary_Guardian__c
  };

  /**
   * The lookups that feed the Contact application rollups: the student and
   * the primary guardian only (the secondary guardian is out of scope).
   */
  private static final List<SObjectField> PERSON_LOOKUPS = new List<SObjectField>{
    Schema.IndividualApplication.AccountId,
    Schema.IndividualApplication.Primary_Guardian__c
  };

  private static final List<SObjectField> CONTACT_ROLLUP_WATCHED_FIELDS = new List<SObjectField>{
    Schema.IndividualApplication.AccountId,
    Schema.IndividualApplication.Primary_Guardian__c,
    Schema.IndividualApplication.Application_Timeline__c,
    Schema.IndividualApplication.Lead_Source__c
  };

  private final CurrentPriorityCalcService priorityGroupService;
  private final ApplicationCountRollupService applicationCountRollupService;
  private final ContactApplicationRollupService contactApplicationRollupService;
  private DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @TestVisible
  private void setDatabaseRepo(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public IndividualApplicationTriggerHandler() {
    this(
      new CurrentPriorityCalcServiceImpl(),
      new ApplicationCountRollupServiceImpl(),
      new ContactApplicationRollupServiceImpl()
    );
  }

  @TestVisible
  private IndividualApplicationTriggerHandler(
    CurrentPriorityCalcService priorityGroupService,
    ApplicationCountRollupService applicationCountRollupService,
    ContactApplicationRollupService contactApplicationRollupService
  ) {
    this.priorityGroupService = priorityGroupService;
    this.applicationCountRollupService = applicationCountRollupService;
    this.contactApplicationRollupService = contactApplicationRollupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.IndividualApplication.SObjectType;
  }

  // SFR-216: a closed application can only be reopened when the student has no other active
  // submitted application on that timeline (including one reopened in this same save).
  public override void onBeforeUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    List<IndividualApplication> reopened = reopenedApplications(sobjects, oldSObjectsByIds);
    if (reopened.isEmpty()) {
      return;
    }
    Set<Id> studentIds = new Set<Id>();
    for (IndividualApplication app : reopened) {
      studentIds.add(app.AccountId);
    }
    Set<String> activeStudentTimelines = new Set<String>();
    for (
      IndividualApplication active : (List<IndividualApplication>) databaseRepo.queryWithBinds(
        'SELECT AccountId, Application_Timeline__c FROM IndividualApplication' +
          ' WHERE AccountId IN :studentIds' +
          ' AND Status NOT IN :closedStatuses AND AppliedDate != NULL',
        new Map<String, Object>{ 'studentIds' => studentIds, 'closedStatuses' => CLOSED_STATUSES }
      )
    ) {
      activeStudentTimelines.add('' + active.AccountId + active.Application_Timeline__c);
    }
    for (IndividualApplication app : reopened) {
      if (!activeStudentTimelines.add('' + app.AccountId + app.Application_Timeline__c)) {
        app.addError(Schema.IndividualApplication.Status, REOPEN_BLOCKED_MESSAGE);
      }
    }
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    recalculateApplicationCounts(collectAccountIds(sobjects));
    recalculateContactApplicationRollups(collectPersonIds(sobjects));
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Set<Id> applicationIdsNeedingRecalculation = new Set<Id>();

    for (IndividualApplication individualApplication : (List<IndividualApplication>) sobjects) {
      IndividualApplication oldApp = (IndividualApplication) oldSObjectsByIds.get(
        individualApplication.Id
      );

      SObjectFieldDiffResponse priorityDiff = SObjectFieldDiffer.getFieldDiff(
        individualApplication,
        oldApp,
        new List<SObjectField>{ Schema.IndividualApplication.Relationship_Priority_Group__c }
      );
      if (priorityDiff.isDifferent()) {
        applicationIdsNeedingRecalculation.add(individualApplication.Id);
      }
    }

    if (!applicationIdsNeedingRecalculation.isEmpty()) {
      priorityGroupService.recalculateForApplications(applicationIdsNeedingRecalculation);
    }

    recalculateApplicationCounts(
      collectAccountIdsForRollup((List<IndividualApplication>) sobjects, oldSObjectsByIds)
    );
    recalculateContactApplicationRollups(
      collectPersonIdsForContactRollup((List<IndividualApplication>) sobjects, oldSObjectsByIds)
    );
    restoreSchoolChoices(reopenedApplications(sobjects, oldSObjectsByIds));
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    recalculateApplicationCounts(collectAccountIds(oldSObjects));
    recalculateContactApplicationRollups(collectPersonIds(oldSObjects));
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    recalculateApplicationCounts(collectAccountIds(sobjects));
    recalculateContactApplicationRollups(collectPersonIds(sobjects));
  }

  // SFR-216: withdrawing an application withdraws its school choices, so reopening brings them
  // back as Applied (the Eligible sync flow then takes over if the application is Eligible).
  private void restoreSchoolChoices(List<IndividualApplication> reopened) {
    if (reopened.isEmpty()) {
      return;
    }
    List<AcademicInterest> choices = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id FROM AcademicInterest' +
        ' WHERE IndividualApplicationId IN :applicationIds AND Status = \'Withdrawn/Declined\'',
      new Map<String, Object>{
        'applicationIds' => new Map<Id, IndividualApplication>(reopened).keySet()
      }
    );
    for (AcademicInterest choice : choices) {
      choice.Status = 'Applied';
    }
    databaseRepo.updateSObjects(choices);
  }

  private static List<IndividualApplication> reopenedApplications(
    List<SObject> sobjects,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    List<IndividualApplication> reopened = new List<IndividualApplication>();
    for (IndividualApplication app : (List<IndividualApplication>) sobjects) {
      String oldStatus = ((IndividualApplication) oldSObjectsByIds.get(app.Id)).Status;
      if (CLOSED_STATUSES.contains(oldStatus) && !CLOSED_STATUSES.contains(app.Status)) {
        reopened.add(app);
      }
    }
    return reopened;
  }

  private void recalculateApplicationCounts(Set<Id> accountIds) {
    if (!accountIds.isEmpty()) {
      applicationCountRollupService.recalculate(accountIds);
    }
  }

  private void recalculateContactApplicationRollups(Set<Id> personAccountIds) {
    if (!personAccountIds.isEmpty()) {
      contactApplicationRollupService.recalculate(personAccountIds);
    }
  }

  private static Set<Id> collectAccountIds(List<SObject> records) {
    Set<Id> accountIds = new Set<Id>();
    for (SObject record : records) {
      if (record == null) {
        continue;
      }
      for (SObjectField field : ACCOUNT_LOOKUPS) {
        Id accountId = (Id) record.get(field);
        if (accountId != null) {
          accountIds.add(accountId);
        }
      }
    }
    return accountIds;
  }

  private static Set<Id> collectPersonIds(List<SObject> records) {
    Set<Id> personIds = new Set<Id>();
    for (SObject record : records) {
      if (record == null) {
        continue;
      }
      for (SObjectField field : PERSON_LOOKUPS) {
        Id personId = (Id) record.get(field);
        if (personId != null) {
          personIds.add(personId);
        }
      }
    }
    return personIds;
  }

  private static Set<Id> collectPersonIdsForContactRollup(
    List<IndividualApplication> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Set<Id> personIds = new Set<Id>();
    for (IndividualApplication individualApplication : newRecords) {
      IndividualApplication oldApplication = (IndividualApplication) oldSObjectsByIds.get(
        individualApplication.Id
      );

      SObjectFieldDiffResponse watchedDiff = SObjectFieldDiffer.getFieldDiff(
        individualApplication,
        oldApplication,
        CONTACT_ROLLUP_WATCHED_FIELDS
      );
      if (watchedDiff.isDifferent()) {
        personIds.addAll(
          collectPersonIds(new List<SObject>{ individualApplication, oldApplication })
        );
      }
    }
    return personIds;
  }

  /**
   * Collects the Accounts whose count is affected by an update. A repointed
   * lookup leaves the Account it pointed at stale, so both the old and the new
   * value are collected. A lookup-unchanged update still recalculates when the
   * Status flips across Draft, the only Status change that moves
   * Post_Draft_Application_Count__c.
   */
  private static Set<Id> collectAccountIdsForRollup(
    List<IndividualApplication> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Set<Id> accountIds = new Set<Id>();
    for (IndividualApplication individualApplication : newRecords) {
      IndividualApplication oldApplication = (IndividualApplication) oldSObjectsByIds.get(
        individualApplication.Id
      );

      SObjectFieldDiffResponse lookupDiff = SObjectFieldDiffer.getFieldDiff(
        individualApplication,
        oldApplication,
        ACCOUNT_LOOKUPS
      );
      if (lookupDiff.isDifferent() || isDraftTransition(oldApplication, individualApplication)) {
        accountIds.addAll(
          collectAccountIds(new List<SObject>{ individualApplication, oldApplication })
        );
      }
    }
    return accountIds;
  }

  private static Boolean isDraftTransition(
    IndividualApplication oldApplication,
    IndividualApplication newApplication
  ) {
    Boolean wasDraft = oldApplication.Status == STATUS_DRAFT;
    Boolean isDraft = newApplication.Status == STATUS_DRAFT;
    return wasDraft != isDraft;
  }
}