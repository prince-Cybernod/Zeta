/*
Action Plans v4
David Schach 2022
https://appexchange.salesforce.com/appxListingDetail?listingId=a0N4V00000Gg6NVUAZ

Action Plans v3
Force.com Labs 2011
http://appexchange.salesforce.com/listingDetail?listingId=a0N30000003HcINEA0

Copyright (c) 2022, salesforce.com, inc.
All rights reserved.
SPDX-License-Identifier: BSD-3-Clause
For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause

*/
/**
 * Extension for `Action Plan Template` Create/Edit page
 * @since v3
 * @author {@link [Rodrigo Birriel](https://www.linkedin.com/in/rbirriel)}
 * @author {@link [David Schach](https://github.com/dschach)}
 * @group Visualforce
 */
public with sharing class ActionPlanTemplateCreationController {
  private Double taskIndex;
  /**
   * The Action Plan Template for this page
   */
  @TestVisible
  private ActionPlanTemplate__c actionPlanTemplate;

  /**
   * Getter for the Action Plan Template
   * @return The Action Plan Template
   */
  public ActionPlanTemplate__c getActionPlanTemplate() {
    return actionPlanTemplate;
  }
  /**
   * Page SubTitle
   */
  public String subTitle { get; private set; }
  /**
   * Does the user have reminders enabled?
   */
  public Boolean canDisplayReminder { get; private set; }
  /**
   * Does the `Task` object have Record Types enabled?
   */
  public Boolean taskHasRecordType { get; private set; }

  /**
   * Map of user lookup fields for the target object
   */
  public Map<String, String> userLookupFields { get; private set; }

  /**
   * Due Date Type options
   */
  public List<SelectOption> dueDateTypeOptions {
    get {
      if (dueDateTypeOptions == null) {
        dueDateTypeOptions = new List<SelectOption>();
        dueDateTypeOptions.add(new SelectOption('AssignedDate',     'Assigned Date'));
        dueDateTypeOptions.add(new SelectOption('DependentDueDate', 'Dependent Task Due Date'));
        dueDateTypeOptions.add(new SelectOption('DateField',        'Object date field'));
        dueDateTypeOptions.add(new SelectOption('StaticDate',       'User sets a static date'));
      }
      return dueDateTypeOptions;
    }
    private set;
  }

  /**
   * Date fields for the target object
   */
  public Map<String, String> dateFields { get; private set; }

  @TestVisible
  private List<APTemplateTask__c> pendingTemplateTaskDeletes;
  /**
   * If we are making this template from another template, the Id is stored here
   */
  private Id templateId;

  /**
   * Constructor
   * <br>If we can obtain the Id from the page parameters then we search for that template and set the variable for that template.
   * <br>If we can't obtain the Id from the page parameters then we create a new template and obtain from the controller.
   * <br>Then we need to check if we are cloning the template; in that case clone the template without Id.
   * @param stdController Standard Controller (`ActionPlanTemplate__c`)
   */
  public ActionPlanTemplateCreationController(ApexPages.StandardController stdController) {
    this.taskIndex = 0;
    actionPlanTemplate = (ActionPlanTemplate__c) stdController.getRecord();

    if (ApexPages.currentPage().getParameters().get('clone') == '1') {
      if (ApexPages.currentPage().getParameters().containsKey('templateId')) {
        templateId = ActionPlansUtilities.getEscapedPageParameter('templateId');
        //System.debug('we have a template : ' + templateId);
      } else if (ApexPages.currentPage().getParameters().containsKey('Id') && ApexPages.currentPage().getParameters().get('Id') != null) {
        templateId = ActionPlansUtilities.getEscapedPageParameter('Id');
        //System.debug('using Id parameter : ' + templateId);
      }

      if (templateId != null) {
        ActionPlanTemplate__c apC = [SELECT Name, Description__c, SkipDay__c, SkipWeekends__c, TaskRecordTypeID__c FROM ActionPlanTemplate__c WHERE Id = :templateId LIMIT 1];

        actionPlanTemplate.Name = apC.Name;
        actionPlanTemplate.Description__c = apC.Description__c;
        actionPlanTemplate.SkipDay__c = apC.SkipDay__c;
        actionPlanTemplate.SkipWeekends__c = apC.SkipWeekends__c;
        actionPlanTemplate.TaskRecordTypeID__c = apC.TaskRecordTypeID__c;

        ApexPages.currentPage().getParameters().put('id', null);
      }
    }

    this.canDisplayReminder = ActionPlansUtilities.getCanDisplayReminder();
    this.taskHasRecordType = ActionPlansUtilities.taskUsesRecordTypes;

    if (actionPlanTemplate.Id != null) {
      taskIndex = calculateTaskIndexValue();
      subTitle = actionPlanTemplate.Name;
    } else {
      if (taskHasRecordType) {
        actionPlanTemplate.TaskRecordTypeID__c = getDefaultTaskRecordTypeId();
      }
      this.taskIndex = 0;
      this.subTitle = System.Label.ap_New + ' ' + Schema.getGlobalDescribe().get(ActionPlansUtilities.namespacePrefix + 'ActionPlanTemplate__c').getDescribe().getLabel();
    }
  }

  /**
   * Action on page load to ensure custom setting is created
   * @return   `PageReference` null
   * @see ActionPlansUtilities.onPageLoad
   */
  public PageReference onLoad() {
    ActionPlansUtilities.onPageLoad();
    if (getTemplateWrappers().isEmpty()) {
      addTemplateTask();
    }

    // Initialize user lookup fields and date fields if Target Object API Name is set
    if (String.isNotBlank(actionPlanTemplate.Target_Object_API_Name__c)) {
      userLookupFields = getUserLookupFieldsRemote(actionPlanTemplate.Target_Object_API_Name__c);
      dateFields = getDateFieldsRemote(actionPlanTemplate.Target_Object_API_Name__c);
    } else {
      userLookupFields = new Map<String, String>();
      dateFields = new Map<String, String>();
    }

    return null;
  }

  /**
   * Standalone save action so the redirects are different for Save vs Save and New
   * <br>First delete pending deletions, then upsert the template and its tasks,
   * <br>then update dependencies
   * @return `Boolean` Do we have an error?
   */
  private Boolean doSave() {
    // Validate Fallback Queue
    if (String.isBlank(actionPlanTemplate?.Fallback_Queue__c)) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Fallback Queue is required'));
      return true;
    }

    // Validate the WHERE clause if provided
    if (String.isNotBlank(actionPlanTemplate?.Where_Clause__c)) {
      if (String.isBlank(actionPlanTemplate?.Target_Object_API_Name__c)) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Target Object API Name is required when using a WHERE clause'));
        return true; // Return with error
      }

      try {
        // Remove any leading "WHERE" if the user included it
        String whereClause = actionPlanTemplate.Where_Clause__c.trim();
        if (whereClause.startsWithIgnoreCase('WHERE')) {
          whereClause = whereClause.substring(5).trim();
          actionPlanTemplate.Where_Clause__c = whereClause; // Save the cleaned version
        }

        // Test the query
        String testQuery = 'SELECT COUNT() FROM ' + actionPlanTemplate.Target_Object_API_Name__c + ' WHERE ' + whereClause;
        Database.countQuery(testQuery);
      } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid WHERE clause: ' + e.getMessage()));
        return true; // Return with error
      }
    }

    // check for pending Deletes; if something is pending send it to delete
    if (pendingTemplateTaskDeletes != null) {
      Database.delete(pendingTemplateTaskDeletes);
    }
    // update Action Plan Template object
    try {
      Database.upsert(actionPlanTemplate);
    } catch (Exception e) {
      ApexPages.addMessages(e);
      System.debug('ERROR: ' + e.getMessage());
      this.errorMsg = e.getMessage();
      return true;
    }

    // save tasks to the template and attach relation to Action Plan
    for (APTemplateTask__c t : aptTasks) {
      if (t.Action_Plan_Template__c == null) {
        t.Action_Plan_Template__c = actionPlanTemplate.Id;
      }
      if (t.DaysFromStart__c == null || t.DaysFromStart__c < 0) {
        t.DaysFromStart__c = 0;
      }
      t.DaysFromStart__c = Math.abs(t.DaysFromStart__c);
    }

    try {
      Database.upsert(aptTasks);
    } catch (Exception e) {
      ApexPages.addMessages(e);
      System.debug('ERROR: ' + e.getMessage());
      this.errorMsg = e.getMessage();
      return true;
    }

    // run through the tasks and take care of dependents
    for (APTemplateTask__c t : aptTasks) {
      if (t.Dependent__c != null && t.Dependent__c != 'None') {
        t.TController__c = aptTasks[Integer.valueOf(t.Dependent__c)].Id;
      } else {
        t.TController__c = null;
        t.Dependent__c = 'None'; // Added for redundancy
      }
    }

    try {
      Database.update(aptTasks);
    } catch (Exception e) {
      ApexPages.addMessages(e);
      System.debug('ERROR: ' + e.getMessage());
      this.errorMsg = e.getMessage();
      return true;
    }
    return false;
  }

  /**
   * Saves Action Plan Template and all tasks, then redirects to the AP template list.
   * <br>First check for pending templates for delete; in case that exists then delete those objects.
   * <br>Then insert or update the Action Plan Template pending to save and save tasks to the template
   * and attach relation to Action Plan.
   * @return `PageReference` Page.ActionPlanTemplateDetail
   */
  public PageReference saveTemplate() {
    Boolean hasSaveError = doSave();
    if (hasSaveError) {
      return null;
    }
    // Send the user to the detail page for the new account.
    PageReference newPage = Page.ActionPlanTemplateDetail;
    newPage.getParameters().put('Id', actionPlanTemplate.Id);
    newPage.setRedirect(true);
    return newPage;
  }

  /**
   * Save and go to New page for Save and New
   * @return `PageReference` Page.ActionPlanTemplateCreation
   */
  public PageReference saveAndNew() {
    Boolean hasSaveError = doSave();
    if (hasSaveError) {
      return null;
    }

    PageReference newPage = Page.ActionPlanTemplateCreation;
    newPage.getParameters().clear();
    newPage.setRedirect(true);
    return newPage;
  }

  /**
   * Cancel changes
   * @return `PageReference` Object home or Template detail page
   */
  public PageReference cancelTemplate() {
    PageReference newPage;

    if (actionPlanTemplate.Id == null) {
      // Send the user to the list of templates.
      newPage = new PageReference('/' + Schema.ActionPlanTemplate__c.SObjectType.getDescribe().getKeyPrefix() + '/o');
    } else {
      // Send the user to the detail page for the new account.
      newPage = Page.ActionPlanTemplateDetail;
      newPage.getParameters().put('Id', actionPlanTemplate.Id);
    }
    newPage.setRedirect(true);

    return newPage;
  }

  /**
   * Add a new row to the Template Tasks (but do not commit to the database)
   */
  public void addTemplateTask() {
    taskIndex++;

    //in case the task limit is reached set a message error to display
    if (aptTasks.size() >= ActionPlansUtilities.MAX_APTASKS) {
      List<String> parameters = new List<String>();
      parameters.add(String.valueOf(ActionPlansUtilities.MAX_APTASKS));
      errorMsg = String.format(System.Label.ap_Errors_TaskLimitError, parameters);
    } else {
      APTemplateTask__c t = new APTemplateTask__c();
      t.TaskIndex__c = taskIndex;
      aptTasks.add(t);
    }
  }

  /**
   * Remove this row from the Template Tasks (but do not commit to the database)
   */
  public void removeTemplateTask() {
    if (ApexPages.currentPage().getParameters().get('remove') != null) {
      Integer taskIndex = Integer.valueOf(ApexPages.currentPage().getParameters().get('remove'));

      //check for dependent children and clear them since the parent is being removed.
      aptTasks[taskIndex].TController__c = null;
      aptTasks[taskIndex].Dependent__c = null;

      Integer dependentApTask;

      //update the current dependent position from tasks below of deleted one.
      for (Integer i = 0; i < aptTasks.size(); i++) {
        APTemplateTask__c aptTask = aptTasks.get(i);
        if (aptTask.Dependent__c != null && aptTask.Dependent__c != 'None') {
          dependentApTask = Integer.valueOf(aptTask.Dependent__c);
          if (dependentApTask > taskIndex) {
            aptTask.Dependent__c = String.valueOf(dependentApTask - 1);
          } else if (dependentApTask == taskIndex) {
            aptTask.Dependent__c = 'None';
            aptTask.TController__c = null;
          }
        }
      }

      // before remove check if it exists in the DB. If so, add to pendingTemplateTaskDeletes to be deleted on save.
      if (aptTasks[taskIndex].Id != null) {
        if (pendingTemplateTaskDeletes == null) {
          pendingTemplateTaskDeletes = new List<APTemplateTask__c>();
        }
        pendingTemplateTaskDeletes.add(aptTasks[taskIndex]);
      }

      aptTasks.remove(taskIndex);

      // clear errorMsg if it's set.
      if (aptTasks.size() < ActionPlansUtilities.MAX_APTASKS) {
        errorMsg = null;
      }
    }
  }

  /**
   * Iterate over aptTasks and generate wrappers for display on the page
   * @return `List<ApTTaskWrapper>` All the template wrappers for display on the page
   * @see ActionPlanTemplateCreationController.aptTasks
   */
  public List<ApTTaskWrapper> getTemplateWrappers() {
    List<ApTTaskWrapper> tasksList = new List<ApTTaskWrapper>();

    Integer i = 0;
    for (APTemplateTask__c templateTask : aptTasks) {
      ApTTaskWrapper wrapper = new ApTTaskWrapper(templateTask, i, this.actionPlanTemplate.TaskRecordTypeID__c);
      tasksList.add(wrapper);
      i++;
    }
    if (i > 0) {
      tasksList[i - 1].isLast = true;
    }
    return tasksList;
  }

  /**
   * The list of Template Tasks (no wrapper) - private for internal use only
   */
  @TestVisible
  private List<APTemplateTask__c> aptTasks {
    get {
      if (aptTasks == null) {
        aptTasks = new List<APTemplateTask__c>();
        aptTasks = getTemplateTasks();
      }
      return aptTasks;
    }
    set;
  }

  /**
   * Single query for ActionPlan Template Tasks
   * @author {@link [David Schach](https://github.com/dschach)}
   * @param  templateId `APTemplate__c` Id
   * @return          `List<APTemplateTask__c>` The related APTemplate Tasks
   */
  private List<APTemplateTask__c> queryAPTTasks(Id templateId) {
    return [
      SELECT
        Type__c,
        Subject__c,
        Priority__c,
        Dependent__c,
        Name,
        User__c,
        TaskIndex__c,
        Minutes_Reminder__c,
        User__r.Name,
        User__r.Username,
        Id,
        DaysFromStart__c,
        CreatedById,
        Action_Plan_Template__c,
        TController__c,
        TController__r.Subject__c,
        Reminder__c,
        SendEmail__c,
        Comments__c,
        StaticDueDate__c,
        DueDateType__c,
        DueDateRelatedField__c,
        UserType__c,
        UserRelatedField__c,
        FallbackUser__c,
        FallbackUser__r.Name,
        FallbackUser__r.Username,
        FallbackUserType__c,
        FallbackUserRelatedField__c
      FROM APTemplateTask__c
      WHERE Action_Plan_Template__c = :templateId
      ORDER BY TaskIndex__c ASC
    ];
  }

  /**
   * Get all tasks related to the Action Template.
   * @return `List<APTemplateTask__c>` ActionPlan Template Tasks
   */
  public List<APTemplateTask__c> getTemplateTasks() {
    if (aptTasks.isEmpty()) {
      if (actionPlanTemplate.Id != null) {
        aptTasks = queryAPTTasks(actionPlanTemplate.Id);
      } else {
        aptTasks = new List<APTemplateTask__c>();
        APTemplateTask__c t = new APTemplateTask__c();
        t.Reminder__c = ActionPlansUtilities.getCheckReminderByDefault();
        t.Priority__c = ActionPlansUtilities.getTaskRecordTypePriorityDefaultValues().get(actionPlanTemplate.TaskRecordTypeID__c);
        aptTasks.add(t);
      }

      // clone and clear ids
      if (ApexPages.currentPage().getParameters().get('clone') == '1') {
        aptTasks = queryAPTTasks(String.escapeSingleQuotes(templateId));
        List<APTemplateTask__c> tempTaskList = aptTasks.deepClone(false, false, false);
        aptTasks.clear();
        aptTasks = tempTaskList;

        // clear lookup relationship
        for (APTemplateTask__c t : aptTasks) {
          t.Action_Plan_Template__c = null;
        }
      }
    }
    return aptTasks;
  }

  /**
   * Return size of the APTTemplate Tasks List.
   * @return `Integer` the number of template tasks
   */
  public Integer getTemplateTaskSize() {
    return aptTasks.size();
  }

  /**
   * Call method getTemplateSubjectItems()
   * @return `List<SelectOption>` the picklist of Task subjects
   */
  public List<SelectOption> getTemplateSubjectItems() {
    List<SelectOption> options = new List<SelectOption>();
    options.add(new SelectOption('None', '--' + System.Label.ap_None + '--'));
    Integer i = 0;

    if (aptTasks != null) {
      for (APTemplateTask__c t : aptTasks) {
        if (t.Subject__c != null) {
          options.add(new SelectOption(String.valueOf(i), t.Subject__c + ' (' + (i + 1) + ')'));
        }
        i++;
      }
    }

    return options;
  }

  /**
   * Checks if Action Plan Tasks has cyclic dependency.
   * @return `PageReference` to allow pass-through of save action
   */
  public PageReference checkCycleDependent() {
    if (this.templateCycleDependent()) {
      return null;
    } else {
      return this.saveTemplate();
    }
  }

  /**
   * Checks if Action Plans Tasks has cyclic dependency.
   * @return `Boolean` cyclicErrorExists
   */
  public Boolean templateCycleDependent() {
    this.errorMsg = null;
    Integer index = 0;

    for (APTemplateTask__c t : aptTasks) {
      if (t.Dependent__c != null && t.Dependent__c != 'None') {
        APTemplateTask__c link = aptTasks[Integer.valueOf(t.Dependent__c)];

        //task can not depend on themselves
        if (Integer.valueOf(t.Dependent__c) == index) {
          System.debug('self-dependency error ' + System.Label.ap_ItselfDependencyError);
          this.errorMsg = System.Label.ap_ItselfDependencyError;
          return true;
        }

        if (this.dependantCycle(link, index)) {
          //System.debug('cyclic-dependency error ' + System.Label.ap_Errors_RemoveCyclicDependency);
          this.errorMsg = System.Label.ap_Errors_RemoveCyclicDependency;
          return true;
        }
      }
      index++;
    }
    return false;
  }

  /**
   * Check for dependent tasks
   * @param inspectedTask We check against a specific task
   * @param index The index (position) of the template task
   * @return `Boolean` Is there a dependency for this task?
   */
  private Boolean dependantCycle(APTemplateTask__c inspectedTask, Integer index) {
    Boolean hasDependency = false;
    Set<Integer> checkedTasks = new Set<Integer>();

    while (!hasDependency) {
      if (inspectedTask.Dependent__c != null && inspectedTask.Dependent__c != 'None') {
        if (checkedTasks.contains(Integer.valueOf(inspectedTask.Dependent__c))) {
          hasDependency = true;
          break;
        } else {
          checkedTasks.add(Integer.valueOf(inspectedTask.Dependent__c));
        }
      }

      if (inspectedTask.Dependent__c != null && inspectedTask.Dependent__c != 'None') {
        Integer tempIndexDestiny = Integer.valueOf(inspectedTask.Dependent__c);
        APTemplateTask__c link = aptTasks[tempIndexDestiny];

        if (link.Dependent__c != null && link.Dependent__c != 'None') {
          if (Integer.valueOf(link.Dependent__c) == index) {
            hasDependency = true;
            break;
          } else {
            //get next task in dependency chain
            inspectedTask = aptTasks[Integer.valueOf(inspectedTask.Dependent__c)];
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return hasDependency;
  }

  /**
   * Store the value of the error message
   */
  private String errorMsg;
  /**
   * Getter method to return the error message from action plans utilities
   * @return `String` errorMsg
   * @see ActionPlanTemplateCreationController.errorMsg
   */
  public String getErrorMsg() {
    return errorMsg;
  }

  /**
   * Calculates the highest task index value
   * @return `Double` maxIndex
   */
  public Double calculateTaskIndexValue() {
    Double maxIndex = 0;
    for (APTemplateTask__c tsk : [SELECT Id, TaskIndex__c FROM APTemplateTask__c WHERE Action_Plan_Template__c = :actionPlanTemplate.Id]) {
      if (tsk.TaskIndex__c > maxIndex) {
        maxIndex = tsk.TaskIndex__c;
      }
    }

    return maxIndex;
  }

  /**
   * Find user default recordtype
   * @return `Id` The org default Task RecordTypeId
   * @see ActionPlansUtilities.getDefaultTaskRecordTypeId
   */
  public Id getDefaultTaskRecordTypeId() {
    return ActionPlansUtilities.getDefaultTaskRecordTypeId();
  }

  /**
   * Generate picklist of Task Record Types
   * @return `List<SelectOption>` A picklist of available Record Types
   * @see ActionPlansUtilities.getTaskRTPicklistValues
   */
  public List<SelectOption> getTaskRTPicklistValues() {
    return ActionPlansUtilities.getTaskRTPicklistValues();
  }

  /**
   * Generate picklist of Task Queues
   */
  private List<SelectOption> taskQueueOptions;
  /**
   * Generate a picklist of Task Queues
   * @return `List<SelectOption>` Picklist of Task Queues
   */
  public List<SelectOption> getTaskQueueOptions() {
    if (taskQueueOptions == null) {
      taskQueueOptions = new List<SelectOption>();

      try {
        // Query all queues that can accept Task objects
        List<Group> queues = [
          SELECT Id, Name 
          FROM Group 
          WHERE Type = 'Queue' 
            AND Id IN (
              SELECT QueueId 
              FROM QueueSobject
              WHERE SobjectType = 'Task'
            )
          ORDER BY Name
        ];
        
        for (Group queue : queues) {
          taskQueueOptions.add(new SelectOption(queue.Id, queue.Name));
        }
      } catch (Exception e) {
        System.debug('Error querying Task queues: ' + e.getMessage());
      }
    }
    return taskQueueOptions;
  }

  /**
   * Generate picklist of Task Type
   */
  private List<SelectOption> taskTypes;
  /**
   * Generate a picklist of Task Type
   * @author {@link [David Schach](https://github.com/dschach)}
   * @return `List<SelectOption>` Picklist of `Task.Type`
   * @see ActionPlansUtilities.getFieldOptions
   */
  public List<SelectOption> getTaskTypes() {
    if (taskTypes == null) {
      taskTypes = ActionPlansUtilities.getFieldOptions('Task', 'Type', null);
    }
    return taskTypes;
  }

  /**
   * Generate picklist of Task Priority
   */
  private List<SelectOption> taskPriorities;
  /**
   * Generate picklist of Task Priorities
   * @author {@link [David Schach](https://github.com/dschach)}
   * @return `List<SelectOption>` Picklist of `Task.Priority`
   * @see ActionPlansUtilities.getFieldOptions
   */
  public List<SelectOption> getTaskPriorities() {
    if (taskPriorities == null) {
      taskPriorities = ActionPlansUtilities.getFieldOptions('Task', 'Priority', true);
    }
    return taskPriorities;
  }

  /**
   * Get the reminder time picklist options from the central utilities class
   * @return `List<SelectOption>` Picklist of reminder times
   * @see ActionPlansUtilities.getHoursOption
   */
  public List<SelectOption> getHoursOption() {
    return ActionPlansUtilities.getHoursOption();
  }

  /**
   * Inner Wrapper Class for Action Plan Template Tasks
   * @author {@link [Matias Menafra](https://www.linkedin.com/in/mmenafra)}
   * @date 08/08/2010
   * @author {@link [David Schach](https://github.com/dschach)}
   * @date 05/2021
   */
  public class ApTTaskWrapper {
    /**
     * Action Plan Template Task in wrapper
     * @return   The Action Plan Template Task
     */
    public APTemplateTask__c task { get; set; }
    /**
     * Task position (order on the page)
     * @return  Index
     */
    public Integer position { get; set; }
    /**
     * Last Task
     * @return   Is this AP Task the last in the list?
     */
    public Boolean isLast { get; set; }

    /**
     * Constructor for ActionPlan Template Task Wrapper
     * @param apTask      Action Plan Template Task
     * @param pos         Position/Index
     * @param apTTaskRTId The RecordType of the related Task
     * @see ActionPlansUtilities
     */
    public ApTTaskWrapper(APTemplateTask__c apTask, Integer pos, Id apTTaskRTId) {
      task = apTask;
      position = pos;
      isLast = false;

      Id taskRTID = null;
      if (ActionPlansUtilities.taskUsesRecordTypes) {
        if (ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues().containsKey(apTTaskRTId)) {
          taskRTID = apTTaskRTId;
        } else {
          taskRTID = ActionPlansUtilities.getDefaultTaskRecordTypeId();
        }
      }

      if (task.Id == null && task.Subject__c == null) {
        task.Priority__c = task.Priority__c != null ? task.Priority__c : ActionPlansUtilities.getTaskRecordTypePriorityDefaultValues().get(taskRTID);
        task.Type__c = ActionPlansUtilities.getTaskRecordTypeTypeDefaultValues().get(taskRTID);

        if (ApexPages.currentPage().getParameters().get('clone') != '1') {
          task.Reminder__c = ActionPlansUtilities.getCheckReminderByDefault();
        }
      }
      if (task.Id == null || !task.Reminder__c) {
        task.Minutes_Reminder__c = ActionPlansUtilities.getDefaultReminderMinutes();
      }
    }
  }

  /**
   * Validates the WHERE clause for the template
   * @return PageReference null
   */
  public PageReference validateWhereClause() {
    if (String.isBlank(actionPlanTemplate.Target_Object_API_Name__c)) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Target Object API Name is required when using a WHERE clause'));
      return null;
    }

    if (String.isBlank(actionPlanTemplate.Where_Clause__c)) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Please enter a WHERE clause'));
      return null;
    }

    try {
      // Remove any leading "WHERE" if the user included it
      String whereClause = actionPlanTemplate.Where_Clause__c.trim();
      if (whereClause.startsWithIgnoreCase('WHERE')) {
        whereClause = whereClause.substring(5).trim();
      }

      // Try to run the query to see if the WHERE clause is valid
      String countQuery = 'SELECT COUNT() FROM ' + actionPlanTemplate.Target_Object_API_Name__c + ' WHERE ' + whereClause;
      System.debug('Executing query: ' + countQuery);
      Integer recordCount = Database.countQuery(countQuery);

      if (recordCount > 0) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, recordCount + ' records will be returned by this WHERE clause'));
      } else {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No records found matching this criteria'));
      }
    } catch (Exception e) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Invalid WHERE clause: ' + e.getMessage()));
    }

    return null;
  }

  /**
   * Remote action to validate a custom WHERE clause for a specific object
   *
   * @param whereClause The WHERE clause to validate
   * @param objectName The API name of the object to query
   * @param extractedFields Comma-separated list of fields extracted from the WHERE clause by the client-side parser
   * @return Map<String, Object> with validation results (success, message, count)
   */
  @RemoteAction
  public static Map<String, Object> validateWhereClauseRemote(String whereClause, String objectName, String extractedFields) {
    Map<String, Object> result = new Map<String, Object>{
      'success' => false,
      'message' => '',
      'count' => 0
    };

    System.debug('validateWhereClauseRemote called with clause: ' + whereClause + ' for object: ' + objectName);
    System.debug('Extracted fields from client: ' + extractedFields);

    if (String.isBlank(whereClause)) {
      result.put('message', 'Please enter a WHERE clause');
      return result;
    }

    if (String.isBlank(objectName)) {
      result.put('message', 'Target Object API Name is required');
      return result;
    }

    try {
      // Remove any leading "WHERE" if the user included it
      String cleanWhereClause = whereClause.trim();
      if (cleanWhereClause.startsWithIgnoreCase('WHERE')) {
        cleanWhereClause = cleanWhereClause.substring(5).trim();
      }

      // Try to run the query to see if the WHERE clause is valid
      String countQuery = 'SELECT COUNT() FROM ' + objectName + ' WHERE ' + cleanWhereClause;
      System.debug('Executing query: ' + countQuery);
      Integer recordCount = Database.countQuery(countQuery);
      System.debug('Query returned ' + recordCount + ' records');

      result.put('success', true);
      result.put('count', recordCount);

      if (recordCount > 0) {
        result.put('message', recordCount + ' records will be returned');
      } else {
        result.put('message', 'No records found matching this criteria');
      }

      // Convert extracted fields from relationship notation to SObjectField notation
      if (String.isNotBlank(extractedFields)) {
        // First deduplicate the input fields
        Set<String> uniqueInputFields = new Set<String>();
        for (String field : extractedFields.split(',')) {
          uniqueInputFields.add(field.trim());
        }
        List<String> uniqueInputFieldsList = new List<String>(uniqueInputFields);

        // Then convert the deduplicated fields
        String[] convertedFields = ActionPlansFieldPathFinder.convertToSObjectFields(objectName, uniqueInputFieldsList);
        System.debug('Converted fields: ' + convertedFields);

        // Deduplicate again after conversion to ensure uniqueness
        Set<String> uniqueFields = new Set<String>();
        for (String field : convertedFields) {
          uniqueFields.add(field.trim());
        }
        List<String> uniqueFieldsList = new List<String>(uniqueFields);
        System.debug('Deduplicated fields: ' + uniqueFieldsList);

        // Directly use the Set to ensure uniqueness
        // Convert to lowercase for case-insensitive comparison
        Set<String> caseInsensitiveSet = new Set<String>();
        List<String> finalFieldsList = new List<String>();

        for (String field : convertedFields) {
          String trimmedField = field.trim();
          String lowerField = trimmedField.toLowerCase();

          // Only add if we haven't seen this field before (case-insensitive)
          if (!caseInsensitiveSet.contains(lowerField)) {
            finalFieldsList.add(trimmedField);
            caseInsensitiveSet.add(lowerField);
          }
        }

        System.debug('Final deduplicated fields: ' + finalFieldsList);

        // Join with no spaces between commas to ensure consistent splitting
        String finalResult = String.join(finalFieldsList, ',');
        System.debug('Final result string: ' + finalResult);

        result.put('convertedFields', finalResult);
      }

    } catch (Exception e) {
      result.put('message', 'Invalid WHERE clause: ' + e.getMessage());
      System.debug('Error validating WHERE clause: ' + e.getMessage());
    }

    return result;
  }


  /**
   * Gets all user lookup fields for a given object, including fields up to 5 levels deep
   * @param objectName The API name of the object
   * @return Map<String, String> Map of field API names to field labels
   */
  @RemoteAction
  public static Map<String, String> getUserLookupFieldsRemote(String objectName) {
    Map<String, String> result = new Map<String, String>();

    if (String.isBlank(objectName)) {
      return result;
    }

    try {
      // Get the object's describe result
      Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
      if (objectType == null) {
        return result;
      }

      // Find all user lookup fields up to 5 levels deep
      findUserLookupFields(objectType, '', '', result, 0, 3);
    } catch (Exception e) {
      System.debug('Error getting user lookup fields: ' + e.getMessage());
    }
    System.debug(JSON.serializePretty(result));
    return result;
  }

  /**
   * Gets all user lookup fields for a given object, including fields up to 5 levels deep
   * Returns both field name and relationship name to allow frontend to decide which to use
   * @param objectName The API name of the object
   * @return Map<String, Map<String, Object>> Map of field paths to field details (fieldName, relationshipName, label)
   */
  @RemoteAction
  public static Map<String, Map<String, Object>> getUserLookupFieldsWithRelationshipsRemote(String objectName) {
    Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

    if (String.isBlank(objectName)) {
      return result;
    }

    try {
      // Get the object's describe result
      Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
      if (objectType == null) {
        return result;
      }

      // Find all user lookup fields up to 5 levels deep
      findUserLookupFieldsWithRelationships(objectType, '', '', result, 0, 5);
    } catch (Exception e) {
      System.debug('Error getting user lookup fields with relationships: ' + e.getMessage());
    }
    System.debug(JSON.serializePretty(result));
    return result;
  }

  // =========================
  // SAFE RECURSION CONSTANTS
  // =========================

  // Objects that typically cause massive fanout or noisy recursion
  private static final Set<String> DEFAULT_DENY_OBJECTS = new Set<String>{
    'FeedItem','FeedComment','CaseFeed','UserFeed',
    'ContentDocument','ContentVersion','ContentNote','CombinedAttachment','Note',
    'Task','Event','EmailMessage','ProcessInstance','ProcessInstanceStep'
  };

  // Reasonable cap for highly polymorphic references (to avoid explosion)
  private static final Integer POLYMORPHIC_FANOUT_CAP = 6;

  /**
   * Recursively finds all user lookup fields for a given object, up to a specified depth
   * (Public signature kept; now delegates to safe overload with cycle guards and caps)
   */
  private static void findUserLookupFields(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, String> result,
    Integer currentDepth,
    Integer maxDepth
  ) {
    findUserLookupFields(
      objectType, prefix, labelPrefix, result, currentDepth, maxDepth,
      new Set<String>(), DEFAULT_DENY_OBJECTS, POLYMORPHIC_FANOUT_CAP
    );
  }

  /**
   * Safe overload with cycle guard, denylist, and polymorphic fanout cap
   */
  private static void findUserLookupFields(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, String> result,
    Integer currentDepth,
    Integer maxDepth,
    Set<String> typePath,
    Set<String> denyObjects,
    Integer polymorphicFanoutCap
  ) {
    if (currentDepth >= maxDepth) return;

    String typeName = getCachedObjectDescribe(objectType).getName();
    if ((denyObjects != null && denyObjects.contains(typeName)) || typePath.contains(typeName)) return;

    typePath.add(typeName);
    try {
      Map<String, Schema.SObjectField> fieldMap = getCachedFieldMap(objectType);

      for (Schema.SObjectField f : fieldMap.values()) {
        Schema.DescribeFieldResult fd = f.getDescribe();
        Schema.DisplayType fType = fd.getType();
        String apiName = fd.getName();
        String relName = fd.getRelationshipName();

        // Skip MasterRecord and related
        if (apiName == 'MasterRecordId' || relName == 'MasterRecord') continue;

        // Build path segment (prefer relationship name for first hop)
        String pathPart = apiName;
        if (fType == Schema.DisplayType.REFERENCE && String.isEmpty(prefix) && relName != null) {
          pathPart = relName;
        }
        String fieldPath  = String.isEmpty(prefix) ? pathPart : prefix + '.' + pathPart;
        String fieldLabel = String.isEmpty(labelPrefix) ? fd.getLabel() : labelPrefix + ' → ' + fd.getLabel();

        if (fType != Schema.DisplayType.REFERENCE) continue;

        // Avoid worst polymorphic offenders entirely
        if (apiName == 'WhoId' || apiName == 'WhatId') continue;

        List<Schema.SObjectType> refs = fd.getReferenceTo();
        if (refs == null || refs.isEmpty()) continue;

        // Cap polymorphic fanout
        if (polymorphicFanoutCap != null && refs.size() > polymorphicFanoutCap) {
          Set<String> keep = new Set<String>{'User','Account','Contact','Lead','Case','Opportunity','Group'};
          List<Schema.SObjectType> filtered = new List<Schema.SObjectType>();
          for (Schema.SObjectType rt : refs) {
            if (keep.contains(getCachedObjectDescribe(rt).getName())) filtered.add(rt);
          }
          if (!filtered.isEmpty()) refs = filtered;
        }

        for (Schema.SObjectType rt : refs) {
          if (rt == Schema.User.SObjectType) {
            result.put(fieldPath, fieldLabel);
            break; // don't recurse past User
          }

          String rtName = getCachedObjectDescribe(rt).getName();
          if (rt == objectType || (denyObjects != null && denyObjects.contains(rtName))) continue;

          if (currentDepth < maxDepth - 1) {
            findUserLookupFields(
              rt, fieldPath, fieldLabel, result,
              currentDepth + 1, maxDepth,
              new Set<String>(typePath), denyObjects, polymorphicFanoutCap
            );
          }
        }
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'findUserLookupFields safe error on ' + typeName + ': ' + e.getMessage());
    } finally {
      typePath.remove(typeName);
    }
  }

  /**
   * Recursively finds all user lookup fields for a given object, up to a specified depth
   * Returns both field name and relationship name to allow frontend to decide which to use
   * Uses relationship names for reference fields (e.g., "Account" instead of "AccountId")
   * following the idiomatic Salesforce pattern
   * (Public signature kept; now delegates to safe overload)
   */
  private static void findUserLookupFieldsWithRelationships(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, Map<String, Object>> result,
    Integer currentDepth,
    Integer maxDepth
  ) {
    findUserLookupFieldsWithRelationships(
      objectType, prefix, labelPrefix, result, currentDepth, maxDepth,
      new Set<String>(), DEFAULT_DENY_OBJECTS, POLYMORPHIC_FANOUT_CAP
    );
  }

  /**
   * Safe overload for relationships variant with guards & caps
   */
  private static void findUserLookupFieldsWithRelationships(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, Map<String, Object>> result,
    Integer currentDepth,
    Integer maxDepth,
    Set<String> typePath,
    Set<String> denyObjects,
    Integer polymorphicFanoutCap
  ) {
    if (currentDepth >= maxDepth) return;

    String typeName = getCachedObjectDescribe(objectType).getName();
    if ((denyObjects != null && denyObjects.contains(typeName)) || typePath.contains(typeName)) return;

    typePath.add(typeName);
    try {
      Map<String, Schema.SObjectField> fieldMap = getCachedFieldMap(objectType);

      for (Schema.SObjectField f : fieldMap.values()) {
        Schema.DescribeFieldResult fd = f.getDescribe();
        Schema.DisplayType fType = fd.getType();
        String apiName = fd.getName();
        String relName = fd.getRelationshipName();
        String lbl     = fd.getLabel();

        if (apiName == 'MasterRecordId' || relName == 'MasterRecord') continue;

        String pathPart = (fType == Schema.DisplayType.REFERENCE && relName != null) ? relName : apiName;
        String fieldPath  = String.isEmpty(prefix) ? pathPart : prefix + '.' + pathPart;
        String fieldLabel = String.isEmpty(labelPrefix) ? lbl     : labelPrefix + ' → ' + lbl;

        if (fType != Schema.DisplayType.REFERENCE) continue;

        // Avoid WhoId/WhatId
        if (apiName == 'WhoId' || apiName == 'WhatId') continue;

        List<Schema.SObjectType> refs = fd.getReferenceTo();
        if (refs == null || refs.isEmpty()) continue;

        // Cap polymorphic fanout
        if (polymorphicFanoutCap != null && refs.size() > polymorphicFanoutCap) {
          Set<String> keep = new Set<String>{'User','Account','Contact','Lead','Case','Opportunity','Group'};
          List<Schema.SObjectType> filtered = new List<Schema.SObjectType>();
          for (Schema.SObjectType rt : refs) {
            if (keep.contains(getCachedObjectDescribe(rt).getName())) filtered.add(rt);
          }
          if (!filtered.isEmpty()) refs = filtered;
        }

        for (Schema.SObjectType rt : refs) {
          if (rt == Schema.User.SObjectType) {
            Map<String, Object> details = new Map<String, Object>{
              'fieldName' => apiName,
              'relationshipName' => relName,
              'label' => fieldLabel,
              'isReference' => true
            };

            if (apiName == 'OwnerId' || apiName.endsWith('OwnerId')) {
              details.put('isOwnerField', true);

              // 1) Relationship name form
              result.put(fieldPath, details);

              // 2) Raw Id form
              String idPath = String.isEmpty(prefix) ? apiName : prefix + '.' + apiName;
              Map<String, Object> idDetails = new Map<String, Object>(details);
              idDetails.put('useIdField', true);
              result.put(idPath, idDetails);

              // 3) Relationship.Id
              if (relName != null) {
                String relIdPath = String.isEmpty(prefix) ? relName + '.Id' : prefix + '.' + relName + '.Id';
                Map<String, Object> relIdDetails = new Map<String, Object>(details);
                relIdDetails.put('useRelationshipWithId', true);
                result.put(relIdPath, relIdDetails);
              }
            } else {
              result.put(fieldPath, details);
            }
            // do not recurse past User
            break;
          }

          String rtName = getCachedObjectDescribe(rt).getName();
          if (rt == objectType || (denyObjects != null && denyObjects.contains(rtName))) continue;

          if (currentDepth < maxDepth - 1) {
            findUserLookupFieldsWithRelationships(
              rt, fieldPath, fieldLabel, result,
              currentDepth + 1, maxDepth,
              new Set<String>(typePath), denyObjects, polymorphicFanoutCap
            );
          }
        }
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'findUserLookupFieldsWithRelationships safe error on ' + typeName + ': ' + e.getMessage());
    } finally {
      typePath.remove(typeName);
    }
  }

  /**
   * Gets all date fields for a given object, including fields up to 5 levels deep
   * @param objectName The API name of the object
   * @return Map<String, String> Map of field API names to field labels
   */
  @RemoteAction
  public static Map<String, String> getDateFieldsRemote(String objectName) {
    Map<String, String> result = new Map<String, String>();

    if (String.isBlank(objectName)) {
      return result;
    }

    try {
      // Get the object's describe result
      Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
      if (objectType == null) {
        return result;
      }

      // Find all date fields up to 5 levels deep
      findDateFields(objectType, '', '', result, 0, 3);
    } catch (Exception e) {
      System.debug('Error getting date fields: ' + e.getMessage());
    }

    return result;
  }

  /**
   * Gets all date fields for a given object, including fields up to 5 levels deep
   * Returns both field name and relationship name to allow frontend to decide which to use
   * @param objectName The API name of the object
   * @return Map<String, Map<String, Object>> Map of field paths to field details (fieldName, relationshipName, label)
   */
  @RemoteAction
  public static Map<String, Map<String, Object>> getDateFieldsWithRelationshipsRemote(String objectName) {
    System.debug(LoggingLevel.INFO, '=== RETRIEVING DATE FIELDS WITH RELATIONSHIPS ===');
    System.debug(LoggingLevel.INFO, 'Object name: ' + objectName);

    Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

    if (String.isBlank(objectName)) {
      System.debug(LoggingLevel.INFO, 'Object name is blank, returning empty result');
      return result;
    }

    try {
      // Get the object's describe result
      Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
      if (objectType == null) {
        System.debug(LoggingLevel.INFO, 'Object type not found: ' + objectName);
        return result;
      }

      System.debug(LoggingLevel.INFO, 'Starting field search for object: ' + objectType.getDescribe().getName());

      // Find all date fields up to 5 levels deep
      findDateFieldsWithRelationships(objectType, '', '', result, 0, 5);

      System.debug(LoggingLevel.INFO, 'Found ' + result.size() + ' date fields');
      System.debug(LoggingLevel.INFO, 'Field paths: ' + result.keySet());
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Error getting date fields with relationships: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
    }

    System.debug(LoggingLevel.INFO, '=== END RETRIEVING DATE FIELDS WITH RELATIONSHIPS ===');
    return result;
  }

  /**
   * Cache for SObject describe results to improve performance
   */
  private static Map<String, Schema.DescribeSObjectResult> objectDescribeCache = new Map<String, Schema.DescribeSObjectResult>();

  /**
   * Cache for field maps to improve performance
   */
  private static Map<String, Map<String, Schema.SObjectField>> fieldMapCache = new Map<String, Map<String, Schema.SObjectField>>();

  /**
   * Gets the cached describe result for an SObject type
   * @param objectType The SObjectType to get the describe for
   * @return The cached DescribeSObjectResult
   */
  private static Schema.DescribeSObjectResult getCachedObjectDescribe(Schema.SObjectType objectType) {
    String objectName = String.valueOf(objectType);
    if (!objectDescribeCache.containsKey(objectName)) {
      objectDescribeCache.put(objectName, objectType.getDescribe());
    }
    return objectDescribeCache.get(objectName);
  }

  /**
   * Gets the cached field map for an SObject type
   * @param objectType The SObjectType to get the field map for
   * @return The cached field map
   */
  private static Map<String, Schema.SObjectField> getCachedFieldMap(Schema.SObjectType objectType) {
    String objectName = String.valueOf(objectType);
    if (!fieldMapCache.containsKey(objectName)) {
      Schema.DescribeSObjectResult describeResult = getCachedObjectDescribe(objectType);
      fieldMapCache.put(objectName, describeResult.fields.getMap());
    }
    return fieldMapCache.get(objectName);
  }

  /**
   * Recursively finds all date fields for a given object, up to a specified depth
   * @param objectType The SObjectType to search
   * @param prefix The current field path prefix
   * @param labelPrefix The current label path prefix
   * @param result The map to store results in
   * @param currentDepth The current depth in the recursion
   * @param maxDepth The maximum depth to search
   */
  private static void findDateFields(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, String> result,
    Integer currentDepth,
    Integer maxDepth
  ) {
    if (currentDepth >= maxDepth) {
      return;
    }

    try {
      Schema.DescribeSObjectResult objectDescribe = getCachedObjectDescribe(objectType);
      Map<String, Schema.SObjectField> fieldMap = getCachedFieldMap(objectType);

      // Find all date fields in the current object
      for (String fieldName : fieldMap.keySet()) {
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();

        // Cache field describe method results to avoid repeated calls
        String cachedFieldName = fieldDescribe.getName();
        String cachedRelationshipName = fieldDescribe.getRelationshipName();
        Schema.DisplayType cachedFieldType = fieldDescribe.getType();
        String cachedFieldLabel = fieldDescribe.getLabel();

        // Use the properly cased field name from the describe result
        String pathFieldName = cachedFieldName;

        // Skip MasterRecordId fields
        if (pathFieldName == 'MasterRecordId') {
          continue;
        }

        // Skip MasterRecord relationship fields
        if (cachedRelationshipName == 'MasterRecord') {
          continue;
        }

        // For reference fields in the first part of the path, use relationship name
        // For intermediate parts, use the field name with Id/c suffix
        if (cachedFieldType == Schema.DisplayType.REFERENCE) {
          // If this is the first part of the path (prefix is empty), use relationship name
          if (String.isEmpty(prefix) && cachedRelationshipName != null) {
            pathFieldName = cachedRelationshipName;
          } else {
            // For intermediate parts or if relationship name is null, use field name with Id suffix
            pathFieldName = cachedFieldName;
          }
        }

        String fieldPath = String.isEmpty(prefix) ? pathFieldName : prefix + '.' + pathFieldName;
        String fieldLabel = String.isEmpty(labelPrefix) ? cachedFieldLabel : labelPrefix + ' → ' + cachedFieldLabel;

        // Check if it's a date or datetime field
        if (cachedFieldType == Schema.DisplayType.DATE ||
          cachedFieldType == Schema.DisplayType.DATETIME) {
          result.put(fieldPath, fieldLabel);
        }

        // If it's a lookup field, recursively search the referenced object
        if (cachedFieldType == Schema.DisplayType.REFERENCE && currentDepth < maxDepth - 1) {
          List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
          for (Schema.SObjectType refType : referenceTo) {
            // Skip certain objects that would lead to too many fields or circular references
            String refTypeName = getCachedObjectDescribe(refType).getName();
            if (!refTypeName.equalsIgnoreCase('User') &&
              !refTypeName.equalsIgnoreCase('RecordType') &&
              !refTypeName.equalsIgnoreCase('BusinessHours')) {
              findDateFields(refType, fieldPath, fieldLabel, result, currentDepth + 1, maxDepth);
            }
          }
        }
      }
    } catch (Exception e) {
      System.debug('Error in findDateFields: ' + e.getMessage());
    }
  }

  /**
   * Recursively finds all date fields for a given object, up to a specified depth
   * Returns both field name and relationship name to allow frontend to decide which to use
   * Uses relationship names for reference fields (e.g., "Account" instead of "AccountId")
   * following the idiomatic Salesforce pattern
   * (Public signature kept; now delegates to safe overload with cycle guards and caps)
   * @param objectType The SObjectType to search
   * @param prefix The current field path prefix
   * @param labelPrefix The current label path prefix
   * @param result The map to store results in
   * @param currentDepth The current depth in the recursion
   * @param maxDepth The maximum depth to search
   */
  private static void findDateFieldsWithRelationships(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, Map<String, Object>> result,
    Integer currentDepth,
    Integer maxDepth
  ) {
    findDateFieldsWithRelationships(
      objectType, prefix, labelPrefix, result, currentDepth, maxDepth,
      new Set<String>(), DEFAULT_DENY_OBJECTS, POLYMORPHIC_FANOUT_CAP
    );
  }

  /**
   * Safe overload for date fields with cycle detection, deny list, and polymorphic fanout cap
   */
  private static void findDateFieldsWithRelationships(
    Schema.SObjectType objectType,
    String prefix,
    String labelPrefix,
    Map<String, Map<String, Object>> result,
    Integer currentDepth,
    Integer maxDepth,
    Set<String> typePath,
    Set<String> denyObjects,
    Integer polymorphicFanoutCap
  ) {
    if (currentDepth >= maxDepth) return;

    String typeName = getCachedObjectDescribe(objectType).getName();
    if ((denyObjects != null && denyObjects.contains(typeName)) || typePath.contains(typeName)) return;

    typePath.add(typeName);
    try {
      Map<String, Schema.SObjectField> fieldMap = getCachedFieldMap(objectType);

      for (Schema.SObjectField f : fieldMap.values()) {
        Schema.DescribeFieldResult fd = f.getDescribe();
        Schema.DisplayType fType = fd.getType();
        String apiName = fd.getName();
        String relName = fd.getRelationshipName();
        String lbl = fd.getLabel();

        // Skip MasterRecord and related
        if (apiName == 'MasterRecordId' || relName == 'MasterRecord') continue;

        // Build path segment (prefer relationship name for reference fields)
        String pathPart = (fType == Schema.DisplayType.REFERENCE && relName != null) ? relName : apiName;
        String fieldPath = String.isEmpty(prefix) ? pathPart : prefix + '.' + pathPart;
        String fieldLabel = String.isEmpty(labelPrefix) ? lbl : labelPrefix + ' → ' + lbl;

        // Check if it's a date or datetime field
        if (fType == Schema.DisplayType.DATE || fType == Schema.DisplayType.DATETIME) {
          Map<String, Object> fieldDetails = new Map<String, Object>{
            'fieldName' => apiName,
            'relationshipName' => relName,
            'label' => fieldLabel,
            'isReference' => (fType == Schema.DisplayType.REFERENCE)
          };
          result.put(fieldPath, fieldDetails);
        }

        // If it's a reference field, recursively search the referenced object
        if (fType == Schema.DisplayType.REFERENCE && currentDepth < maxDepth - 1) {
          // Avoid worst polymorphic offenders entirely
          if (apiName == 'WhoId' || apiName == 'WhatId') continue;

          List<Schema.SObjectType> refs = fd.getReferenceTo();
          if (refs == null || refs.isEmpty()) continue;

          // Cap polymorphic fanout
          if (polymorphicFanoutCap != null && refs.size() > polymorphicFanoutCap) {
            Set<String> keep = new Set<String>{'User','Account','Contact','Lead','Case','Opportunity','Group'};
            List<Schema.SObjectType> filtered = new List<Schema.SObjectType>();
            for (Schema.SObjectType rt : refs) {
              if (keep.contains(getCachedObjectDescribe(rt).getName())) filtered.add(rt);
            }
            if (!filtered.isEmpty()) refs = filtered;
          }

          for (Schema.SObjectType rt : refs) {
            String rtName = getCachedObjectDescribe(rt).getName();
            if (rt == objectType || (denyObjects != null && denyObjects.contains(rtName))) continue;

            findDateFieldsWithRelationships(
              rt, fieldPath, fieldLabel, result,
              currentDepth + 1, maxDepth,
              new Set<String>(typePath), denyObjects, polymorphicFanoutCap
            );
          }
        }
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'findDateFieldsWithRelationships safe error on ' + typeName + ': ' + e.getMessage());
    } finally {
      typePath.remove(typeName);
    }
  }

  /**
   * Validates a related field path
   * Can handle field paths with both field names and relationship names
   * (e.g., both "AccountId.OwnerId.Name" and "Account.Owner.Name" are valid)
   * @param objectName The API name of the starting object
   * @param fieldPath The field path to validate (e.g., "Account.Owner.Name")
   * @return Map<String, Object> with validation results (success, message)
   */
  @RemoteAction
  public static Map<String, Object> validateFieldPathRemote(String objectName, String fieldPath) {
    // Debug: Log input parameters
    System.debug(LoggingLevel.INFO, '=== FIELD PATH VALIDATION ===');
    System.debug(LoggingLevel.INFO, 'Validating field path: ' + fieldPath + ' on object: ' + objectName);

    Map<String, Object> result = new Map<String, Object>{
      'success' => false,
      'message' => '',
      'fieldType' => ''
    };

    if (String.isBlank(objectName) || String.isBlank(fieldPath)) {
      System.debug(LoggingLevel.INFO, 'Validation failed: Object name or field path is blank');
      result.put('message', 'Object name and field path are required');
      return result;
    }

    try {
      // Split the field path into parts
      List<String> pathParts = fieldPath.split('\\.');
      System.debug(LoggingLevel.INFO, 'Field path parts: ' + pathParts);

      // Start with the initial object
      Schema.SObjectType currentType = Schema.getGlobalDescribe().get(objectName);
      if (currentType == null) {
        System.debug(LoggingLevel.INFO, 'Validation failed: Invalid object: ' + objectName);
        result.put('message', 'Invalid object: ' + objectName);
        return result;
      }
      System.debug(LoggingLevel.INFO, 'Starting object type: ' + getCachedObjectDescribe(currentType).getName());

      Schema.SObjectType finalType;
      Schema.DisplayType finalFieldType;
      String finalFieldLabel = '';

      // Traverse the path
      for (Integer i = 0; i < pathParts.size(); i++) {
        String part = pathParts[i];
        Schema.DescribeSObjectResult currentDescribe = getCachedObjectDescribe(currentType);
        Map<String, Schema.SObjectField> fieldMap = getCachedFieldMap(currentType);

        System.debug(LoggingLevel.INFO, 'Processing path part [' + i + ']: ' + part + ' on object: ' + currentDescribe.getName());

        // Check if the field exists - either by field name or relationship name
        Schema.DescribeFieldResult fieldDescribe;

        if (fieldMap.containsKey(part)) {
          // Direct match by field name
          fieldDescribe = fieldMap.get(part).getDescribe();
          System.debug(LoggingLevel.INFO, 'Found field by direct field name match: ' + fieldDescribe.getName());
        } else {
          // Try to find by relationship name
          Boolean found = false;
          for (String fieldKey : fieldMap.keySet()) {
            Schema.DescribeFieldResult tempDescribe = fieldMap.get(fieldKey).getDescribe();
            String tempRelationshipName = tempDescribe.getRelationshipName();
            if (tempRelationshipName == part) {
              fieldDescribe = tempDescribe;
              found = true;
              System.debug(LoggingLevel.INFO, 'Found field by relationship name match: ' + fieldDescribe.getName() +
                ' (relationship name: ' + tempRelationshipName + ')');
              break;
            }
          }

          if (!found) {
            System.debug(LoggingLevel.INFO, 'Validation failed: Field not found: ' + part + ' on object ' + currentDescribe.getName());
            result.put('message', 'Field not found: ' + part + ' on object ' + currentDescribe.getName());
            return result;
          }
        }

        // Cache field describe method results
        Schema.DisplayType cachedFieldType = fieldDescribe.getType();
        String cachedFieldName = fieldDescribe.getName();
        String cachedFieldLabel = fieldDescribe.getLabel();

        // If this is the last part, check if it's the right type
        if (i == pathParts.size() - 1) {
          finalFieldType = cachedFieldType;
          finalFieldLabel = cachedFieldLabel;
          System.debug(LoggingLevel.INFO, 'Final field: ' + cachedFieldName + ', Type: ' + finalFieldType + ', Label: ' + finalFieldLabel);

          // For user lookup validation
          if (finalFieldType == Schema.DisplayType.REFERENCE) {
            List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
            if (referenceTo.isEmpty() || referenceTo[0] != Schema.User.SObjectType) {
              System.debug(LoggingLevel.INFO, 'Validation failed: Field is not a User lookup: ' + part);
              result.put('message', 'Field is not a User lookup: ' + part);
              return result;
            }
            finalType = Schema.User.SObjectType;
            System.debug(LoggingLevel.INFO, 'Valid User lookup field found: ' + cachedFieldName);
          }
          // For date field validation
          else if (finalFieldType != Schema.DisplayType.DATE && finalFieldType != Schema.DisplayType.DATETIME) {
            System.debug(LoggingLevel.INFO, 'Validation failed: Field is not a Date or DateTime: ' + part + ', Actual type: ' + finalFieldType);
            result.put('message', 'Field is not a Date or DateTime: ' + part);
            return result;
          } else {
            System.debug(LoggingLevel.INFO, 'Valid Date/DateTime field found: ' + cachedFieldName);
          }
        }
        // If not the last part, it must be a lookup field
        else if (cachedFieldType != Schema.DisplayType.REFERENCE) {
          System.debug(LoggingLevel.INFO, 'Validation failed: Field is not a lookup: ' + part + ', Actual type: ' + cachedFieldType);
          result.put('message', 'Field is not a lookup: ' + part);
          return result;
        }
        // Move to the next object in the path
        else {
          List<Schema.SObjectType> referenceTo = fieldDescribe.getReferenceTo();
          if (referenceTo.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'Validation failed: Field does not reference any object: ' + part);
            result.put('message', 'Field does not reference any object: ' + part);
            return result;
          }
          currentType = referenceTo[0];
          System.debug(LoggingLevel.INFO, 'Moving to referenced object: ' + getCachedObjectDescribe(currentType).getName());
        }
      }

      result.put('success', true);
      result.put('message', 'Valid field path: ' + fieldPath);
      result.put('fieldType', String.valueOf(finalFieldType));
      result.put('fieldLabel', finalFieldLabel);

      if (finalType == Schema.User.SObjectType) {
        result.put('isUserLookup', true);
        System.debug(LoggingLevel.INFO, 'Field path validated as User lookup: ' + fieldPath);
      } else {
        result.put('isUserLookup', false);
        System.debug(LoggingLevel.INFO, 'Field path validated as Date/DateTime field: ' + fieldPath);
      }

      System.debug(LoggingLevel.INFO, 'Validation successful: ' + result);
      System.debug(LoggingLevel.INFO, '=== END FIELD PATH VALIDATION ===');
    } catch (Exception e) {
      result.put('message', 'Error validating field path: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'Exception during field path validation: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      System.debug(LoggingLevel.INFO, '=== END FIELD PATH VALIDATION (ERROR) ===');
    }

    return result;
  }

  /**
   * Updates the user lookup fields and date fields when the Target Object API Name changes
   */
  public PageReference updateFieldsForTargetObject() {
    if (String.isBlank(actionPlanTemplate.Target_Object_API_Name__c)) {
      userLookupFields = new Map<String, String>();
      dateFields = new Map<String, String>();
      return null;
    }

    userLookupFields = getUserLookupFieldsRemote(actionPlanTemplate.Target_Object_API_Name__c);
    dateFields = getDateFieldsRemote(actionPlanTemplate.Target_Object_API_Name__c);

    return null;
  }
}