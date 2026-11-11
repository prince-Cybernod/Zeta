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
 * Builder Utilities class
 * @author {@link [Rodrigo Birriel](https://www.linkedin.com/in/rbirriel)}
 * @author {@link [David Schach](https://github.com/dschach)}
 * @group Utilities
 * @since v3
 * @see ActionPlanCreateInvocable
 * @see ActionPlanCreationController
 * @see ActionPlansQueueableBuilder
 */
public inherited sharing class ActionPlansBuilderUtilities {
  // Holds current APTemplateTask context during owner resolution for fallback handling
  private static APTemplateTask__c currentTemplateTaskForFallback;

  /**
   * Static cache for resolved field path values to prevent "Too many SOQL queries"
   * Key format: objectType + '-' + recordId + '-' + fieldPath
   */
  private static Map<String, Object> fieldPathCache = new Map<String, Object>();

  /**
   * Cache for hydrated APTemplateTask__c records
   */
  private static Map<Id, APTemplateTask__c> hydratedTasksCache = new Map<Id, APTemplateTask__c>();

  /**
   * Cache for hydrated ActionPlanTemplate__c records
   */
  private static Map<Id, ActionPlanTemplate__c> templateCache = new Map<Id, ActionPlanTemplate__c>();

  /**
   * Manually cache a template record
   * @param template The template record to cache
   */
  public static void cacheTemplate(ActionPlanTemplate__c template) {
    if (template != null && template.Id != null) {
      templateCache.put(template.Id, template);
    }
  }

  /**
   * Clear the field path and task caches
   */
  public static void clearFieldPathCache() {
    fieldPathCache.clear();
    hydratedTasksCache.clear();
    templateCache.clear();
  }

  /**
   * Pre-load field path values for a collection of records to prevent 101 SOQL errors.
   * This method queries all required fields for all records in bulk and caches them.
   * 
   * @param objectType The API name of the base object
   * @param recordIds The set of record IDs to pre-load
   * @param fieldPaths The set of field paths to pre-load
   */
  public static void preloadFieldPathValues(String objectType, Set<Id> recordIds, Set<String> fieldPaths) {
    if (String.isBlank(objectType) || recordIds == null || recordIds.isEmpty() || fieldPaths == null || fieldPaths.isEmpty()) {
      return;
    }

    System.debug(LoggingLevel.INFO, '=== PRE-LOADING FIELD PATH VALUES ===');
    System.debug(LoggingLevel.INFO, 'Object Type: ' + objectType + ', Record Count: ' + recordIds.size() + ', Path Count: ' + fieldPaths.size());

    Set<String> selectPaths = new Set<String>();
    Map<String, CanonicalPath> pathToCanonical = new Map<String, CanonicalPath>();

    for (String path : fieldPaths) {
      if (String.isBlank(path)) {
        continue;
      }
      
      // Handle special fields
      if (path.equalsIgnoreCase('Owner') || path.equalsIgnoreCase('OwnerId') || path.equalsIgnoreCase('Owner.Id')) {
        selectPaths.add('OwnerId');
        continue;
      }

      try {
        CanonicalPath cp = canonicalizeFieldPath(objectType, path);
        selectPaths.add(cp.selectPath);
        pathToCanonical.put(path, cp);
      } catch (Exception e) {
        System.debug(LoggingLevel.WARN, 'Could not canonicalize path ' + path + ': ' + e.getMessage());
      }
    }

    if (selectPaths.isEmpty()) {
      return;
    }

    String query = 'SELECT Id, ' + String.join(new List<String>(selectPaths), ', ') + ' FROM ' + objectType + ' WHERE Id IN :recordIds';
    System.debug(LoggingLevel.INFO, 'Executing bulk pre-load query: ' + query);

    for (SObject record : Database.query(query)) {
      Id recordId = record.Id;
      
      for (String path : fieldPaths) {
        String cacheKey = (objectType + '-' + recordId + '-' + path).toLowerCase();
        
        if (path.equalsIgnoreCase('Owner') || path.equalsIgnoreCase('OwnerId') || path.equalsIgnoreCase('Owner.Id')) {
          fieldPathCache.put(cacheKey, record.get('OwnerId'));
          continue;
        }

        CanonicalPath cp = pathToCanonical.get(path);
        if (cp == null) {
          continue;
        }

        SObject node = record;
        Boolean pathBroken = false;
        for (String rel : cp.relationshipPath) {
          node = node.getSObject(rel);
          if (node == null) {
            pathBroken = true;
            break;
          }
        }
        
        if (!pathBroken) {
          fieldPathCache.put(cacheKey, node.get(cp.leafFieldName));
        } else {
          fieldPathCache.put(cacheKey, null);
        }
      }
    }
    System.debug(LoggingLevel.INFO, '=== PRE-LOAD COMPLETED: ' + fieldPathCache.size() + ' entries cached ===');
  }
  /**
   * Local store of `aPTListparam` passed to constructor
   */
  private List<APTask__c> baseAPTaskList { get; set; }
  /**
   * The constructed `ActionPlan__c` records
   */
  private List<ActionPlan__c> relActionPlans { get; set; }

  /**
   * Local store of `refType` passed to constructor
   */
  private String relatedObjectName { get; set; }
  /**
   * Local store of `oIdsSet` passed to constructor
   */
  private Set<Id> relatedRecordIDs { get; set; }

  /**
   * Editing or creating an `ActionPlan__c` record?
   */
  private enum ApEditMode {
    MODE_EDIT_SINGLE,
    MODE_NEW
  }
  /**
   * Store the enum value
   */
  private ApEditMode mode;

  /**
   * A single list of all Tasks - we set the DMLOption to send an email notification when we add the Task to this list
   */
  private List<Task> allTasksToUpsert { get; set; }

  /**
   * Constructor
   * @param baseObj      ActionPlan object
   * @param aPTListparam Action Plan Task Template records
   * @param refType      Related object Name
   * @param oIdsSet     Parent IDs
   */
  public ActionPlansBuilderUtilities(ActionPlan__c baseObj, List<APTask__c> aPTListparam, String refType, Set<Id> oIdsSet) {
    this.baseAPTaskList = aPTListparam;
    this.relActionPlans = new List<ActionPlan__c>();
    this.relatedObjectName = refType;
    this.relatedRecordIDs = oIdsSet;

    // if the actionPlan has already an Id, then we are editing an AP and not creating a new one
    if (baseObj.Id != null) {
      mode = ApEditMode.MODE_EDIT_SINGLE;
      relActionPlans.add(baseObj);
    } else {
      // If baseObjId == null, then we are inserting a single or multiple APs
      mode = ApEditMode.MODE_NEW;
      List<String> apRefFields = ActionPlansUtilities.getCustomRelationshipFields();
      Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ActionPlan__c.fields.getMap();

      for (Id relObjId : oIdsSet) {
        // iterate over all related IDs
        ActionPlan__c ap = new ActionPlan__c();
        ap = baseObj.clone();

        for (String s : apRefFields) {
          if (s == 'Related_Record__c') {
            continue; // skip text fallback when resolving true lookup field
          }
          String relatedObject = fieldMap.get(s).getDescribe().getReferenceTo()[0].getDescribe().getName();
          if (relatedObject.equalsIgnoreCase(refType)) {
            ap.put(s, relObjId);
          }
        }
        //add Action Plan to list that will be inserted later and referenced by ActionPlanTasks
        relActionPlans.add(ap);
      }
    }
  }

  /**
   * Generate Action Plans from parameters passed to this class
   * @author {@link [David Schach](https://github.com/dschach)}
   * @return   `Id` of the first created `ActionPlan__c`
   */
  public Id generateActionPlans() {
    List<APTask__c> aptList = new List<APTask__c>();
    Set<Id> upsertedAPTaskIDs = new Set<Id>();
    Map<Id, ActionPlan__c> mapIDAP = new Map<Id, ActionPlan__c>();
    ActionPlan__c apAux;
    Map<Id, Task> mapApTasks = new Map<Id, Task>();
    Integer taskTemplateNameLength = APTask__c.Name.getDescribe().getLength();

    this.allTasksToUpsert = new List<Task>();

    Database.DMLOptions dmlEmail = new Database.DMLOptions();
    dmlEmail.emailHeader.triggerUserEmail = true;

    Database.DMLOptions dmlNoEmail = new Database.DMLOptions();
    dmlEmail.emailHeader.triggerUserEmail = false;

    Map<Id, Id> objectOwnersMap = retrieveOwnersDataRelatedObject(this.relatedRecordIDs);
    //insert Action Plans to DB
    upsert relActionPlans;

    //create ActionPlanTemplatetasks && tasks from base ActionPlan Task List
    if (this.mode == ApEditMode.MODE_NEW) {
      // Working on multiple APs from oIdsSet
      for (ActionPlan__c ap : relActionPlans) {
        mapIDAP.put(ap.Id, ap);

        //Now for each inserted ap we should run through tasks and create them
        for (APTask__c aptask : this.baseAPTaskList) {
          APTask__c nt = new APTask__c();
          nt = aptask.clone();

          nt.Action_Plan__c = ap.Id;
          nt.Name = aptask.Id == null ? ActionPlansUtilities.actionPlanSubjectToName(ap.Name + ' - ' + nt.Subject__c, taskTemplateNameLength) : nt.Name;
          nt.DaysFromStart__c = (nt.DaysFromStart__c == null || nt.DaysFromStart__c < 0) ? 0 : nt.DaysFromStart__c;
          
          // Get the assigned user/queue ID
          Id assignedToId = getAPTaskTemplateUser(ap, objectOwnersMap, nt);
          
          // Store the assignedToId in a custom field for later Task creation
          // This ensures Queue IDs are preserved for Task.OwnerId assignment
          try {
            nt.put('TemplateAssignedToId__c', assignedToId);
            System.debug(LoggingLevel.INFO, 'Set TemplateAssignedToId__c to: ' + assignedToId);
          } catch (Exception e) {
            System.debug(LoggingLevel.INFO, 'TemplateAssignedToId__c field not available: ' + e.getMessage());
          }
          
          // Only assign to User__c if it's a User ID, not a Queue ID
          // Queue IDs start with '00G' and cause FIELD_INTEGRITY_EXCEPTION on User__c field
          if (assignedToId != null && String.valueOf(assignedToId).startsWith('005')) {
            nt.User__c = assignedToId;
          } else if (assignedToId != null && String.valueOf(assignedToId).startsWith('00G')) {
            System.debug(LoggingLevel.INFO, 'Skipping User__c assignment for Queue ID: ' + assignedToId);
            // Don't assign User__c for Queue IDs as it causes field integrity exception
            nt.User__c = null;
          } else {
            nt.User__c = assignedToId;
          }
          
          aptList.add(nt);
        }
      }

      upsert aptList;
    } else {
      Assert.areEqual(1, relActionPlans.size());

      for (ActionPlan__c ap : relActionPlans) {
        mapIDAP.put(ap.Id, ap);

        for (APTask__c apt : this.baseAPTaskList) {
          apt.DaysFromStart__c = (apt.DaysFromStart__c == null || apt.DaysFromStart__c < 0) ? 0 : apt.DaysFromStart__c;
          apt.Name = apt.Id == null ? ActionPlansUtilities.actionPlanSubjectToName(ap.Name + ' - ' + apt.Subject__c, taskTemplateNameLength) : apt.Name;
          
          // Get the assigned user/queue ID
          Id assignedToId = getAPTaskTemplateUser(ap, objectOwnersMap, apt);
          
          // Store the assignedToId in a custom field for later Task creation
          // This ensures Queue IDs are preserved for Task.OwnerId assignment
          try {
            apt.put('TemplateAssignedToId__c', assignedToId);
            System.debug(LoggingLevel.INFO, 'Set TemplateAssignedToId__c to: ' + assignedToId);
          } catch (Exception e) {
            System.debug(LoggingLevel.INFO, 'TemplateAssignedToId__c field not available: ' + e.getMessage());
          }
          
          // Only assign to User__c if it's a User ID, not a Queue ID
          // Queue IDs start with '00G' and cause FIELD_INTEGRITY_EXCEPTION on User__c field
          if (assignedToId != null && String.valueOf(assignedToId).startsWith('005')) {
            apt.User__c = assignedToId;
          } else if (assignedToId != null && String.valueOf(assignedToId).startsWith('00G')) {
            System.debug(LoggingLevel.INFO, 'Skipping User__c assignment for Queue ID: ' + assignedToId);
            // Don't assign User__c for Queue IDs as it causes field integrity exception
            apt.User__c = null;
          } else {
            apt.User__c = assignedToId;
          }
        }
        aptList = this.baseAPTaskList;
      }
    }

    List<APTask__c> aptsToUpsert = new List<APTask__c>();

    String defaultTaskStatus = ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues().get(ActionPlansUtilities.getDefaultTaskRecordTypeId());

    for (ActionPlan__c ap : relActionPlans) {
      for (APTask__c at : aptList) {
        if (at.Action_Plan__c != null && at.Action_Plan__c != ap.Id) {
          continue;
        }

        if (at.Action_Plan__c == null && ap.Id != null) {
          at.Action_Plan__c = ap.Id;
        } // This Id can be null because we may not have set it in the controller

        if (at.Status__c == null) {
          if (!String.isBlank(ap.TaskRecordTypeID__c) && ap.TaskRecordTypeID__c instanceof Id && ap.TaskRecordTypeID__c.startsWithIgnoreCase('012')) {
            at.Status__c = ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues().get(ap.TaskRecordTypeID__c);
          } else {
            at.Status__c = defaultTaskStatus;
          }
        }

        if (at.Dependent__c != null && at.Dependent__c != 'None') {
          Integer tempIndex = Integer.valueOf(at.Dependent__c);
          at.Controller__c = aptList[tempIndex].Id;
          at.ActivityDate__c = null;
        } else {
          at.Controller__c = null;
          //set dependency taskId to none if none was selected
          at.Dependent__c = 'None';

          // Standard due date calculation for APTask__c
          // Note: DueDateType__c and DueDateRelatedField__c fields exist on APTemplateTask__c but not on APTask__c
          if (ap.SkipWeekends__c == true && ap.SkipDay__c != null) {
            at.ActivityDate__c = ActionPlansUtilities.adjustTaskDueDate(ap.StartDate__c, at.DaysFromStart__c.intValue(), ap.SkipDay__c);
          } else {
            at.ActivityDate__c = ap.StartDate__c.addDays(at.DaysFromStart__c.intValue());
          }
        }
        aptsToUpsert.add(at);
      }
    }

    upsert aptsToUpsert;

    // This may be unnecessary, as we can probably use the upserted list in the query, but is here for readability
    for (APTask__c apt : aptsToUpsert) {
      upsertedAPTaskIDs.add(apt.Id);
    }

    for (Task tmpTask : [SELECT Id, TaskAPTask__c, Subject, OwnerId FROM Task WHERE TaskAPTask__c IN :upsertedAPTaskIDs AND TaskAPTask__c != NULL]) {
      mapApTasks.put(tmpTask.TaskAPTask__c, tmpTask);
    }
    System.debug('mapApTasks.size: ' + mapApTasks.size());

    for (APTask__c refAPTask : aptsToUpsert) {
      // check if task exists already
      Task t = mapApTasks.get(refAPTask.Id);
      System.debug('t: ' + t);
      if (t == null) {
        //Create the new task and template
        t = new Task();
      }
      t.Subject = refAPTask.Subject__c;
      t.Priority = refAPTask.Priority__c;
      if (t.Id == null || ActionPlansUtilities.idStartsWith(t.OwnerId, '005')) {
        // Use proper fallback logic when APTask User__c is null (including for Queue IDs)
        if (refAPTask?.User__c != null) {
          t.OwnerId = refAPTask.User__c;
        } else {
          // Try to get the stored assignedToId that includes fallback queue IDs
          Id storedAssignedToId = null;
          try {
            storedAssignedToId = (Id) refAPTask.get('TemplateAssignedToId__c');
            System.debug(LoggingLevel.INFO, 'Retrieved TemplateAssignedToId__c: ' + storedAssignedToId);
          } catch (Exception e) {
            System.debug(LoggingLevel.INFO, 'TemplateAssignedToId__c field not available on APTask: ' + e.getMessage());
          }
          
          if (storedAssignedToId != null) {
            t.OwnerId = storedAssignedToId;
            System.debug(LoggingLevel.INFO, 'Using stored TemplateAssignedToId__c for Task.OwnerId: ' + storedAssignedToId);
          } else {
            // Fallback to the previous logic if TemplateAssignedToId__c is not available
            Id assignedToId = getAPTaskTemplateUser(apAux, new Map<Id, Id>(), refAPTask);
            t.OwnerId = assignedToId != null ? assignedToId : UserInfo.getUserId();
          }
        }
      }
      t.Type = refAPTask.Type__c;
      t.TaskAPTask__c = refAPTask.Id;

      if (String.isNotEmpty(refAPTask.Comments__c)) {
        t.Description = refAPTask.Comments__c;
      }

      if (t.Id == null) {
        t.Status = refAPTask.Status__c;
      }

      //set reminder based on user's default reminder setting
      if (refAPTask.Reminder__c == true && refAPTask.ActivityDate__c != null) {
        t.IsReminderSet = true;
        t.ReminderDateTime = Datetime.newInstance(refAPTask.ActivityDate__c.year(), refAPTask.ActivityDate__c.month(), refAPTask.ActivityDate__c.day(), 0, 0, 0);
        t.ReminderDateTime = t.ReminderDateTime.addMinutes(Integer.valueOf(refAPTask.Minutes_Reminder__c));
      } else {
        t.IsReminderSet = false;
      }
      t.ActivityDate = refAPTask.ActivityDate__c;

      if (mapIDAP.containsKey(refAPTask.Action_Plan__c)) {
        apAux = mapIDAP.get(refAPTask.Action_Plan__c);
      }

      if (apAux == null) {
        apAux = refAPTask.Action_Plan__r;
      }

      Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ActionPlan__c.fields.getMap();

      Boolean setWhat = true;
      if (apAux.Contact__c != null) {
        t.WhoId = apAux.Contact__c;
        setWhat = false;
      } else if (apAux.Lead__c != null) {
        t.WhoId = apAux.Lead__c;
        setWhat = false;
      }

      if (setWhat) {
        //link to Action Plan's Related To Object
        for (String s : ActionPlansUtilities.getCustomRelationshipFields()) {
          if (s == 'Related_Record__c') {
            continue; // skip text fallback when resolving true lookup field
          }
          String relatedObject = fieldMap.get(s).getDescribe().getReferenceTo()[0].getDescribe().getName();
          if (relatedObject.equalsIgnoreCase(relatedObjectName)) {
            t.WhatId = (Id) apAux.get(s);
            break;
          }
        }
        // Fallback to Related_Record__c if no dedicated lookup field was found
        if (t.WhatId == null && apAux.Related_Record__c != null) {
          System.debug('ActionPlansBuilderUtilities: No dedicated lookup field found, checking Related_Record__c');
          String relatedRecordValue = apAux.Related_Record__c;
          // Related_Record__c stores the record Id as a string when no dedicated lookup exists
          if (relatedRecordValue != null && (relatedRecordValue.length() == 15 || relatedRecordValue.length() == 18)) {
            try {
              Id relatedId = (Id) relatedRecordValue;
              System.debug('ActionPlansBuilderUtilities: Setting Task.WhatId from Related_Record__c: ' + relatedId);
              t.WhatId = relatedId;
            } catch (Exception e) {
              System.debug('ActionPlansBuilderUtilities: Related_Record__c is not a valid Id: ' + relatedRecordValue);
            }
          }
        }
      }

      //System.debug('NEW TASK: ' + t);

      if (refAPTask.Dependent__c == 'None') {
        if (refAPTask.SendEmail__c == true) {
          t.setOptions(dmlEmail);
          allTasksToUpsert.add(t);
        } else {
          t.setOptions(dmlNoEmail);
          allTasksToUpsert.add(t);
        }
      } else {
        //only update dependant tasks that are already created
        if (t.Id != null) {
          if (refAPTask.SendEmail__c == true) {
            t.setOptions(dmlEmail);
            allTasksToUpsert.add(t);
          } else {
            t.setOptions(dmlNoEmail);
            allTasksToUpsert.add(t);
          }
        }
      }
    }

    upsert allTasksToUpsert;

    if (this.mode != ApEditMode.MODE_EDIT_SINGLE) {
      // Execution When a Action Plan is created that checks the Custom Setings in order to post a new FeedPost ( Object )
      Action_Plans_Settings__c mySettings = ActionPlansUtilities.getCustomSetting();

      Set<Id> relObjectIDs = new Set<Id>();
      for (ActionPlan__c ap : relActionPlans) {
        relObjectIDs.add(ap.Id);
      }

      if (mySettings != null && mySettings.Chatter_Object_Brag__c) {
        generateObjectFeeds(relObjectIDs);
      }
    }
    if (relActionPlans.size() == 1) {
      return relActionPlans[0].Id;
    } else {
      return null;
    }
  }

  /**
   * Overloaded method to handle APTask__c parameter
   * @param ap           The `ActionPlan__c`
   * @param relObjOwners Map of `Id` to record `OwnerId`
   * @param apTask       The `APTask__c` object
   * @return             `Id` The `APTask__c` assigned user
   */
  public static Id getAPTaskTemplateUser(ActionPlan__c ap, Map<Id, Id> relObjOwners, APTask__c apTask) {
    System.debug(LoggingLevel.INFO, '=== PARSING OWNER FROM APTASK OBJECT ===');
    System.debug(LoggingLevel.INFO, 'Action Plan: ' + ap?.Id + ', APTask: ' + apTask?.Id);
    
    // Check if the APTask has UserRelatedField__c field
    String userRelatedField = null;
    try {
      // Use dynamic field access since APTask__c might not have UserRelatedField__c in all orgs
      userRelatedField = (String)apTask.get('UserRelatedField__c');
      System.debug(LoggingLevel.INFO, 'UserRelatedField__c: ' + userRelatedField);
    } catch (Exception e) {
      System.debug(LoggingLevel.INFO, 'UserRelatedField__c field not found on APTask__c');
    }
    
    // If UserRelatedField__c is not null, use it as a field path
    if (String.isNotBlank(userRelatedField)) {
      try {
        // Get the related record ID from the action plan
        Id relatedRecordId = getRelatedRecordId(ap);
        if (relatedRecordId == null) {
          System.debug(LoggingLevel.ERROR, 'Could not find related record ID for action plan: ' + ap.Id);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
        }
        
        // Get the object type of the related record
        String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
        System.debug(LoggingLevel.INFO, 'Related record ID: ' + relatedRecordId + ', Object Type: ' + objectType);
        
        // Resolve the field path value
        Id userId = resolveFieldPathValue(objectType, relatedRecordId, userRelatedField);
        if (userId != null) {
          System.debug(LoggingLevel.INFO, 'Successfully resolved field path ' + userRelatedField + ' to user ID: ' + userId);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED SUCCESSFULLY ===');
          return userId;
        } else {
          System.debug(LoggingLevel.ERROR, 'Could not resolve field path: ' + userRelatedField);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error resolving field path: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
        return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
      }
    }
    
    // If UserRelatedField__c is null, fall back to User__c
    return getAPTaskTemplateUser(ap, relObjOwners, apTask.User__c);
  }

  /**
   * Overloaded method to handle String/Id parameter for backward compatibility
   * @param ap           The `ActionPlan__c`
   * @param relObjOwners Map of `Id` to record `OwnerId`
   * @param userIdOrFieldPath The user Id or field path string
   * @return             `Id` The `APTask__c` assigned user
   */
  public static Id getAPTaskTemplateUser(ActionPlan__c ap, Map<Id, Id> relObjOwners, String userIdOrFieldPath) {
    System.debug(LoggingLevel.INFO, '=== PARSING OWNER FROM STRING VALUE ===');
    System.debug(LoggingLevel.INFO, 'Action Plan: ' + ap?.Id + ', User/Field Path: ' + userIdOrFieldPath);
    
    // Check if the value is null or empty
    if (String.isBlank(userIdOrFieldPath)) {
      System.debug(LoggingLevel.INFO, 'User/Field Path is blank or null');
    }
    
    // This method is called from two places:
    // 1. From APTask__c creation where we don't have UserType__c
    // 2. From APTemplateTask__c where we should have UserType__c but it's not passed to this method
    
    // Try to determine if this is a field path or a user ID
    Boolean isFieldPath = false;
    String fieldPath = '';
    
    // First check for explicit FIELD: prefix (legacy format)
    if (String.isNotBlank(userIdOrFieldPath) && userIdOrFieldPath.startsWith('FIELD:')) {
      System.debug(LoggingLevel.INFO, 'Detected FIELD: prefix in User/Field Path');
      isFieldPath = true;
      fieldPath = userIdOrFieldPath.substring(6); // 'FIELD:'.length() = 6
      System.debug(LoggingLevel.INFO, 'Extracted field path from FIELD: prefix: ' + fieldPath);
    } 
    // Then check if it's a valid ID but not a User ID (might be a field path that happens to be a valid ID)
    else if (String.isNotBlank(userIdOrFieldPath) && userIdOrFieldPath.length() == 18) {
      try {
        Id possibleId = Id.valueOf(userIdOrFieldPath);
        if (possibleId.getSobjectType() != User.SObjectType && !String.valueOf(possibleId).startsWith('005')) {
          System.debug(LoggingLevel.INFO, 'Detected non-User ID that might be a field path: ' + userIdOrFieldPath);
          isFieldPath = true;
          fieldPath = userIdOrFieldPath;
          System.debug(LoggingLevel.INFO, 'Using as field path: ' + fieldPath);
        }
      } catch (Exception e) {
        // Not a valid ID, ignore
      }
    }
    
    if (isFieldPath) {
      try {
        // Get the related record ID from the action plan
        Id relatedRecordId = getRelatedRecordId(ap);
        if (relatedRecordId == null) {
          System.debug(LoggingLevel.ERROR, 'Could not find related record ID for action plan: ' + ap.Id);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
        }
        
        // Get the object type of the related record
        String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
        System.debug(LoggingLevel.INFO, 'Related record ID: ' + relatedRecordId + ', Object Type: ' + objectType);
        
        // Resolve the field path value
        Id userId = resolveFieldPathValue(objectType, relatedRecordId, fieldPath);
        if (userId != null) {
          System.debug(LoggingLevel.INFO, 'Successfully resolved field path ' + fieldPath + ' to user ID: ' + userId);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED SUCCESSFULLY ===');
          return userId;
        } else {
          System.debug(LoggingLevel.ERROR, 'Could not resolve field path: ' + fieldPath);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error resolving field path: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
        return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
      }
    }
    
    // If it's a valid User Id, return it
    if (String.isNotBlank(userIdOrFieldPath)) {
      try {
        // Check if it's a valid Id
        Id userId = Id.valueOf(userIdOrFieldPath);
        
        // Check if it's a User ID specifically (starts with 005)
        if (userId.getSobjectType() == User.SObjectType || String.valueOf(userId).startsWith('005')) {
          System.debug(LoggingLevel.INFO, 'Value is a valid User ID: ' + userId);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED SUCCESSFULLY ===');
          return userId;
        } else {
          System.debug(LoggingLevel.WARN, 'Value is a valid ID but not a User ID: ' + userId + ' (Type: ' + userId.getSobjectType() + ')');
          System.debug(LoggingLevel.INFO, 'Continuing to check if this should be treated as a field path...');
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.INFO, 'Value is not a valid ID: ' + userIdOrFieldPath);
        // Not a valid Id, ignore and continue
      }
    } else {
      System.debug(LoggingLevel.INFO, 'User/Field Path is blank');
    }
    
    // Use consistent fallback logic that prioritizes per-task fallback, then template queue
    System.debug(LoggingLevel.INFO, 'Using fallback logic for assignment');
    System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED - USING FALLBACK LOGIC ===');
    return getFallbackUserIdConsideringTask(ap, null, relObjOwners, currentTemplateTaskForFallback);
  }

  /**
   * Read the Action Plan and see the custom setting to determine who should own the AP Tasks (backward compatibility)
   * @param ap           The `ActionPlan__c`
   * @param relObjOwners Map of `Id` to record `OwnerId`
   * @param aptTask      The `APTemplateTask__c` object containing user assignment information
   * @return             `Id` The `APTask__c` assigned user
   * @see ActionPlansBuilderUtilities.getRelatedRecordOwnerId
   */
  public static Id getAPTaskTemplateUser(ActionPlan__c ap, Map<Id, Id> relObjOwners, APTemplateTask__c aptTask) {
    return getAPTaskTemplateUser(ap, relObjOwners, aptTask, null);
  }

  /**
   * Read the Action Plan and see the custom setting to determine who should own the AP Tasks
   * @param ap           The `ActionPlan__c`
   * @param relObjOwners Map of `Id` to record `OwnerId`
   * @param aptTask      The `APTemplateTask__c` object containing user assignment information
   * @param template     The `ActionPlanTemplate__c` object containing fallback queue information
   * @return             `Id` The `APTask__c` assigned user
   * @see ActionPlansBuilderUtilities.getRelatedRecordOwnerId
   */
  public static Id getAPTaskTemplateUser(ActionPlan__c ap, Map<Id, Id> relObjOwners, APTemplateTask__c aptTask, ActionPlanTemplate__c template) {
    // Set context for per-task fallback resolution
    currentTemplateTaskForFallback = aptTask;
    System.debug(LoggingLevel.INFO, '=== PARSING OWNER FROM TEMPLATE TASK ===');
    System.debug(LoggingLevel.INFO, 'Action Plan: ' + ap.Id + ', Template Task: ' + aptTask.Id);
    System.debug(LoggingLevel.INFO, 'UserType: ' + aptTask.UserType__c + ', UserRelatedField: ' + aptTask.UserRelatedField__c + ', User: ' + aptTask.User__c);
    
    // First check if UserType__c is FIELD and UserRelatedField__c is not blank
    if (aptTask.UserType__c == 'FIELD' && String.isNotBlank(aptTask.UserRelatedField__c)) {
      System.debug(LoggingLevel.INFO, 'Using UserRelatedField__c for field path: ' + aptTask.UserRelatedField__c);
      try {
        // Get the related record ID from the action plan
        Id relatedRecordId = getRelatedRecordId(ap);
        if (relatedRecordId == null) {
          System.debug(LoggingLevel.ERROR, 'Could not find related record ID for action plan: ' + ap.Id);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, template, relObjOwners, aptTask);
        }
        
        // Get the object type of the related record
        String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
        System.debug(LoggingLevel.INFO, 'Related record ID: ' + relatedRecordId + ', Object Type: ' + objectType);
        
        // Resolve the field path value
        Id userId = resolveFieldPathValue(objectType, relatedRecordId, aptTask.UserRelatedField__c);
        if (userId != null) {
          System.debug(LoggingLevel.INFO, 'Successfully resolved field path ' + aptTask.UserRelatedField__c + ' to user ID: ' + userId);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED SUCCESSFULLY ===');
          return userId;
        } else {
          System.debug(LoggingLevel.ERROR, 'Could not resolve field path: ' + aptTask.UserRelatedField__c);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, template, relObjOwners, aptTask);
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error resolving field path: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
        return getFallbackUserId(ap, template, relObjOwners);
      }
    }
    
    // For backward compatibility, check if User__c has a FIELD: prefix
    String apTaskUser = aptTask.User__c;
    if (String.isNotBlank(apTaskUser) && apTaskUser.startsWith('FIELD:')) {
      System.debug(LoggingLevel.INFO, 'Using legacy FIELD: prefix format from User__c field: ' + apTaskUser);
      try {
        // Extract the field path from the "FIELD:" prefix
        String fieldPath = apTaskUser.substring(6); // 'FIELD:'.length() = 6
        System.debug(LoggingLevel.INFO, 'Extracted field path: ' + fieldPath);
        
        // Get the related record ID from the action plan
        Id relatedRecordId = getRelatedRecordId(ap);
        if (relatedRecordId == null) {
          System.debug(LoggingLevel.ERROR, 'Could not find related record ID for action plan: ' + ap.Id);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserId(ap, template, relObjOwners);
        }
        
        // Get the object type of the related record
        String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
        System.debug(LoggingLevel.INFO, 'Related record ID: ' + relatedRecordId + ', Object Type: ' + objectType);
        
        // Resolve the field path value
        Id userId = resolveFieldPathValue(objectType, relatedRecordId, fieldPath);
        if (userId != null) {
          System.debug(LoggingLevel.INFO, 'Successfully resolved field path ' + fieldPath + ' to user ID: ' + userId);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING COMPLETED SUCCESSFULLY ===');
          return userId;
        } else {
          System.debug(LoggingLevel.ERROR, 'Could not resolve field path: ' + fieldPath);
          System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
          return getFallbackUserIdConsideringTask(ap, template, relObjOwners, aptTask);
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error resolving field path: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        System.debug(LoggingLevel.INFO, '=== OWNER PARSING FAILED - USING FALLBACK LOGIC ===');
        return getFallbackUserId(ap, template, relObjOwners);
      }
    }
    
    // Handle standard user ID
    if (String.isNotBlank(apTaskUser) && apTaskUser.length() >= 15 && !apTaskUser.equalsIgnoreCase('fallback')) {
      try {
        Id apTaskUserId = (Id) apTaskUser;
        return apTaskUserId;
      } catch (Exception e) {
        System.debug(LoggingLevel.INFO, 'apTaskUser is not a valid ID: ' + apTaskUser);
      }
    }
    
    // Handle default assignment - check fallback queue first
    if (template != null) {
      Object fallbackQueueObj = template.get('Fallback_Queue__c');
      if (fallbackQueueObj != null) {
        String fallbackQueue = String.valueOf(fallbackQueueObj);
        if (String.isNotBlank(fallbackQueue) && fallbackQueue.length() >= 15) {
          try {
            Id fallbackQueueId = (Id) fallbackQueue;
            System.debug(LoggingLevel.INFO, 'Using fallback queue from template: ' + fallbackQueueId);
            return fallbackQueueId;
          } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Invalid fallback queue ID on template: ' + fallbackQueue);
          }
        }
      }
    }
    
    // Handle default assignment based on custom setting
    Action_Plans_Settings__c mySettings = ActionPlansUtilities.getCustomSetting();
    if (mySettings.Unassigned_Task_Assigned_to_Owner__c) {
      return getRelatedRecordOwnerId(ap, relObjOwners);
    } else {
      return UserInfo.getUserId();
    }
  }
  
  /**
   * Get the fallback user ID when owner parsing fails
   * This method implements proper fallback logic:
   * 1. Check for fallback queue from template
   * 2. Check custom setting for unassigned task behavior
   * 3. Default to current user as last resort
   * @param ap The Action Plan
   * @param template The Action Plan Template
   * @param relObjOwners Map of related object owners
   * @return The fallback user/queue ID
   */
  private static Id getFallbackUserId(ActionPlan__c ap, ActionPlanTemplate__c template, Map<Id, Id> relObjOwners) {
    System.debug(LoggingLevel.INFO, '=== APPLYING FALLBACK LOGIC ===');
    
    // First, if we have per-task fallback context, try it
    if (currentTemplateTaskForFallback != null) {
      try {
        APTemplateTask__c taskCtx = hydrateTemplateTask(currentTemplateTaskForFallback);
        String fbUserType = null;
        String fbRelatedField = null;
        Id fbUser = null;
        try {
          fbUserType = (String) taskCtx.get('FallbackUserType__c');
        } catch (Exception e1) {}
        try {
          fbRelatedField = (String) taskCtx.get('FallbackUserRelatedField__c');
        } catch (Exception e2) {}
        try {
          fbUser = (Id) taskCtx.get('FallbackUser__c');
        } catch (Exception e3) {}
        if (fbUser != null) {
          System.debug(LoggingLevel.INFO, 'Using per-task FallbackUser__c: ' + fbUser);
          return fbUser;
        }
        if (fbUserType == 'FIELD' && String.isNotBlank(fbRelatedField)) {
          Id relatedRecordId = getRelatedRecordId(ap);
          if (relatedRecordId != null) {
            String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
            Id resolved = resolveFieldPathValue(objectType, relatedRecordId, fbRelatedField);
            if (resolved != null) {
              System.debug(LoggingLevel.INFO, 'Resolved per-task FallbackUserRelatedField__c to: ' + resolved);
              return resolved;
            }
          }
        }
      } catch (Exception ex) {
        System.debug(LoggingLevel.INFO, 'Per-task fallback evaluation failed or fields missing: ' + ex.getMessage());
      }
    }
    
    // If template is null but we have an ActionPlan with template ID, try to retrieve it
    if (template == null && ap != null && ap.Action_Plan_Template__c != null) {
      Id templateId = ap.Action_Plan_Template__c;
      if (templateCache.containsKey(templateId)) {
        template = templateCache.get(templateId);
      } else {
        try {
          System.debug(LoggingLevel.INFO, 'Template parameter is null, retrieving from ActionPlan: ' + templateId);
          
          // Build dynamic SOQL query to include Fallback_Queue__c if it exists
          String templateFields = 'Id, Name';
          
          // Check if Fallback_Queue__c field exists and add it
          Schema.SObjectType templateType = Schema.ActionPlanTemplate__c.getSObjectType();
          Map<String, Schema.SObjectField> templateFieldMap = templateType.getDescribe().fields.getMap();
          if (templateFieldMap.containsKey('fallback_queue__c')) {
            templateFields += ', Fallback_Queue__c';
          }
          
          String templateQuery = 'SELECT ' + templateFields + ' FROM ActionPlanTemplate__c WHERE Id = :templateId LIMIT 1';
          
          List<ActionPlanTemplate__c> templates = Database.query(templateQuery);
          if (!templates.isEmpty()) {
            template = templates[0];
            templateCache.put(templateId, template);
            System.debug(LoggingLevel.INFO, 'Successfully retrieved template: ' + template.Name);
          }
        } catch (Exception e) {
          System.debug(LoggingLevel.INFO, 'Error retrieving template: ' + e.getMessage());
        }
      }
    }
    
    // Handle default assignment - check fallback queue first
    if (template != null) {
      Object fallbackQueueObj = template.get('Fallback_Queue__c');
      if (fallbackQueueObj != null) {
        String fallbackQueue = String.valueOf(fallbackQueueObj);
        if (String.isNotBlank(fallbackQueue) && fallbackQueue.length() >= 15) {
          try {
            Id fallbackQueueId = (Id) fallbackQueue;
            System.debug(LoggingLevel.INFO, 'Using fallback queue from template: ' + fallbackQueueId);
            return fallbackQueueId;
          } catch (Exception e) {
            System.debug(LoggingLevel.INFO, 'Invalid fallback queue ID on template: ' + fallbackQueue);
          }
        }
      }
    }
    
    // Handle default assignment based on custom setting
    Action_Plans_Settings__c mySettings = ActionPlansUtilities.getCustomSetting();
    if (mySettings != null && mySettings.Unassigned_Task_Assigned_to_Owner__c) {
      Id ownerId = getRelatedRecordOwnerId(ap, relObjOwners);
      System.debug(LoggingLevel.INFO, 'Using related record owner from custom setting: ' + ownerId);
      return ownerId;
    } else {
      System.debug(LoggingLevel.INFO, 'Defaulting to current user as final fallback');
      return UserInfo.getUserId();
    }
  }
  
  /**
   * Enhanced fallback that first tries per-task fallback fields, then template queue, then settings.
   * @param ap The Action Plan
   * @param template The Action Plan Template (may be null)
   * @param relObjOwners Map of related object owners
   * @param aptTask The APTemplateTask__c providing fallback user fields (may be null)
   */
  private static Id getFallbackUserIdConsideringTask(ActionPlan__c ap, ActionPlanTemplate__c template, Map<Id, Id> relObjOwners, APTemplateTask__c aptTask) {
    System.debug(LoggingLevel.INFO, '=== APPLYING PER-TASK FALLBACK LOGIC ===');
    
    // Hydrate template task to ensure fallback fields are available
    if (aptTask != null) {
      aptTask = hydrateTemplateTask(aptTask);
    }
    
    // 1) Try per-task fallback fields if available
    if (aptTask != null) {
      try {
        // Safely access fields via dynamic get to avoid issues in orgs without them
        String fbUserType = null;
        String fbRelatedField = null;
        Id fbUser = null;
        try {
          fbUserType = (String) aptTask.get('FallbackUserType__c');
        } catch (Exception e1) {}
        try {
          fbRelatedField = (String) aptTask.get('FallbackUserRelatedField__c');
        } catch (Exception e2) {}
        try {
          fbUser = (Id) aptTask.get('FallbackUser__c');
        } catch (Exception e3) {}
        
        // If a direct fallback user is set, prefer it
        if (fbUser != null) {
          System.debug(LoggingLevel.INFO, 'Using direct FallbackUser__c: ' + fbUser);
          return fbUser;
        }
        
        // If fallback type is FIELD and a related field is provided, resolve it
        if (fbUserType == 'FIELD' && String.isNotBlank(fbRelatedField)) {
          Id relatedRecordId = getRelatedRecordId(ap);
          if (relatedRecordId != null) {
            String objectType = relatedRecordId.getSobjectType().getDescribe().getName();
            Id resolved = resolveFieldPathValue(objectType, relatedRecordId, fbRelatedField);
            if (resolved != null) {
              System.debug(LoggingLevel.INFO, 'Resolved FallbackUserRelatedField__c to: ' + resolved);
              return resolved;
            }
          }
        }
      } catch (Exception ex) {
        System.debug(LoggingLevel.INFO, 'Per-task fallback fields not available or failed: ' + ex.getMessage());
      }
    }
    
    // 2) Fall back to existing logic (template queue -> settings -> current user)
    return getFallbackUserId(ap, template, relObjOwners);
  }

  /**
   * Ensure APTemplateTask__c record has fallback fields populated by re-querying if needed.
   * Returns the hydrated record, or the original if hydration is not possible.
   */
  private static APTemplateTask__c hydrateTemplateTask(APTemplateTask__c task) {
    try {
      if (task == null || task.Id == null) {
        return task;
      }

      // Check cache first
      if (hydratedTasksCache.containsKey(task.Id)) {
        return hydratedTasksCache.get(task.Id);
      }

      // Describe fields safely; different orgs may not have these custom fields
      Map<String, Schema.SObjectField> fmap = Schema.SObjectType.APTemplateTask__c.fields.getMap();
      List<String> selectFields = new List<String>();
      selectFields.add('Id');
      
      // Fields to potentially re-query if they might be missing
      List<String> optionalFields = new List<String>{
        'fallbackuser__c', 'fallbackusertype__c', 'fallbackuserrelatedfield__c',
        'usertype__c', 'userrelatedfield__c', 'user__c'
      };
      
      for (String f : optionalFields) {
        if (fmap.containsKey(f)) {
          selectFields.add(fmap.get(f).getDescribe().getName());
        }
      }

      // Check if original task already has all these fields populated
      Boolean needsQuery = false;
      for (String f : selectFields) {
        try {
          task.get(f);
        } catch (System.SObjectException e) {
          needsQuery = true;
          break;
        }
      }

      if (!needsQuery) {
        hydratedTasksCache.put(task.Id, task);
        return task;
      }

      String soql = 'SELECT ' + String.join(selectFields, ', ') +
        ' FROM APTemplateTask__c WHERE Id = :taskId LIMIT 1';
      Id taskId = task.Id;
      List<APTemplateTask__c> rows = Database.query(soql);
      if (!rows.isEmpty()) {
        hydratedTasksCache.put(task.Id, rows[0]);
        return rows[0];
      }
      return task;
    } catch (Exception e) {
      System.debug(LoggingLevel.INFO, 'hydrateTemplateTask failed: ' + e.getMessage());
      return task;
    }
  }

  /**
   * Get the related record ID from an Action Plan
   * @param ap The Action Plan
   * @return The ID of the related record, or null if not found
   */
  private static Id getRelatedRecordId(ActionPlan__c ap) {
    for (String f : ActionPlansUtilities.getCustomRelationshipFields()) {
      if (ap.get(f) != null) {
        return (Id) ap.get(f);
      }
    }
    return null;
  }
  
  /**
   * Resolve a field path to get a User ID value
   * @param objectType The API name of the base object (e.g., "Account")
   * @param recordId The ID of the record to start from
   * @param fieldPath The field path to follow (e.g., "Owner.ManagerId")
   * @return The resolved User ID, or null if not found or not a valid User ID
   */
  public static Id resolveFieldPathValue(String objectType, Id recordId, String fieldPath) {
    System.debug(LoggingLevel.INFO, '=== RESOLVING FIELD PATH FOR USER ID ===');
    System.debug(LoggingLevel.INFO, 'Object Type: ' + objectType + ', Record ID: ' + recordId + ', Field Path: ' + fieldPath);
    
    // Check cache first
    String cacheKey = (objectType + '-' + recordId + '-' + fieldPath).toLowerCase();
    if (fieldPathCache.containsKey(cacheKey)) {
      Object cachedValue = fieldPathCache.get(cacheKey);
      System.debug(LoggingLevel.INFO, 'Using cached value for ' + cacheKey + ': ' + cachedValue);
      if (cachedValue instanceof Id) {
        return (Id)cachedValue;
      }
      return null;
    }

    try {
      // Validate inputs
      if (String.isBlank(objectType) || recordId == null || String.isBlank(fieldPath)) {
        System.debug(LoggingLevel.ERROR, 'Invalid inputs for resolveFieldPathValue: objectType=' + objectType + ', recordId=' + recordId + ', fieldPath=' + fieldPath);
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - INVALID INPUTS ===');
        return null;
      }
      
      // Special handling for common field paths
      if (fieldPath.equalsIgnoreCase('Owner') || fieldPath.equalsIgnoreCase('OwnerId')) {
        // For "Owner" or "OwnerId" field path, just query OwnerId directly
        System.debug(LoggingLevel.INFO, 'Special handling for Owner/OwnerId field path');
        String queryString = 'SELECT OwnerId FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
        System.debug(LoggingLevel.INFO, 'Executing query: ' + queryString);
        
        SObject record = Database.query(queryString);
        if (record == null) {
          System.debug(LoggingLevel.ERROR, 'No record found for ID: ' + recordId);
          System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - RECORD NOT FOUND ===');
          return null;
        }
        
        Id ownerId = (Id)record.get('OwnerId');
        System.debug(LoggingLevel.INFO, 'Successfully resolved to OwnerId: ' + ownerId);
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION COMPLETED SUCCESSFULLY ===');
        return ownerId;
      } else if (fieldPath.equalsIgnoreCase('Owner.Id')) {
        // For "Owner.Id" field path, just query OwnerId directly
        System.debug(LoggingLevel.INFO, 'Special handling for Owner.Id field path');
        String queryString = 'SELECT OwnerId FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
        System.debug(LoggingLevel.INFO, 'Executing query: ' + queryString);
        
        SObject record = Database.query(queryString);
        if (record == null) {
          System.debug(LoggingLevel.ERROR, 'No record found for ID: ' + recordId);
          System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - RECORD NOT FOUND ===');
          return null;
        }
        
        Id ownerId = (Id)record.get('OwnerId');
        System.debug(LoggingLevel.INFO, 'Successfully resolved Owner.Id to OwnerId: ' + ownerId);
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION COMPLETED SUCCESSFULLY ===');
        return ownerId;
      }
      
      // Canonicalize the incoming field path (case-insensitive and supports relationship name at leaf)
      CanonicalPath cp = canonicalizeFieldPath(objectType, fieldPath);
      System.debug(LoggingLevel.INFO, 'Canonical selectPath: ' + cp.selectPath);
      
      // Build and execute SOQL using canonical path
      String queryString = 'SELECT ' + cp.selectPath + ' FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
      System.debug(LoggingLevel.INFO, 'Executing query: ' + queryString);
      SObject record = Database.query(queryString);
      if (record == null) {
        System.debug(LoggingLevel.ERROR, 'No record found for ID: ' + recordId);
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - RECORD NOT FOUND ===');
        return null;
      }
      
      System.debug(LoggingLevel.INFO, 'Record found, navigating through field path...');
      
      // Navigate using exact-cased relationship names, then get the leaf field name
      SObject node = record;
      for (String rel : cp.relationshipPath) {
        System.debug(LoggingLevel.INFO, 'Traversing relationship: ' + rel);
        node = node.getSObject(rel);
        if (node == null) {
          System.debug(LoggingLevel.ERROR, 'Relationship segment returned null: ' + rel);
          return null;
        }
      }
      Object value = node.get(cp.leafFieldName);
      System.debug(LoggingLevel.INFO, 'Final value after path navigation: ' + value);
      
      // Ensure the final value is a valid User ID
      if (value instanceof Id) {
        Id valueId = (Id) value;
        if (valueId.getSobjectType() == User.SObjectType) {
          System.debug(LoggingLevel.INFO, 'Successfully resolved to User ID: ' + valueId);
          System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION COMPLETED SUCCESSFULLY ===');
          return valueId;
        } else {
          System.debug(LoggingLevel.ERROR, 'Field path does not resolve to a User ID. Found ID type: ' + valueId.getSobjectType() + ', Value: ' + valueId);
          System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - NOT A USER ID ===');
        }
      } else if (value != null) {
        System.debug(LoggingLevel.ERROR, 'Field path does not resolve to an ID. Found value: ' + value + ', Type: ' + value.toString());
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - NOT AN ID ===');
      } else {
        System.debug(LoggingLevel.ERROR, 'Field path resolves to null');
        System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - NULL VALUE ===');
      }
      
      return null;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Error resolving field path: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      System.debug(LoggingLevel.INFO, '=== FIELD PATH RESOLUTION FAILED - EXCEPTION ===');
      return null;
    }
  }
  
  // Helper holder for canonical path
  private class CanonicalPath {
    String selectPath;
    List<String> relationshipPath;
    String leafFieldName;
  }
  
  // Convert a raw path to canonical form: exact relationship tokens for intermediate segments,
  // and exact leaf field API name. Accepts case-insensitive input and relationship at leaf.
  private static CanonicalPath canonicalizeFieldPath(String baseObject, String rawPath) {
    if (String.isBlank(baseObject) || String.isBlank(rawPath)) {
      throw new IllegalArgumentException('Object and path are required.');
    }
    
    Map<String, Schema.SObjectType> globals = Schema.getGlobalDescribe();
    if (!globals.containsKey(baseObject)) {
      throw new IllegalArgumentException('Unknown sObject: ' + baseObject);
    }
    Schema.DescribeSObjectResult describe = globals.get(baseObject).getDescribe();
    
    List<String> tokens = rawPath.split('\\.');
    List<String> relSegments = new List<String>();
    
    for (Integer i = 0; i < tokens.size(); i++) {
      String token = tokens[i].trim();
      Boolean isLast = (i == tokens.size() - 1);
      
      // 1) Try direct case-insensitive field match
      Schema.SObjectField matched = null;
      for (String api : describe.fields.getMap().keySet()) {
        if (api.equalsIgnoreCase(token)) {
          matched = describe.fields.getMap().get(api);
          break;
        }
      }
      
      // 2) Try relationship-name match on reference fields
      if (matched == null) {
        for (Schema.SObjectField f : describe.fields.getMap().values()) {
          Schema.DescribeFieldResult fdr = f.getDescribe();
          if (fdr.getType() == Schema.DisplayType.REFERENCE) {
            String rel = fdr.getRelationshipName();
            if (rel != null && rel.equalsIgnoreCase(token)) {
              matched = f;
              break;
            }
          }
        }
      }
      
      // 3) Allow token + 'Id' fallback for non-leaf tokens
      if (matched == null && !isLast) {
        String alt = token + 'Id';
        if (describe.fields.getMap().containsKey(alt)) {
          matched = describe.fields.getMap().get(alt);
        }
      }
      
      if (matched == null) {
        throw new IllegalArgumentException('Cannot resolve segment "' + token + '" on ' + describe.getName());
      }
      
      Schema.DescribeFieldResult fdesc = matched.getDescribe();
      
      if (!isLast) {
        if (fdesc.getType() != Schema.DisplayType.REFERENCE) {
          throw new IllegalArgumentException('Segment "' + token + '" on ' + describe.getName() + ' is not a relationship.');
        }
        String relName = fdesc.getRelationshipName();
        if (String.isBlank(relName)) {
          throw new IllegalArgumentException('Field "' + fdesc.getName() + '" on ' + describe.getName() + ' has no relationship name.');
        }
        relSegments.add(relName);
        describe = fdesc.getReferenceTo()[0].getDescribe();
        continue;
      }
      
      // Leaf
      String leaf = fdesc.getName();
      
      String selectPath = relSegments.isEmpty()
        ? leaf
        : String.join(relSegments, '.') + '.' + leaf;
      
      CanonicalPath outp = new CanonicalPath();
      outp.selectPath = selectPath;
      outp.relationshipPath = relSegments;
      outp.leafFieldName = leaf;
      return outp;
    }
    
    throw new System.StringException('Path normalization fell through.');
  }
  
  /**
   * Resolve a field path to get a Date value for due date calculation
   * @param objectType The API name of the base object (e.g., "Account")
   * @param recordId The ID of the record to start from
   * @param fieldPath The field path to follow (e.g., "CreatedDate" or "Account.SLAExpirationDate__c")
   * @return The resolved Date value, or null if not found or not a valid Date
   */
  public static Date resolveFieldPathForDueDate(String objectType, Id recordId, String fieldPath) {
    System.debug(LoggingLevel.INFO, '=== RESOLVING DATE FIELD PATH FOR DUE DATE ===');
    System.debug(LoggingLevel.INFO, 'Object Type: ' + objectType + ', Record ID: ' + recordId + ', Field Path: ' + fieldPath);
    
    // Check cache first
    String cacheKey = (objectType + '-' + recordId + '-' + fieldPath).toLowerCase();
    if (fieldPathCache.containsKey(cacheKey)) {
      Object cachedValue = fieldPathCache.get(cacheKey);
      System.debug(LoggingLevel.INFO, 'Using cached value for ' + cacheKey + ': ' + cachedValue);
      if (cachedValue instanceof Date) {
        return (Date)cachedValue;
      } else if (cachedValue instanceof Datetime) {
        return ((Datetime)cachedValue).date();
      }
      return null;
    }

    try {
      // Validate inputs
      if (String.isBlank(objectType) || recordId == null || String.isBlank(fieldPath)) {
        System.debug(LoggingLevel.ERROR, 'Invalid inputs for resolveFieldPathForDueDate: objectType=' + objectType + ', recordId=' + recordId + ', fieldPath=' + fieldPath);
        return null;
      }
      
      // Split the field path into parts
      List<String> pathParts = fieldPath.split('\\.');
      System.debug(LoggingLevel.INFO, 'Field path parts: ' + pathParts);
      
      // Build a dynamic SOQL query to follow the field path
      String queryFields = String.join(pathParts, '.');
      String queryString = 'SELECT ' + queryFields + ' FROM ' + objectType + ' WHERE Id = :recordId LIMIT 1';
      
      System.debug(LoggingLevel.INFO, 'Executing query: ' + queryString);
      
      try {
        // Execute the query
        SObject record = Database.query(queryString);
        if (record == null) {
          System.debug(LoggingLevel.ERROR, 'No record found for ID: ' + recordId);
          return null;
        }
        
        // For relationship fields, we need to extract the value differently
        if (pathParts.size() > 1) {
          // Handle multi-level relationship fields
          SObject currentObj = record;
          
          // Navigate through all relationship fields except the last one (which is the actual field)
          for (Integer i = 0; i < pathParts.size() - 1; i++) {
            String relationshipField = pathParts[i];
            
            // Check if we have a relationship field
            if (currentObj.getSObject(relationshipField) != null) {
              // Get the related object and update currentObj for next iteration
              currentObj = currentObj.getSObject(relationshipField);
            } else {
              System.debug(LoggingLevel.ERROR, 'Related object is null for relationship field: ' + relationshipField);
              return null;
            }
          }
          
          // Get the final field value from the last related object
          String fieldName = pathParts[pathParts.size() - 1];
          Object fieldValue = currentObj.get(fieldName);
          
          // Convert the value to a Date
          Date dueDate = null;
          
          if (fieldValue instanceof Date) {
            dueDate = (Date) fieldValue;
            System.debug(LoggingLevel.INFO, 'Value is a Date: ' + dueDate);
          } else if (fieldValue instanceof Datetime) {
            dueDate = ((Datetime) fieldValue).date();
            System.debug(LoggingLevel.INFO, 'Value is a Datetime, converted to Date: ' + dueDate);
          } else if (fieldValue != null) {
            System.debug(LoggingLevel.ERROR, 'Field path does not resolve to a Date or Datetime: ' + fieldValue);
            return null;
          } else {
            System.debug(LoggingLevel.ERROR, 'Field path resolves to null');
            return null;
          }
          
          System.debug(LoggingLevel.INFO, 'Successfully resolved date field path to: ' + dueDate);
          System.debug(LoggingLevel.INFO, '=== END RESOLVING DATE FIELD PATH ===');
          return dueDate;
        } else {
          // For direct fields (no relationship), use the original approach
          Object value = record.get(pathParts[0]);
          
          // Convert the value to a Date
          Date dueDate = null;
          
          if (value instanceof Date) {
            dueDate = (Date) value;
            System.debug(LoggingLevel.INFO, 'Value is a Date: ' + dueDate);
          } else if (value instanceof Datetime) {
            dueDate = ((Datetime) value).date();
            System.debug(LoggingLevel.INFO, 'Value is a Datetime, converted to Date: ' + dueDate);
          } else if (value != null) {
            System.debug(LoggingLevel.ERROR, 'Field path does not resolve to a Date or Datetime: ' + value);
            return null;
          } else {
            System.debug(LoggingLevel.ERROR, 'Field path resolves to null');
            return null;
          }
          
          System.debug(LoggingLevel.INFO, 'Successfully resolved date field path to: ' + dueDate);
          System.debug(LoggingLevel.INFO, '=== END RESOLVING DATE FIELD PATH ===');
          return dueDate;
        }
      } catch (System.QueryException qe) {
        // If the query fails, it might be because we're trying to access a relationship field directly
        // Try an alternative approach for relationship fields
        if (pathParts.size() > 1) {
          String relationshipField = pathParts[0];
          String fieldName = pathParts[1];
          
          // For Contact.Account relationship, we need to use AccountId to get the Account
          if (objectType == 'Contact' && relationshipField == 'Account') {
            // Query the Contact to get the AccountId
            Contact contact = [SELECT AccountId FROM Contact WHERE Id = :recordId LIMIT 1];
            if (contact != null && contact.AccountId != null) {
              // Now query the Account to get the field value
              String accountQuery = 'SELECT ' + fieldName + ' FROM Account WHERE Id = \'' + contact.AccountId + '\' LIMIT 1';
              System.debug(LoggingLevel.INFO, 'Executing alternative query: ' + accountQuery);
              
              SObject account = Database.query(accountQuery);
              if (account != null) {
                Object fieldValue = account.get(fieldName);
                
                // Convert the value to a Date
                Date dueDate = null;
                
                if (fieldValue instanceof Date) {
                  dueDate = (Date) fieldValue;
                  System.debug(LoggingLevel.INFO, 'Value is a Date: ' + dueDate);
                } else if (fieldValue instanceof Datetime) {
                  dueDate = ((Datetime) fieldValue).date();
                  System.debug(LoggingLevel.INFO, 'Value is a Datetime, converted to Date: ' + dueDate);
                } else if (fieldValue != null) {
                  System.debug(LoggingLevel.ERROR, 'Field path does not resolve to a Date or Datetime: ' + fieldValue);
                  return null;
                } else {
                  System.debug(LoggingLevel.ERROR, 'Field path resolves to null');
                  return null;
                }
                
                System.debug(LoggingLevel.INFO, 'Successfully resolved date field path to: ' + dueDate);
                System.debug(LoggingLevel.INFO, '=== END RESOLVING DATE FIELD PATH ===');
                return dueDate;
              }
            }
          }
          
          // Handle other relationship types here if needed
          
          System.debug(LoggingLevel.ERROR, 'Could not resolve relationship field: ' + relationshipField);
          return null;
        } else {
          System.debug(LoggingLevel.ERROR, 'Query exception: ' + qe.getMessage());
          return null;
        }
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Error resolving date field path: ' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
      System.debug(LoggingLevel.INFO, '=== END RESOLVING DATE FIELD PATH (ERROR) ===');
      return null;
    }
  }

  /**
   * Given an Action Plan, looking in its relationship fields, find the owner of the related record from the map of records and owners
   * @param ap           `ActionPlan__c`
   * @param relObjOwners Map of related object `Id` to `OwnerId`
   * @return             `Id` The related record `OwnerId`
   */
  public static Id getRelatedRecordOwnerId(ActionPlan__c ap, Map<Id, Id> relObjOwners) {
    // Add null check for ActionPlan__c parameter
    if (ap == null) {
      System.debug(LoggingLevel.ERROR, 'ActionPlan__c parameter is null in getRelatedRecordOwnerId');
      return null;
    }
    
    Id objId;

    for (String f : ActionPlansUtilities.getCustomRelationshipFields()) {
      if (ap.get(f) != null) {
        objId = (Id) ap.get(f);
        break;
      }
    }

    if (relObjOwners.containsKey(objId)) {
      return relObjOwners.get(objId);
    } else {
      System.debug('RETURNING NULL FOR THE USER');
      return null;
    }
  }

  /**
   * Retrieve the owner list from the related object.
   * <br>Exclude owners that are not users (that are queues)
   * @param relatedRecordIDs	List of sobject record Ids
   * @return                  `Map<Id, Id>` Map of record Id to Owner Id
   */
  public static Map<Id, Id> retrieveOwnersDataRelatedObject(Set<Id> relatedRecordIDs) {
    Map<Id, Id> relatedObjOwners = new Map<Id, Id>();
    if (relatedRecordIDs.isEmpty()) {
      return relatedObjOwners;
    }
    List<Id> recordIdList = new List<Id>(relatedRecordIDs);
    Id recId = recordIdList[0];
    String objectName = ActionPlansUtilities.getRelatedSObjectDescribe(recId).getName();

    if (Schema.getGlobalDescribe().containsKey(objectName.toLowerCase())) {
      Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectName.toLowerCase()).getDescribe().fields.getMap();
      if (!fieldMap.containsKey('OwnerId')) {
        for (Id i : relatedRecordIDs) {
          relatedObjOwners.put(i, null);
        }
        return relatedObjOwners;
      }
    } else {
      for (Id i : relatedRecordIDs) {
        relatedObjOwners.put(i, null);
      }
      return relatedObjOwners;
    }

    String queryRetrieveOwnerIds;

    if (!relatedRecordIDs.isEmpty()) {
      queryRetrieveOwnerIds = 'SELECT Id, OwnerId FROM ' + objectName + ' WHERE Id IN :relatedRecordIDs';

      for (SObject obj : Database.query(String.escapeSingleQuotes(queryRetrieveOwnerIds))) {
        Id relRecordOwnerId = (Id) (obj.get('OwnerId'));
        relatedObjOwners.put((Id) (obj.get('Id')), ((String) relRecordOwnerId).startsWith('005') ? relRecordOwnerId : System.UserInfo.getUserId());
      }
    }
    return relatedObjOwners;
  }

  /**
   * Generate New `FeedItems` for multiple Action Plans
   * @param recIDs Set of IDs of records for which we may make Chatter posts
   * @see ActionPlansUtilities.getRelatedSObjectDescribe
   * @see ActionPlansUtilities.getPostObjectBody
   */
  public static void generateObjectFeeds(Set<Id> recIDs) {
    if (!Schema.getGlobalDescribe().containsKey('feeditem')) {
      return;
    }

    List<SObject> chatterPosts = new List<SObject>();

    List<String> apRefFields = ActionPlansUtilities.getCustomRelationshipFields();
    String apQuery = 'SELECT Id, Name, ' + String.join(apRefFields, ', ') + ' FROM ActionPlan__c WHERE Id IN :recIDs';

    for (SObject so : Database.query(String.escapeSingleQuotes(apQuery))) {
      ActionPlan__c ap = (ActionPlan__c) so;

      Id recId;
      Boolean chatterEnabled;

      for (String f : apRefFields) {
        if (ap.get(f) != null) {
          recId = (Id) ap.get(f);
          chatterEnabled = ActionPlansUtilities.getRelatedSObjectDescribe(recId).isFeedEnabled();
          //chatterEnabled = recId.getSObjectType().getDescribe().isFeedEnabled();
          break;
        }
      }

      if (chatterEnabled) {
        SObjectType token = Schema.getGlobalDescribe().get('FeedItem');
        SObject newPost = token.newSObject();
        newPost.put('Type', 'TextPost');
        newPost.put('ParentId', recId);
        newPost.put('Body', getPostObjectBody(recId, (String) ap.get('Name')));

        chatterPosts.add(newPost);
      }
    }

    insert chatterPosts;
  }

  /**
   * Given a parentID and the name of an Action Plan, make the `FeedItem` post body
   * @author {@link [David Schach](https://github.com/dschach)}
   * @param  recID  Parent ID
   * @param  apName Action Plan Name
   * @return        `String` The `FeedItem` Body
   */
  public static String getPostObjectBody(Id recID, String apName) {
    String objName = recID.getSobjectType().getDescribe().getLabel();
    String actionPlanName = apName;
    String runningUserName = UserInfo.getName();

    List<String> parameters = new List<String>();
    parameters.add(actionPlanName);
    parameters.add(objName);

    String chatterBody = runningUserName + ' ' + String.format(System.Label.ap_PostMessage, parameters);
    return chatterBody;
  }


}