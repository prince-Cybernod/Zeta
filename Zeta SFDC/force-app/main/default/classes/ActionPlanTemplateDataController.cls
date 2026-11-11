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
 * Lightning Web Component controller for Action Plan Template data operations
 * Handles CRUD operations for templates and template tasks
 * @since v4
 * @author David Schach
 * @group Lightning
 */
public with sharing class ActionPlanTemplateDataController {

  /**
   * Wrapper class for template task data
   */
  public class TaskWrapper {
    @AuraEnabled public APTemplateTask__c task { get; set; }
    @AuraEnabled public Integer position { get; set; }
    @AuraEnabled public Boolean isLast { get; set; }

    public TaskWrapper(APTemplateTask__c apTask, Integer pos) {
      this.task = apTask;
      this.position = pos;
      this.isLast = false;
      
      if (this.task.Id == null) {
        this.task.TaskIndex__c = pos;
        this.task.DaysFromStart__c = pos == 0 ? 0 : 1;
      }
    }
  }

  /**
   * Gets template data including template record and tasks
   * @param templateId The ID of the template to load
   * @param isClone Whether this is a clone operation
   * @return Map<String, Object> containing template data and metadata
   */
  @AuraEnabled
  public static Map<String, Object> getTemplateData(Id templateId, Boolean isClone) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
      ActionPlanTemplate__c template;
      List<APTemplateTask__c> templateTasks = new List<APTemplateTask__c>();
      
      if (templateId != null && !isClone) {
        // Load existing template - use dynamic query to handle optional Fallback_Queue__c field
        String templateFields = 'Id, Name, Description__c, SkipDay__c, SkipWeekends__c, TaskRecordTypeID__c, Target_Object_API_Name__c, Where_Clause__c';
        
        // Check if Fallback_Queue__c field exists and add it
        Schema.SObjectType templateType = Schema.ActionPlanTemplate__c.getSObjectType();
        Map<String, Schema.SObjectField> templateFieldMap = templateType.getDescribe().fields.getMap();
        if (templateFieldMap.containsKey('fallback_queue__c')) {
          templateFields += ', Fallback_Queue__c';
        }
        
        String query = 'SELECT ' + templateFields + ' FROM ActionPlanTemplate__c WHERE Id = :templateId LIMIT 1';
        List<ActionPlanTemplate__c> templates = Database.query(query);
        template = templates.isEmpty() ? null : templates[0];
        
        templateTasks = [
          SELECT Id, Subject__c, Type__c, Priority__c, Comments__c, Reminder__c,
                 SendEmail__c, DaysFromStart__c, Dependent__c,
                 TController__c, TaskIndex__c, Minutes_Reminder__c, User__c,
                 DueDateType__c, StaticDueDate__c, DueDateRelatedField__c,
                 UserType__c, UserRelatedField__c
          FROM APTemplateTask__c 
          WHERE Action_Plan_Template__c = :templateId 
          ORDER BY TaskIndex__c ASC
        ];
      } else if (templateId != null && isClone) {
        // Clone template - use dynamic query to handle optional Fallback_Queue__c field
        String templateFields = 'Name, Description__c, SkipDay__c, SkipWeekends__c, TaskRecordTypeID__c, Target_Object_API_Name__c, Where_Clause__c';
        
        // Check if Fallback_Queue__c field exists and add it
        Schema.SObjectType templateType = Schema.ActionPlanTemplate__c.getSObjectType();
        Map<String, Schema.SObjectField> templateFieldMap = templateType.getDescribe().fields.getMap();
        if (templateFieldMap.containsKey('fallback_queue__c')) {
          templateFields += ', Fallback_Queue__c';
        }
        
        String query = 'SELECT ' + templateFields + ' FROM ActionPlanTemplate__c WHERE Id = :templateId LIMIT 1';
        List<ActionPlanTemplate__c> originalTemplates = Database.query(query);
        ActionPlanTemplate__c originalTemplate = originalTemplates.isEmpty() ? null : originalTemplates[0];
        
        template = new ActionPlanTemplate__c();
        template.Name = originalTemplate.Name;
        template.Description__c = originalTemplate.Description__c;
        template.SkipDay__c = originalTemplate.SkipDay__c;
        template.SkipWeekends__c = originalTemplate.SkipWeekends__c;
        template.TaskRecordTypeID__c = originalTemplate.TaskRecordTypeID__c;
        template.Target_Object_API_Name__c = originalTemplate.Target_Object_API_Name__c;
        template.Where_Clause__c = originalTemplate.Where_Clause__c;
        
        // Conditionally set Fallback_Queue__c if it exists
        if (templateFieldMap.containsKey('fallback_queue__c') && originalTemplate.get('Fallback_Queue__c') != null) {
          template.put('Fallback_Queue__c', originalTemplate.get('Fallback_Queue__c'));
        }
        
        List<APTemplateTask__c> originalTasks = [
          SELECT Subject__c, Type__c, Priority__c, Comments__c, Reminder__c,
                 SendEmail__c, DaysFromStart__c, Dependent__c,
                 TController__c, TaskIndex__c, Minutes_Reminder__c, User__c,
                 DueDateType__c, StaticDueDate__c, DueDateRelatedField__c,
                 UserType__c, UserRelatedField__c
          FROM APTemplateTask__c 
          WHERE Action_Plan_Template__c = :templateId 
          ORDER BY TaskIndex__c ASC
        ];
        
        for (APTemplateTask__c originalTask : originalTasks) {
          APTemplateTask__c clonedTask = originalTask.clone(false, false, false, false);
          templateTasks.add(clonedTask);
        }
      } else {
        // New template
        template = new ActionPlanTemplate__c();
      }
      
      // If no tasks exist, create a default task
      if (templateTasks.isEmpty()) {
        templateTasks.add(new APTemplateTask__c(
          TaskIndex__c = 0,
          DaysFromStart__c = 0
        ));
      }
      
      result.put('template', template);
      result.put('tasks', templateTasks);
      result.put('canDisplayReminder', ActionPlansUtilities.getCanDisplayReminder());
      result.put('taskHasRecordType', ActionPlansUtilities.taskUsesRecordTypes);
      result.put('dueDateTypeOptions', getDueDateTypeOptions());
      result.put('taskTypes', getTaskTypeOptions());
      result.put('taskPriorities', getTaskPriorityOptions());
      result.put('hoursOptions', getHoursOptions());
      result.put('taskRecordTypes', getTaskRecordTypeOptions());
      
    } catch (Exception e) {
      result.put('error', e.getMessage());
      System.debug('Error in getTemplateData: ' + e.getMessage());
    }
    
    return result;
  }

  /**
   * Saves the template and its tasks
   * @param templateData The template record data
   * @param tasksData The list of task records data
   * @return Map<String, Object> containing save results
   */
  @AuraEnabled
  public static Map<String, Object> saveTemplate(Object templateData, Object tasksData) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
      // Deserialize template data
      ActionPlanTemplate__c template = (ActionPlanTemplate__c) JSON.deserialize(
        JSON.serialize(templateData), ActionPlanTemplate__c.class
      );
      
      // Deserialize tasks data
      List<APTemplateTask__c> tasks = (List<APTemplateTask__c>) JSON.deserialize(
        JSON.serialize(tasksData), List<APTemplateTask__c>.class
      );
      
      // Validate template
      if (String.isBlank(template.Name)) {
        result.put('success', false);
        result.put('message', 'Template name is required');
        return result;
      }
      
      // Save template
      upsert template;
      
      // Update tasks with template ID
      for (APTemplateTask__c task : tasks) {
        task.Action_Plan_Template__c = template.Id;
      }
      
      // Delete existing tasks if updating
      if (template.Id != null) {
        List<APTemplateTask__c> existingTasks = [
          SELECT Id FROM APTemplateTask__c 
          WHERE Action_Plan_Template__c = :template.Id
        ];
        if (!existingTasks.isEmpty()) {
          delete existingTasks;
        }
      }
      
      // Insert new tasks
      if (!tasks.isEmpty()) {
        insert tasks;
      }
      
      result.put('success', true);
      result.put('templateId', template.Id);
      result.put('message', 'Template saved successfully');
      
    } catch (Exception e) {
      result.put('success', false);
      result.put('message', e.getMessage());
      System.debug('Error in saveTemplate: ' + e.getMessage());
    }
    
    return result;
  }

  /**
   * Gets picklist options for due date types
   * @return List<Map<String, Object>> List of options
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getDueDateTypeOptions() {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    options.add(new Map<String, Object>{'label' => 'Assigned Date', 'value' => 'AssignedDate'});
    options.add(new Map<String, Object>{'label' => 'Dependent Task Due Date', 'value' => 'DependentDueDate'});
    options.add(new Map<String, Object>{'label' => 'Object date field', 'value' => 'DateField'});
    options.add(new Map<String, Object>{'label' => 'User sets a static date', 'value' => 'StaticDate'});
    return options;
  }

  /**
   * Gets picklist options for task types
   * @return List<Map<String, Object>> List of options
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getTaskTypeOptions() {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    
    try {
      Schema.DescribeFieldResult fieldResult = Task.Type.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
      
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive()) {
          options.add(new Map<String, Object>{
            'label' => entry.getLabel(),
            'value' => entry.getValue()
          });
        }
      }
    } catch (Exception e) {
      System.debug('Error getting task type options: ' + e.getMessage());
    }
    
    return options;
  }

  /**
   * Gets picklist options for task priorities
   * @return List<Map<String, Object>> List of options
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getTaskPriorityOptions() {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    
    try {
      Schema.DescribeFieldResult fieldResult = Task.Priority.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
      
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive()) {
          options.add(new Map<String, Object>{
            'label' => entry.getLabel(),
            'value' => entry.getValue()
          });
        }
      }
    } catch (Exception e) {
      System.debug('Error getting task priority options: ' + e.getMessage());
    }
    
    return options;
  }

  /**
   * Gets options for hours selection
   * @return List<Map<String, Object>> List of options
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getHoursOptions() {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    
    for (Integer i = 0; i <= 23; i++) {
      String hourStr = String.valueOf(i).leftPad(2, '0');
      options.add(new Map<String, Object>{
        'label' => hourStr,
        'value' => hourStr
      });
    }
    
    return options;
  }

  /**
   * Gets task record type options
   * @return List<Map<String, Object>> List of options
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getTaskRecordTypeOptions() {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    
    try {
      List<SelectOption> selectOptions = ActionPlansUtilities.getTaskRTPicklistValues();
      
      for (SelectOption option : selectOptions) {
        options.add(new Map<String, Object>{
          'label' => option.getLabel(),
          'value' => option.getValue()
        });
      }
    } catch (Exception e) {
      System.debug('Error getting task record type options: ' + e.getMessage());
    }
    
    return options;
  }

  /**
   * Validates template for cyclic dependencies
   * @param tasksData The list of task records data
   * @return Map<String, Object> containing validation results
   */
  @AuraEnabled
  public static Map<String, Object> validateCyclicDependency(Object tasksData) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
      List<APTemplateTask__c> tasks = (List<APTemplateTask__c>) JSON.deserialize(
        JSON.serialize(tasksData), List<APTemplateTask__c>.class
      );
      
      // Simple validation - check for self-referencing dependencies
      Boolean hasCycle = false;
      for (APTemplateTask__c task : tasks) {
        if (task.Dependent__c != null && task.TaskIndex__c != null) {
          if (String.valueOf(task.TaskIndex__c) == task.Dependent__c) {
            hasCycle = true;
            break;
          }
        }
      }
      
      result.put('success', true);
      result.put('hasCycle', hasCycle);
      
      if (hasCycle) {
        result.put('message', 'Cyclic dependency detected in tasks');
      } else {
        result.put('message', 'No cyclic dependencies found');
      }
      
    } catch (Exception e) {
      result.put('success', false);
      result.put('message', e.getMessage());
      System.debug('Error in validateCyclicDependency: ' + e.getMessage());
    }
    
    return result;
  }

  /**
   * Gets the default task record type ID
   * @return String The default record type ID
   */
  @AuraEnabled(Cacheable=true)
  public static String getDefaultTaskRecordTypeId() {
    try {
      return ActionPlansUtilities.getDefaultTaskRecordTypeId();
    } catch (Exception e) {
      System.debug('Error getting default task record type: ' + e.getMessage());
    }
    return null;
  }

  /**
   * Gets template subject options for dependent tasks
   * @param tasksData The current list of tasks
   * @return List<Map<String, Object>> List of subject options
   */
  @AuraEnabled
  public static List<Map<String, Object>> getTemplateSubjectOptions(Object tasksData) {
    List<Map<String, Object>> options = new List<Map<String, Object>>();
    
    try {
      List<APTemplateTask__c> tasks = (List<APTemplateTask__c>) JSON.deserialize(
        JSON.serialize(tasksData), List<APTemplateTask__c>.class
      );
      
      options.add(new Map<String, Object>{
        'label' => '--None--',
        'value' => ''
      });
      
      for (APTemplateTask__c task : tasks) {
        if (String.isNotBlank(task.Subject__c)) {
          options.add(new Map<String, Object>{
            'label' => task.Subject__c,
            'value' => String.valueOf(task.TaskIndex__c)
          });
        }
      }
    } catch (Exception e) {
      System.debug('Error getting template subject options: ' + e.getMessage());
    }
    
    return options;
  }

  /**
   * Creates a new task wrapper
   * @param position The position for the new task
   * @return Map<String, Object> containing the new task wrapper
   */
  @AuraEnabled
  public static Map<String, Object> createNewTask(Integer position) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
      APTemplateTask__c newTask = new APTemplateTask__c(
        TaskIndex__c = position,
        DaysFromStart__c = position == 0 ? 0 : 1,
        Priority__c = 'Normal',
        Type__c = 'Other',
        SendEmail__c = false,
        Reminder__c = false,
        UserType__c = 'TemplateOwner',
        DueDateType__c = 'AssignedDate'
      );
      
      // Note: Task record type is handled at the template level, not individual task level
      
      TaskWrapper wrapper = new TaskWrapper(newTask, position);
      result.put('success', true);
      result.put('task', wrapper);
      
    } catch (Exception e) {
      result.put('success', false);
      result.put('message', e.getMessage());
      System.debug('Error creating new task: ' + e.getMessage());
    }
    
    return result;
  }
}