/**
 * {@link TriggerHandler} that handles {@link IndividualApplication} DML operations.
 *
 * Currently only kicks off priority-group recalculation on relevant field
 * changes. District assignment is driven from Flow via
 * {@link FindDistrictInvocable} — the trigger no longer enqueues anything.
 */
public with sharing class IndividualApplicationTriggerHandler extends NoOpTriggerHandler {
  private final CurrentPriorityCalcService priorityGroupService;

  public IndividualApplicationTriggerHandler() {
    this(new CurrentPriorityCalcServiceImpl());
  }

  @TestVisible
  private IndividualApplicationTriggerHandler(CurrentPriorityCalcService priorityGroupService) {
    this.priorityGroupService = priorityGroupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.IndividualApplication.SObjectType;
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
  }
}