/**
 * {@link TriggerHandler} that handles {@link IndividualApplication} DML operations.
 *
 * Kicks off priority-group recalculation on relevant field changes and keeps
 * {@link Account.Application_Count__c} in step with the applications an Account
 * is attached to. District assignment is driven from Flow via
 * {@link FindDistrictInvocable} — the trigger no longer enqueues anything.
 */
public with sharing class IndividualApplicationTriggerHandler extends NoOpTriggerHandler {
  /**
   * The lookups that tie an application to an Account: the student and both
   * guardians. Every one of them feeds Application_Count__c.
   */
  private static final List<SObjectField> ACCOUNT_LOOKUPS = new List<SObjectField>{
    Schema.IndividualApplication.AccountId,
    Schema.IndividualApplication.Primary_Guardian__c,
    Schema.IndividualApplication.Secondary_Guardian__c
  };

  private final CurrentPriorityCalcService priorityGroupService;
  private final ApplicationCountRollupService applicationCountRollupService;

  public IndividualApplicationTriggerHandler() {
    this(new CurrentPriorityCalcServiceImpl(), new ApplicationCountRollupServiceImpl());
  }

  @TestVisible
  private IndividualApplicationTriggerHandler(
    CurrentPriorityCalcService priorityGroupService,
    ApplicationCountRollupService applicationCountRollupService
  ) {
    this.priorityGroupService = priorityGroupService;
    this.applicationCountRollupService = applicationCountRollupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.IndividualApplication.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    recalculateApplicationCounts(collectAccountIds(sobjects));
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
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    recalculateApplicationCounts(collectAccountIds(oldSObjects));
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    recalculateApplicationCounts(collectAccountIds(sobjects));
  }

  private void recalculateApplicationCounts(Set<Id> accountIds) {
    if (!accountIds.isEmpty()) {
      applicationCountRollupService.recalculate(accountIds);
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

  /**
   * Collects the Accounts whose count is affected by an update. A repointed
   * lookup leaves the Account it pointed at stale, so both the old and the new
   * value are collected.
   */
  private static Set<Id> collectAccountIdsForRollup(
    List<IndividualApplication> newRecords,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    Set<Id> accountIds = new Set<Id>();
    for (IndividualApplication individualApplication : newRecords) {
      SObject oldApplication = oldSObjectsByIds.get(individualApplication.Id);

      SObjectFieldDiffResponse lookupDiff = SObjectFieldDiffer.getFieldDiff(
        individualApplication,
        oldApplication,
        ACCOUNT_LOOKUPS
      );
      if (lookupDiff.isDifferent()) {
        accountIds.addAll(
          collectAccountIds(new List<SObject>{ individualApplication, oldApplication })
        );
      }
    }
    return accountIds;
  }
}