/**
 * {@link TriggerHandler} that handles {@link Priority_Item__c} DML operations.
 */
public with sharing class PriorityItemTriggerHandler extends NoOpTriggerHandler {
  private final SiblingApplyingRollupService siblingRollupService;
  private final PriorityGroupRollupService priorityGroupRollupService;
  private final EmployeePriorityRollupService employeePriorityRollupService;

  public PriorityItemTriggerHandler() {
    this(
      new SiblingApplyingRollupServiceImpl(),
      new PriorityGroupRollupServiceImpl(),
      new EmployeePriorityRollupServiceImpl()
    );
  }

  @TestVisible
  private PriorityItemTriggerHandler(
    SiblingApplyingRollupService siblingRollupService,
    PriorityGroupRollupService priorityGroupRollupService,
    EmployeePriorityRollupService employeePriorityRollupService
  ) {
    this.siblingRollupService = siblingRollupService;
    this.priorityGroupRollupService = priorityGroupRollupService;
    this.employeePriorityRollupService = employeePriorityRollupService;
  }

  public override SObjectType getSObjectType() {
    return Schema.Priority_Item__c.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    List<Priority_Item__c> records = sobjects;

    Set<Id> siblingAppIds = collectRelatedApplicationIds(records);
    if (!siblingAppIds.isEmpty()) {
      siblingRollupService.recalculate(siblingAppIds);
    }

    Set<Id> relatedAppIds = collectRelatedApplicationIds(records);
    if (!relatedAppIds.isEmpty()) {
      priorityGroupRollupService.recalculate(relatedAppIds);
    }

    Set<Id> employeePriorityAppIds = collectEmployeePriorityApplicationIds(records);
    if (!employeePriorityAppIds.isEmpty()) {
      employeePriorityRollupService.recalculate(employeePriorityAppIds);
    }
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Set<Id> siblingAppIds = new Set<Id>();
    Set<Id> relatedAppIds = new Set<Id>();
    Set<Id> employeePriorityAppIds = new Set<Id>();

    for (Priority_Item__c priorityItem : (List<Priority_Item__c>) sobjects) {
      Priority_Item__c oldPriorityItem = (Priority_Item__c) oldSObjectsByIds.get(priorityItem.Id);

      // The sibling-applying count rolls up onto the APPLICANT's application
      // (Related_Application__c), so recompute when the type/status/applicant
      // of a sibling-applying item changes (e.g. Pending -> Approved).
      SObjectFieldDiffResponse siblingDiff = SObjectFieldDiffer.getFieldDiff(
        priorityItem,
        oldPriorityItem,
        new List<SObjectField>{
          Schema.Priority_Item__c.Priority_Type__c,
          Schema.Priority_Item__c.Review_Status__c,
          Schema.Priority_Item__c.Related_Application__c
        }
      );
      if (siblingDiff.isDifferent()) {
        if (String.isNotBlank(priorityItem.Related_Application__c)) {
          siblingAppIds.add(priorityItem.Related_Application__c);
        }
        if (oldPriorityItem.Related_Application__c != priorityItem.Related_Application__c) {
          if (String.isNotBlank(oldPriorityItem.Related_Application__c)) {
            siblingAppIds.add(oldPriorityItem.Related_Application__c);
          }
        }
      }

      SObjectFieldDiffResponse priorityGroupDiff = SObjectFieldDiffer.getFieldDiff(
        priorityItem,
        oldPriorityItem,
        new List<SObjectField>{
          Schema.Priority_Item__c.Review_Status__c,
          Schema.Priority_Item__c.Priority_Group__c,
          Schema.Priority_Item__c.Priority_Type__c, // TODO: add a test for this
          Schema.Priority_Item__c.Related_Application__c
        }
      );
      if (priorityGroupDiff.isDifferent()) {
        if (String.isNotBlank(priorityItem.Related_Application__c)) {
          relatedAppIds.add(priorityItem.Related_Application__c);
        }

        // Include old application if reparented
        if (oldPriorityItem.Related_Application__c != priorityItem.Related_Application__c) {
          if (String.isNotBlank(oldPriorityItem.Related_Application__c)) {
            relatedAppIds.add(oldPriorityItem.Related_Application__c);
          }
        }
      }

      Boolean isOrWasZetaStaff =
        priorityItem.Priority_Type__c == PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF ||
        oldPriorityItem.Priority_Type__c ==
        PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF;

      if (isOrWasZetaStaff) {
        Boolean typeChanged = priorityItem.Priority_Type__c != oldPriorityItem.Priority_Type__c;
        Boolean statusChanged = priorityItem.Review_Status__c != oldPriorityItem.Review_Status__c;
        Boolean relatedAppChanged =
          priorityItem.Related_Application__c != oldPriorityItem.Related_Application__c;

        if (typeChanged || statusChanged || relatedAppChanged) {
          if (String.isNotBlank(priorityItem.Related_Application__c)) {
            employeePriorityAppIds.add(priorityItem.Related_Application__c);
          }
          if (relatedAppChanged && String.isNotBlank(oldPriorityItem.Related_Application__c)) {
            employeePriorityAppIds.add(oldPriorityItem.Related_Application__c);
          }
        }
      }
    }

    if (!siblingAppIds.isEmpty()) {
      siblingRollupService.recalculate(siblingAppIds);
    }

    if (!relatedAppIds.isEmpty()) {
      priorityGroupRollupService.recalculate(relatedAppIds);
    }

    if (!employeePriorityAppIds.isEmpty()) {
      employeePriorityRollupService.recalculate(employeePriorityAppIds);
    }
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    List<Priority_Item__c> records = oldSObjects;

    Set<Id> siblingAppIds = collectRelatedApplicationIds(records);
    if (!siblingAppIds.isEmpty()) {
      siblingRollupService.recalculate(siblingAppIds);
    }

    Set<Id> relatedAppIds = collectRelatedApplicationIds(records);
    if (!relatedAppIds.isEmpty()) {
      priorityGroupRollupService.recalculate(relatedAppIds);
    }

    Set<Id> employeePriorityAppIds = collectEmployeePriorityApplicationIds(records);
    if (!employeePriorityAppIds.isEmpty()) {
      employeePriorityRollupService.recalculate(employeePriorityAppIds);
    }
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    List<Priority_Item__c> records = sobjects;

    Set<Id> siblingAppIds = collectRelatedApplicationIds(records);
    if (!siblingAppIds.isEmpty()) {
      siblingRollupService.recalculate(siblingAppIds);
    }

    Set<Id> relatedAppIds = collectRelatedApplicationIds(records);
    if (!relatedAppIds.isEmpty()) {
      priorityGroupRollupService.recalculate(relatedAppIds);
    }

    Set<Id> employeePriorityAppIds = collectEmployeePriorityApplicationIds(records);
    if (!employeePriorityAppIds.isEmpty()) {
      employeePriorityRollupService.recalculate(employeePriorityAppIds);
    }
  }

  private static Set<Id> collectRelatedApplicationIds(List<Priority_Item__c> records) {
    Set<Id> appIds = new Set<Id>();
    for (Priority_Item__c priorityItem : records) {
      if (String.isNotBlank(priorityItem.Related_Application__c)) {
        appIds.add(priorityItem.Related_Application__c);
      }
    }
    return appIds;
  }

  private static Set<Id> collectEmployeePriorityApplicationIds(List<Priority_Item__c> records) {
    Set<Id> appIds = new Set<Id>();
    for (Priority_Item__c priorityItem : records) {
      if (
        priorityItem.Priority_Type__c == PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF &&
        String.isNotBlank(priorityItem.Related_Application__c)
      ) {
        appIds.add(priorityItem.Related_Application__c);
      }
    }
    return appIds;
  }
}