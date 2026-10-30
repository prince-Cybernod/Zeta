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
 * @author {@link [David Schach](https://github.com/dschach)}
 * @group Visualforce
 * @since 2022
 */
public with sharing class ActionPlanTemplateDetailController {
  @TestVisible
  private ActionPlanTemplate__c actionPlanTemplate;
  /**
   * The Id of the Action Plan for Exporting. Shown on the Export page that shares this controller
   */
  public Id actionPlanExportXMLId { get; private set; }
  /**
   * Does the org use Task RecordType?
   */
  public Boolean taskHasRecordType { get; private set; }
  /**
   * Does the user have reminders enabled?
   */
  public Boolean canDisplayReminder { get; private set; }
  
  /**
   * List of SObject information for Trigger Fields
   */
  public List<Map<String, Object>> triggerFieldSObjects { get; private set; }

  /**
   * Constructor
   * <br>If we can obtain the Id from the page parameters then we search for that template and set the variable for that template.
   * <br>If we can't obtain the Id from the page parameters then we create a new template and obtain from the controller.
   * @param stdController Standard Controller (Action Plan Template)
   * @see ActionPlansUtilities.getCanDisplayReminder
   */
  public ActionPlanTemplateDetailController(ApexPages.StandardController stdController) {
    actionPlanTemplate = (ActionPlanTemplate__c) stdController.getRecord();
    taskHasRecordType = ActionPlansUtilities.taskUsesRecordTypes;
    canDisplayReminder = ActionPlansUtilities.getCanDisplayReminder();
  }

  /**
   * Action on page load to ensure custom setting is created
   * Also initializes the triggerFieldSObjects property
   * @return   `PageReference` null (required for page actions method)
   * @see ActionPlansUtilities.onPageLoad
   */
  public PageReference onLoad() {
    ActionPlansUtilities.onPageLoad();
    
    // Initialize the triggerFieldSObjects property
    initializeTriggerFieldSObjects();
    
    return null;
  }
  
  /**
   * Initialize the triggerFieldSObjects property by extracting unique SObjects from Trigger Fields
   * and always including the Target Object API Name
   */
  private void initializeTriggerFieldSObjects() {
    triggerFieldSObjects = new List<Map<String, Object>>();
    
    if (actionPlanTemplate == null) {
      return;
    }
    
    // Get unique SObjects from Trigger Fields
    Set<String> uniqueSObjects = new Set<String>();
    if (String.isNotBlank(actionPlanTemplate.Trigger_Fields__c)) {
      uniqueSObjects = ActionPlanTriggerGenerator.getUniqueSObjectsFromTriggerFields(actionPlanTemplate.Trigger_Fields__c);
    }
    
    // Always add the Target Object API Name if it exists
    if (String.isNotBlank(actionPlanTemplate.Target_Object_API_Name__c)) {
      uniqueSObjects.add(actionPlanTemplate.Target_Object_API_Name__c);
    }
    
    // Get SObject information for each unique SObject
    for (String sObjectName : uniqueSObjects) {
      Map<String, Object> sObjectInfo = ActionPlanTriggerGenerator.getSObjectInfo(sObjectName);
      triggerFieldSObjects.add(sObjectInfo);
    }
  }
  
  /**
   * Generate and deploy a trigger for the given SObject
   * @param sObjectName API name of the SObject
   * @param customTestCode Optional custom test code to use instead of default
   * @return Deployment result message
   */
  @AuraEnabled
  @RemoteAction
  public static String generateAndDeployTrigger(String sObjectName, String customTestCode) {
    return ActionPlanTriggerGenerator.createAndDeployTrigger(sObjectName, customTestCode);
  }
  
  /**
   * Check the status of a deployment
   * @param asyncResultId ID of the async result
   * @return Deployment status message
   */
  @AuraEnabled
  @RemoteAction
  public static String checkDeployStatus(String asyncResultId) {
    return ActionPlanTriggerGenerator.checkDeployStatus(asyncResultId);
  }

  /**
   * Convert Record Type Id to Record Type Name
   * @return `String` Record Type Name
   */
  public String getRecordTypeName() {
    String toReturn = '';

    if (taskHasRecordType && actionPlanTemplate.TaskRecordTypeID__c != null) {
      Map<Id, Schema.RecordTypeInfo> rtMapById = Task.SObjectType.getDescribe().getRecordTypeInfosById();
      if (!rtMapById.isEmpty() && rtMapById.containsKey(actionPlanTemplate.TaskRecordTypeID__c)) {
        return rtMapById.get(actionPlanTemplate.TaskRecordTypeID__c).getName();
      }
    }
    return toReturn;
  }

  /**
   * Get Fallback Queue Name from Queue ID
   * @return `String` Queue Name
   */
  public String getFallbackQueueName() {
    String queueName = '';
    
    if (actionPlanTemplate != null && actionPlanTemplate.Id != null) {
      try {
        // Get the template ID for the query
        Id templateId = actionPlanTemplate.Id;
        
        // Build the SOQL query with namespace prefix
        String fallbackQueueField = ActionPlansUtilities.namespacePrefix + 'Fallback_Queue__c';
        String query = 'SELECT ' + fallbackQueueField + ' FROM ' + 
                      ActionPlansUtilities.namespacePrefix + 'ActionPlanTemplate__c WHERE Id = :templateId LIMIT 1';
        
        List<SObject> templates = Database.query(query);
        
        if (!templates.isEmpty()) {
          String queueId = (String) templates[0].get(fallbackQueueField);
          
          if (String.isNotBlank(queueId)) {
            // Query the queue to get its name
            List<Group> queues = [
              SELECT Id, Name 
              FROM Group 
              WHERE Id = :queueId 
                AND Type = 'Queue'
              LIMIT 1
            ];
            
            if (!queues.isEmpty()) {
              queueName = queues[0].Name;
            }
          }
        }
      } catch (Exception e) {
        System.debug('Error querying queue name: ' + e.getMessage());
      }
    }
    
    return queueName;
  }

  /**
   * Delete the template
   * @return `PageReference` Action Plan Template home tab
   */
  public PageReference deleteTemplate() {
    try {
      delete actionPlanTemplate;
    } catch (Exception e) {
      ApexPages.addMessages(e);
      return null;
    }

    // Send the user to the detail page for the new account.
    PageReference newPage = new PageReference('/' + Schema.ActionPlanTemplate__c.SObjectType.getDescribe().getKeyPrefix() + '/o');
    newPage.setRedirect(true);

    return newPage;
  }

  /**
   * Query Template Tasks
   * @return `List<APTemplateTask__c>` The Template Tasks
   */
  public List<APTemplateTask__c> getTemplateTasks() {
    return [
      SELECT
        Subject__c,
        Priority__c,
        Dependent__c,
        Name,
        User__c,
        TaskIndex__c,
        Type__c,
        Time_Reminder__c,
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
      WHERE Action_Plan_Template__c = :actionPlanTemplate.Id
      ORDER BY TaskIndex__c ASC NULLS FIRST
    ];
  }

  /**
   * Query Action Plans related to this template
   * @return `List<ActionPlan__c>` The Action Plans
   */
  public List<ActionPlan__c> getActionPlans() {
    List<ActionPlan__c> apList = [
      SELECT 
        Id, Name, Related_Record__c, Related_Object__c, 
        Task_Status_Formula__c, StartDate__c, Description__c,
        CreatedDate
      FROM ActionPlan__c 
      WHERE Action_Plan_Template__c = :actionPlanTemplate.Id
      ORDER BY CreatedDate DESC
      LIMIT 200
    ];
    
    return apList;
  }

  /**
   * Method exports the Action Plan template into a new XML document
   * @see ActionPlanTemplateExport
   */
  public void exportTemplateToXMLDoc() {
    ActionPlanTemplateExport utility = new ActionPlanTemplateExport(actionPlanTemplate.Id);
    actionPlanExportXMLId = utility.export();
  }

  /**
   * Determine the export success message based on LEX vs Classic
   * @return      `String` The success message
   * @see ActionPlansUtilities.getIsLex
   */
  public String getSuccessMessage() {
    Boolean isLex = ActionPlansUtilities.getIsLex();
    String fileLabel = '';
    String docLabel = '';

    List<Schema.DescribeTabSetResult> tabSetDesc = Schema.describeTabs();
    for (DescribeTabSetResult tsr : tabSetDesc) {
      List<Schema.DescribeTabResult> tabDesc = tsr.getTabs();
      for (Schema.DescribeTabResult tr : tabDesc) {
        if (tr.getSobjectName() == 'File' && !tr.isCustom()) {
          fileLabel = tr.getLabel();
        }
        if (tr.getSobjectName() == 'Document' && !tr.isCustom()) {
          docLabel = tr.getLabel();
        }
        if (docLabel != '' && fileLabel != '') {
          break;
        }
      }
    }

    String destinationName = isLex ? fileLabel : docLabel;

    List<String> parameters = new List<String>();
    parameters.add(destinationName);
    return String.format(System.Label.ap_XMLSuccess, parameters);
  }

  /**
   * If we have no share object, we don't need to show a Share button
   * <br>Also validate user permission to share
   * @author {@link [David Schach](https://github.com/dschach)}
   * @return   `Boolean` Does the user have permission to share this Action Plan Template?
   * @see ActionPlansUtilities.canShareRecord
   */
  public Boolean getCanShare() {
    return ActionPlansUtilities.canShareRecord(actionPlanTemplate.Id, actionPlanTemplate.OwnerId);
  }

  /**
   * Does the user have permission to transfer? We query `UserRecordAccess` to find out.
   * @author {@link [David Schach](https://github.com/dschach)}
   * @return   `Boolean` Does the user have permission to transfer this Action Plan Template?
   * @see ActionPlansUtilities.getCanTransfer
   */
  public Boolean getCanTransfer() {
    return ActionPlansUtilities.getCanTransfer(actionPlanTemplate.Id);
  }
}