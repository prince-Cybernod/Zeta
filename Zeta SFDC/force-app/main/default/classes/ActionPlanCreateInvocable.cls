@SuppressWarnings('PMD.AvoidGlobalModifier')
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
   * @group Invocable
   * @author {@link [David Schach](https://github.com/dschach)}
   * @since 2022
   */
global without sharing class ActionPlanCreateInvocable {
  /**
   * Invocable Apex for creating Action Plans from a template, a parent ID, and days from now to start the task due dates
   * @param requests Wrapper of `CreateActionPlanRequest`
   * @see ActionPlanCreateInvocable.CreateActionPlanRequest
   * @return `List<Id>` of the created Action Plans
   * @example
   * String apTemplateName;
   * ActionPlanTemplate__c apTemplate;
   * List<SObject> toInsert... // can use any object, such as Account, or the generic SObject class
   * List<ActionPlanCreateInvocable.CreateActionPlanRequest> requests = new List<ActionPlanCreateInvocable.CreateActionPlanRequest>();
   * for(SObject a : toInsert){
   *     ActionPlanCreateInvocable.CreateActionPlanRequest req = new ActionPlanCreateInvocable.CreateActionPlanRequest();
   *     req.templateNameOrID = apTemplate.Id;
   *     req.relatedRecordID = a.Id;
   *     req.daysToActionPlanStart = 0;
   *     req.actionPlanName = apTemplate.Name + ' - ' + a.Name; // optional
   *     requests.add(req);
   * List<Id> resultIDs = ActionPlanCreateInvocable.makeActionPlanFromTemplate(requests);
   */
  @InvocableMethod(Label='Create Action Plan From Template' Description='Takes a Template Name/Id and Record Id and makes an Action Plan for that record.' Category='ActionPlans')
  global static List<Id> makeActionPlanFromTemplate(List<CreateActionPlanRequest> requests) {
    System.debug(LoggingLevel.INFO, 'ActionPlanCreateInvocable.makeActionPlanFromTemplate called with ' + requests.size() + ' requests');

    List<ActionPlan__c> actionPlansToInsert = new List<ActionPlan__c>();
    Set<Id> createdAPIDs = new Set<Id>();

    // * Collect template IDs & handle parents
    Set<String> templateNamesOrIDs = new Set<String>();
    Set<Id> relatedIDs = new Set<Id>();
    for (CreateActionPlanRequest r : requests) {
      System.debug(LoggingLevel.INFO, 'Processing request: templateNameOrID=' + r.templateNameOrID +
                   ', relatedRecordID=' + r.relatedRecordID +
                   ', relatedRecordIDs=' + r.relatedRecordIDs +
                   ', actionPlanName=' + r.actionPlanName);

      templateNamesOrIDs.add(r.templateNameOrID);

      // Handle both single ID and list of IDs
      if (r.relatedRecordIDs != null && !r.relatedRecordIDs.isEmpty()) {
        System.debug(LoggingLevel.INFO, 'Using relatedRecordIDs list with ' + r.relatedRecordIDs.size() + ' record(s)');
        relatedIDs.addAll(r.relatedRecordIDs);
      } else if (r.relatedRecordID != null) {
        System.debug(LoggingLevel.INFO, 'Using single relatedRecordID: ' + r.relatedRecordID);
        relatedIDs.add(r.relatedRecordID);
      } else {
        System.debug(LoggingLevel.INFO, 'No related record IDs provided for this request (may be using WHERE clause)');
      }
    }

    System.debug(LoggingLevel.INFO, 'Collected ' + templateNamesOrIDs.size() + ' template names/IDs and ' + relatedIDs.size() + ' related record IDs');

    Map<String, ActionPlanTemplate__c> templateNameOrIdToTemplate = new Map<String, ActionPlanTemplate__c>();

    // Map contains Id AND Name because we will refer to
    // Build dynamic SOQL query to include Fallback_Queue__c if it exists
    String templateFields = 'Id, Description__c, Name, OwnerId, SkipDay__c, SkipWeekends__c, TaskRecordTypeID__c, Where_Clause__c, Target_Object_API_Name__c';

    // Check if Fallback_Queue__c field exists and add it
    Schema.SObjectType templateType = Schema.ActionPlanTemplate__c.getSObjectType();
    Map<String, Schema.SObjectField> templateFieldMap = templateType.getDescribe().fields.getMap();
    if (templateFieldMap.containsKey('fallback_queue__c')) {
      templateFields += ', Fallback_Queue__c';
    }

    // APTemplateTask fields
    String taskFields = 'Type__c, Subject__c, Priority__c, Dependent__c, Name, User__c, User__r.Name, Id, ' +
      'DaysFromStart__c, Action_Plan_Template__c, TController__r.Subject__c, Minutes_Reminder__c, ' +
      'Reminder__c, SendEmail__c, Comments__c, TaskIndex__c, Action_Plan_Template__r.TaskRecordTypeID__c, ' +
      'DueDateType__c, DueDateRelatedField__c, UserType__c, UserRelatedField__c';

    // Check if fallback user fields exist on APTemplateTask and add them
    Schema.SObjectType taskType = Schema.APTemplateTask__c.getSObjectType();
    Map<String, Schema.SObjectField> taskFieldMap = taskType.getDescribe().fields.getMap();
    if (taskFieldMap.containsKey('fallbackuser__c')) {
      taskFields += ', FallbackUser__c';
    }
    if (taskFieldMap.containsKey('fallbackusertype__c')) {
      taskFields += ', FallbackUserType__c';
    }
    if (taskFieldMap.containsKey('fallbackuserrelatedfield__c')) {
      taskFields += ', FallbackUserRelatedField__c';
    }

    String templateQuery = 'SELECT ' + templateFields + ', (' +
      'SELECT ' + taskFields + ' ' +
      'FROM aptTasks__r ORDER BY TaskIndex__c ASC) ' +
      'FROM ActionPlanTemplate__c WHERE (Name IN :templateNamesOrIDs OR Id IN :templateNamesOrIDs) AND Archived__c = false';

    System.debug(LoggingLevel.INFO, 'Executing template query: ' + templateQuery);
    System.debug(LoggingLevel.INFO, 'Template names/IDs to search for: ' + templateNamesOrIDs);

    for (ActionPlanTemplate__c apt : Database.query(templateQuery)) {
      templateNameOrIdToTemplate.put(apt.Id, apt);
      templateNameOrIdToTemplate.put(apt.Name, apt);
      // Pre-populate ActionPlansBuilderUtilities cache
      ActionPlansBuilderUtilities.cacheTemplate(apt);
      System.debug(LoggingLevel.INFO, 'Found template: ' + apt.Name + ' (ID: ' + apt.Id + '), WHERE clause: ' + apt.Where_Clause__c + ', Target Object: ' + apt.Target_Object_API_Name__c);
    }

    if (templateNameOrIdToTemplate.isEmpty()) {
      System.debug(LoggingLevel.WARN, 'No templates found matching the provided names/IDs');
      return new List<Id>(createdAPIDs);
    }

    System.debug(LoggingLevel.INFO, 'Found ' + templateNameOrIdToTemplate.size() + ' unique templates');

    // * Pre-load field path values to prevent 101 SOQL errors
    // Group records by object type and collect all field paths used in those templates
    Map<String, Set<Id>> objectTypeToRecordIds = new Map<String, Set<Id>>();
    Map<String, Set<String>> objectTypeToFieldPaths = new Map<String, Set<String>>();

    // Identify target object for each request and collect field paths from its templates
    for (CreateActionPlanRequest r : requests) {
      ActionPlanTemplate__c apt = templateNameOrIdToTemplate.get(r.templateNameOrID);
      if (apt == null) {
        continue;
      }

      String objectType = apt.Target_Object_API_Name__c;
      if (String.isBlank(objectType)) {
        // Fallback to related record ID if Target_Object_API_Name__c is missing
        if (r.relatedRecordID != null) {
          objectType = r.relatedRecordID.getSobjectType().getDescribe().getName();
        } else if (r.relatedRecordIDs != null && !r.relatedRecordIDs.isEmpty()) {
          objectType = r.relatedRecordIDs[0].getSobjectType().getDescribe().getName();
        }
      }

      if (String.isBlank(objectType)) {
        continue;
      }

      if (!objectTypeToRecordIds.containsKey(objectType)) {
        objectTypeToRecordIds.put(objectType, new Set<Id>());
        objectTypeToFieldPaths.put(objectType, new Set<String>());
      }

      if (r.relatedRecordID != null) {
        objectTypeToRecordIds.get(objectType).add(r.relatedRecordID);
      }
      if (r.relatedRecordIDs != null) {
        objectTypeToRecordIds.get(objectType).addAll(r.relatedRecordIDs);
      }

      // Collect field paths from template tasks
      for (APTemplateTask__c aptt : apt.aptTasks__r) {
        if (aptt.UserType__c == 'FIELD' && String.isNotBlank(aptt.UserRelatedField__c)) {
          objectTypeToFieldPaths.get(objectType).add(aptt.UserRelatedField__c);
        }
        if (aptt.DueDateType__c == 'DateField' && String.isNotBlank(aptt.DueDateRelatedField__c)) {
          objectTypeToFieldPaths.get(objectType).add(aptt.DueDateRelatedField__c);
        }

        // Also pre-load fallback user fields if they are field-based
        try {
          String fbUserType = (String) aptt.get('FallbackUserType__c');
          String fbRelatedField = (String) aptt.get('FallbackUserRelatedField__c');
          if (fbUserType == 'FIELD' && String.isNotBlank(fbRelatedField)) {
            objectTypeToFieldPaths.get(objectType).add(fbRelatedField);
          }
        } catch (Exception e) {
          // Fields might not exist in this org
        }
      }
    }

    // Perform bulk pre-load for each object type
    for (String objectType : objectTypeToRecordIds.keySet()) {
      ActionPlansBuilderUtilities.preloadFieldPathValues(
        objectType,
        objectTypeToRecordIds.get(objectType),
        objectTypeToFieldPaths.get(objectType)
      );
    }

    // * Handle parent records and dynamic WHERE clause
    Map<Id, Id> relObjectOwners = new Map<Id, Id>();
    Map<Id, String> relRecordNames = new Map<Id, String>();

    // Process dynamic WHERE clauses from templates
    Map<Id, List<Id>> templateIdToDynamicRecordIds = new Map<Id, List<Id>>();
    Set<Id> processedTemplates = new Set<Id>();

    for (CreateActionPlanRequest r : requests) {
      if (!templateNameOrIdToTemplate.containsKey(r.templateNameOrID)) {
        continue;
      }
      ActionPlanTemplate__c template = templateNameOrIdToTemplate.get(r.templateNameOrID);

      if (processedTemplates.contains(template.Id)) {
        continue;
      }
      processedTemplates.add(template.Id);

      if (String.isNotBlank(template.Where_Clause__c) && String.isNotBlank(template.Target_Object_API_Name__c)) {
        try {
          String whereClause = template.Where_Clause__c.trim();
          if (whereClause.startsWithIgnoreCase('WHERE')) {
            whereClause = whereClause.substring(5).trim();
          }

          // Query for matching records
          String queryString = 'SELECT Id FROM ' + template.Target_Object_API_Name__c + ' WHERE (' + whereClause + ')';

          // If we have specific record IDs to filter by (from trigger context), add them to the query
          if (!relatedIDs.isEmpty()) {
            queryString += ' AND Id IN :relatedIDs';
          }

          // Add filter to exclude records that already have action plans
          // This prevents duplicate action plans from being created when the same template
          // is applied multiple times to the same records

          // Find the relationship field for this object type
          String objectType = template.Target_Object_API_Name__c;
          Map<String, String> relFieldMap = ActionPlansUtilities.getRelationshipFieldMap();
          String relationshipField = relFieldMap.get(objectType.toLowerCase());

          // To prevent duplicates, we need to exclude records that already have an Action Plan for this template.
          // We can't use 'Related_Record__c' in a semi-join because it's a text field.
          // If we have a specific set of IDs to check, we can pre-filter them.
          Set<Id> idsToExclude = new Set<Id>();
          if (!relatedIDs.isEmpty()) {
            String apCheckQuery = 'SELECT Related_Record__c';
            if (relationshipField != null && !relationshipField.equalsIgnoreCase('Related_Record__c')) {
              apCheckQuery += ', ' + relationshipField;
            }
            apCheckQuery += ' FROM ActionPlan__c WHERE Action_Plan_Template__c = \'' + template.Id + '\' AND (Related_Record__c IN :relatedIDs';
            if (relationshipField != null && !relationshipField.equalsIgnoreCase('Related_Record__c')) {
              apCheckQuery += ' OR ' + relationshipField + ' IN :relatedIDs';
            }
            apCheckQuery += ')';

            for (ActionPlan__c ap : Database.query(apCheckQuery)) {
              if (ap.Related_Record__c != null) {
                try {
                  idsToExclude.add((Id) ap.Related_Record__c);
                } catch (Exception e) {
                  // Not a valid ID, ignore
                }
              }
              if (relationshipField != null && !relationshipField.equalsIgnoreCase('Related_Record__c')) {
                Id relId = (Id) ap.get(relationshipField);
                if (relId != null) {
                  idsToExclude.add(relId);
                }
              }
            }
          }

          if (!idsToExclude.isEmpty()) {
            queryString += ' AND Id NOT IN :idsToExclude';
          }

          // If we found a formal relationship field, also exclude records linked via that field for THIS template
          // This is safe for semi-joins and works even when relatedIDs is empty
          if (relationshipField != null && !relationshipField.equalsIgnoreCase('Related_Record__c')) {
            queryString += ' AND Id NOT IN (SELECT ' + relationshipField + ' FROM ActionPlan__c WHERE Action_Plan_Template__c = \'' + template.Id + '\' AND ' + relationshipField + ' != null)';
          }

          System.debug('Executing dynamic query: ' + queryString);

          List<Id> dynamicRecordIds = new List<Id>();
          for (SObject record : Database.query(queryString)) {
            dynamicRecordIds.add((Id) record.get('Id'));
            relatedIDs.add((Id) record.get('Id'));  // Add to the overall set for owner/name queries
          }

          if (!dynamicRecordIds.isEmpty()) {
            templateIdToDynamicRecordIds.put(template.Id, dynamicRecordIds);

            // Collect field paths for newly found dynamic records
            Set<String> fieldPathsForDynamic = new Set<String>();
            for (APTemplateTask__c aptt : template.aptTasks__r) {
              if (aptt.UserType__c == 'FIELD' && String.isNotBlank(aptt.UserRelatedField__c)) {
                fieldPathsForDynamic.add(aptt.UserRelatedField__c);
              }
              if (aptt.DueDateType__c == 'DateField' && String.isNotBlank(aptt.DueDateRelatedField__c)) {
                fieldPathsForDynamic.add(aptt.DueDateRelatedField__c);
              }
              try {
                String fbUserType = (String) aptt.get('FallbackUserType__c');
                String fbRelatedField = (String) aptt.get('FallbackUserRelatedField__c');
                if (fbUserType == 'FIELD' && String.isNotBlank(fbRelatedField)) {
                  fieldPathsForDynamic.add(fbRelatedField);
                }
              } catch (Exception e) {}
            }

            // Pre-load field path values for these dynamic records
            if (!fieldPathsForDynamic.isEmpty()) {
              ActionPlansBuilderUtilities.preloadFieldPathValues(
                objectType,
                new Set<Id>(dynamicRecordIds),
                fieldPathsForDynamic
              );
            }
          }
        } catch (Exception e) {
          System.debug(LoggingLevel.ERROR, 'Error processing WHERE clause for template ' + template.Id + ': ' + e.getMessage());
          // Skip this template and continue with others
          continue;
        }
      }
    }

    // Process standard related records
    if (!relatedIDs.isEmpty()) {
      relObjectOwners = ActionPlansBuilderUtilities.retrieveOwnersDataRelatedObject(relatedIDs);
      relRecordNames = ActionPlansUtilities.queryRecordIDToRecordName(relatedIDs);
    }

    Set<String> actionPlanFields = Schema.SObjectType.ActionPlan__c.fields.getMap().keySet();

    // * Copy Template fields to new AP fields
    for (CreateActionPlanRequest r : requests) {
      if (!templateNameOrIdToTemplate.containsKey(r.templateNameOrID)) {
        System.debug(LoggingLevel.WARN, 'Template not found for request: ' + r.templateNameOrID);
        continue;
      }

      System.debug(LoggingLevel.INFO, 'Processing action plan creation for template: ' + r.templateNameOrID);

      ActionPlanTemplate__c actionPlanTemplate = templateNameOrIdToTemplate.get(r.templateNameOrID);

      // Validate configuration for this template and request
      Boolean hasWhereClause = String.isNotBlank(actionPlanTemplate.Where_Clause__c);
      Boolean hasTargetObject = String.isNotBlank(actionPlanTemplate.Target_Object_API_Name__c);
      Boolean hasRecordIds = (r.relatedRecordIDs != null && !r.relatedRecordIDs.isEmpty()) || (r.relatedRecordID != null);
      Boolean hasDynamicRecords = templateIdToDynamicRecordIds.containsKey(actionPlanTemplate.Id);

      System.debug(LoggingLevel.INFO, 'Template validation - WHERE clause: ' + hasWhereClause +
                   ', Target object: ' + hasTargetObject +
                   ', Has record IDs: ' + hasRecordIds +
                   ', Has dynamic records: ' + hasDynamicRecords);

      // If template has WHERE clause, use it to create plans for all matching records
      if (hasWhereClause && hasTargetObject && hasDynamicRecords) {
        System.debug(LoggingLevel.INFO, 'Processing WHERE clause template with ' + templateIdToDynamicRecordIds.get(actionPlanTemplate.Id).size() + ' dynamic records');

        List<Id> dynamicRecordIds = templateIdToDynamicRecordIds.get(actionPlanTemplate.Id);

        // Use a set to track which dynamic records we've already processed for THIS request
        // This is important because ActionPlanTriggerUtility now preserves bulk requests (relatedRecordIDs)
        // AND the WHERE clause might return those same records.
        // We only want to create ONE action plan per record per template.
        Set<Id> recordsProcessedInThisRequest = new Set<Id>();

        for (Id dynamicRecordId : dynamicRecordIds) {
          if (recordsProcessedInThisRequest.contains(dynamicRecordId)) {
            continue;
          }
          recordsProcessedInThisRequest.add(dynamicRecordId);

          ActionPlan__c ap = createActionPlan(
            actionPlanTemplate,
            dynamicRecordId,
            r.actionPlanName,
            r.daysToActionPlanStart,
            relRecordNames.get(dynamicRecordId),
            actionPlanFields
          );

          if (ap != null) {
            // Store the WHERE clause in the action plan
            ap.Where_Clause__c = actionPlanTemplate.Where_Clause__c;
            actionPlansToInsert.add(ap);
          }
        }

      } else if (!hasWhereClause && hasRecordIds) {
        // Process records from either relatedRecordIDs list or single relatedRecordID
        List<Id> recordIdsToProcess = new List<Id>();

        if (r.relatedRecordIDs != null && !r.relatedRecordIDs.isEmpty()) {
          recordIdsToProcess = r.relatedRecordIDs;
          System.debug(LoggingLevel.INFO, 'Processing ' + recordIdsToProcess.size() + ' records from relatedRecordIDs');
        } else if (r.relatedRecordID != null) {
          recordIdsToProcess.add(r.relatedRecordID);
          System.debug(LoggingLevel.INFO, 'Processing single record from relatedRecordID: ' + r.relatedRecordID);
        }

        // Create action plans for all specified records
        for (Id recordId : recordIdsToProcess) {
          ActionPlan__c ap = createActionPlan(
            actionPlanTemplate,
            recordId,
            r.actionPlanName,
            r.daysToActionPlanStart,
            relRecordNames.get(recordId),
            actionPlanFields
          );

          if (ap != null) {
            actionPlansToInsert.add(ap);
          }
        }
      } else {
        // Handle error scenarios
        if (hasWhereClause && !hasTargetObject) {
          System.debug(LoggingLevel.ERROR, 'Template ' + actionPlanTemplate.Name + ' has WHERE clause but no Target_Object_API_Name__c specified');
        } else if (hasWhereClause && hasTargetObject && !hasDynamicRecords) {
          System.debug(LoggingLevel.WARN, 'Template ' + actionPlanTemplate.Name + ' WHERE clause returned no matching records');
        } else if (!hasWhereClause && !hasRecordIds) {
          System.debug(LoggingLevel.ERROR, 'Template ' + actionPlanTemplate.Name + ' has no WHERE clause and no related record IDs provided');
        } else {
          System.debug(LoggingLevel.WARN, 'Skipping template ' + actionPlanTemplate.Name + ' due to configuration mismatch');
        }
      }
    }

    if (actionPlansToInsert.isEmpty()) {
      System.debug(LoggingLevel.WARN, 'No action plans to insert after processing all requests');
      return new List<Id>(createdAPIDs);
    }

    System.debug(LoggingLevel.INFO, 'Inserting ' + actionPlansToInsert.size() + ' action plans');
    insert actionPlansToInsert;
    System.debug(LoggingLevel.INFO, 'Successfully inserted action plans');

    // * Action Plans inserted. Handle APTasks.

    Map<String, APTask__c> planTaskIndexToTask = new Map<String, APTask__c>();
    // Map to track original template TaskIndex to APTask for dependency resolution
    // Key: ActionPlanId + OriginalTaskIndex, Value: APTask__c
    // This handles templates with duplicate TaskIndex values by using the FIRST task with each index
    // for dependency resolution (preserving original behavior for valid templates)
    Map<String, APTask__c> originalIndexToTask = new Map<String, APTask__c>();

    // Cache results of calls that are inside loops
    List<String> customRelationshipFields = ActionPlansUtilities.getCustomRelationshipFields();
    Map<Id, String> taskRecordTypeStatusDefaultValues = ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues();
    Id defaultTaskRecordTypeId = ActionPlansUtilities.getDefaultTaskRecordTypeId();

    // For each Action Plan, if we have a template match, make the ActionPlan tasks
    for (ActionPlan__c ap : actionPlansToInsert) {
      if (ap.Action_Plan_Template__c != null && templateNameOrIdToTemplate.containsKey(ap.Action_Plan_Template__c)) {
        ActionPlanTemplate__c actionPlanTemplate = templateNameOrIdToTemplate.get(ap.Action_Plan_Template__c);

        Integer taskCounter = 0;
        for (APTemplateTask__c aptTask : actionPlanTemplate.aptTasks__r) {
          APTask__c apTask = new APTask__c();

          // Get the assigned user/queue ID
          Id assignedToId = ActionPlansBuilderUtilities.getAPTaskTemplateUser(ap, relObjectOwners, aptTask, actionPlanTemplate);

          // Only assign to User__c if it's a User ID, not a Queue ID
          // Queue IDs start with '00G' and cause FIELD_INTEGRITY_EXCEPTION on User__c field
          if (assignedToId != null && String.valueOf(assignedToId).startsWith('005')) {
            apTask.User__c = assignedToId;
          } else if (assignedToId != null && String.valueOf(assignedToId).startsWith('00G')) {
            System.debug(LoggingLevel.INFO, 'Skipping User__c assignment for Queue ID: ' + assignedToId);
            // Don't assign User__c for Queue IDs as it causes field integrity exception
            apTask.User__c = null;
          } else {
            apTask.User__c = assignedToId;
          }
          apTask.Type__c = aptTask.Type__c;
          apTask.Subject__c = aptTask.Subject__c;
          apTask.Priority__c = aptTask.Priority__c;
          apTask.Dependent__c = aptTask.Dependent__c;
          // Use normalized taskCounter to ensure unique TaskIndex values at runtime
          // This handles templates with duplicate TaskIndex values
          apTask.TaskIndex__c = taskCounter;
          apTask.DaysFromStart__c = aptTask.DaysFromStart__c;
          apTask.Comments__c = aptTask.Comments__c;
          apTask.Reminder__c = aptTask.Reminder__c;
          apTask.Minutes_Reminder__c = aptTask.Minutes_Reminder__c;
          apTask.SendEmail__c = aptTask.SendEmail__c;

          // Set the related record ID on the new TemplateAssignedToId__c field
          // Find the related record ID by checking all relationship fields
          for (String fieldName : customRelationshipFields) {
            if (ap.get(fieldName) != null) {
              // Use put method to set the field value dynamically
              apTask.put('TemplateAssignedToId__c', String.valueOf(ap.get(fieldName)));
              break;
            }
          }

          apTask.Action_Plan__c = ap.Id;

          apTask.Status__c = taskRecordTypeStatusDefaultValues.get(defaultTaskRecordTypeId);

          if (apTask.Dependent__c != null && apTask.Dependent__c != 'None') {
            apTask.ActivityDate__c = null;
          } else {
            apTask.Controller__c = null;

            //set dependency taskId to none if none was selected
            if (apTask.Dependent__c == null) {
              apTask.Dependent__c = 'None';
            }

            // create due date, calculate the due date of the tasks based on DueDateType__c
            if (aptTask.DueDateType__c == 'DateField' && String.isNotBlank(aptTask.DueDateRelatedField__c)) {
              System.debug(LoggingLevel.INFO, '=== CALCULATING DUE DATE FROM FIELD PATH ===');
              System.debug(LoggingLevel.INFO, 'Template Task: ' + aptTask.Subject__c + ', DueDateRelatedField__c: ' + aptTask.DueDateRelatedField__c);

              // Get the related record ID from the action plan
              Id relatedRecordId = null;
              for (String fieldName : customRelationshipFields) {
                if (ap.get(fieldName) != null) {
                  relatedRecordId = (Id) ap.get(fieldName);
                  break;
                }
              }

              if (relatedRecordId == null) {
                System.debug(LoggingLevel.ERROR, 'Could not find related record ID for action plan: ' + ap.Id);
                // Fall back to standard calculation
                if (ap.SkipWeekends__c == true && ap.SkipDay__c != null) {
                  apTask.ActivityDate__c = ActionPlansUtilities.adjustTaskDueDate(ap.StartDate__c, apTask.DaysFromStart__c.intValue(), ap.SkipDay__c);
                } else {
                  apTask.ActivityDate__c = ap.StartDate__c.addDays(apTask.DaysFromStart__c.intValue());
                }
              } else {
                // Get the object type of the related record
                String objectType = relatedRecordId.getSobjectType().getDescribe().getName();

                // Resolve the field path value to get the due date
                Date fieldDate = ActionPlansBuilderUtilities.resolveFieldPathForDueDate(objectType, relatedRecordId, aptTask.DueDateRelatedField__c);

                if (fieldDate != null) {
                  System.debug(LoggingLevel.INFO, 'Successfully resolved field date: ' + fieldDate);

                  // Apply days offset if specified
                  if (apTask.DaysFromStart__c != null && apTask.DaysFromStart__c != 0) {
                    fieldDate = fieldDate.addDays(apTask.DaysFromStart__c.intValue());
                    System.debug(LoggingLevel.INFO, 'Applied days offset (' + apTask.DaysFromStart__c + '): ' + fieldDate);
                  }

                  // Apply weekend skipping if enabled
                  if (ap.SkipWeekends__c == true && ap.SkipDay__c != null) {
                    Date adjustedDate = ActionPlansUtilities.adjustTaskDueDate(fieldDate, 0, ap.SkipDay__c);
                    System.debug(LoggingLevel.INFO, 'Applied weekend skipping: ' + adjustedDate);
                    apTask.ActivityDate__c = adjustedDate;
                  } else {
                    apTask.ActivityDate__c = fieldDate;
                  }
                } else {
                  System.debug(LoggingLevel.ERROR, 'Could not resolve field path for due date, falling back to standard calculation');
                  // Fall back to standard calculation
                  if (ap.SkipWeekends__c == true && ap.SkipDay__c != null) {
                    apTask.ActivityDate__c = ActionPlansUtilities.adjustTaskDueDate(ap.StartDate__c, apTask.DaysFromStart__c.intValue(), ap.SkipDay__c);
                  } else {
                    apTask.ActivityDate__c = ap.StartDate__c.addDays(apTask.DaysFromStart__c.intValue());
                  }
                }
              }
              System.debug(LoggingLevel.INFO, 'Final due date: ' + apTask.ActivityDate__c);
              System.debug(LoggingLevel.INFO, '=== END CALCULATING DUE DATE FROM FIELD PATH ===');
            } else {
              // Standard due date calculation
              if (ap.SkipWeekends__c == true && ap.SkipDay__c != null) {
                apTask.ActivityDate__c = ActionPlansUtilities.adjustTaskDueDate(ap.StartDate__c, apTask.DaysFromStart__c.intValue(), ap.SkipDay__c);
              } else {
                apTask.ActivityDate__c = ap.StartDate__c.addDays(apTask.DaysFromStart__c.intValue());
              }
            }
          }
          // Use taskCounter for unique map key (handles duplicate TaskIndex in templates)
          planTaskIndexToTask.put(ap.Id + '' + taskCounter, apTask);

          // Track original template TaskIndex for dependency resolution
          // Only store the first task with each original index (for valid templates, there's only one)
          String originalIndexKey = ap.Id + '' + aptTask.TaskIndex__c;
          if (!originalIndexToTask.containsKey(originalIndexKey)) {
            originalIndexToTask.put(originalIndexKey, apTask);
          }

          taskCounter++;
        }
      }
    }
    Database.insert(planTaskIndexToTask.values());

    // We update with the controlling/dependent task IDs
    // Use originalIndexToTask for dependency resolution since Dependent__c stores the
    // original template TaskIndex value, not the normalized runtime index

    List<APTask__c> dependentTasksToUpdate = new List<APTask__c>();

    for (APTask__c apTask : planTaskIndexToTask.values()) {
      String actionPlanPlusIndex = apTask.Action_Plan__c + '' + apTask.Dependent__c;

      if (originalIndexToTask.containsKey(actionPlanPlusIndex)) {
        apTask.Controller__c = originalIndexToTask.get(actionPlanPlusIndex).Id;
        dependentTasksToUpdate.add(apTask);
      }
    }

    Database.update(dependentTasksToUpdate);

    List<Task> allTasksToInsert = new List<Task>();

    Map<Id, APTask__c> mapAP = new Map<Id, APTask__c>();
    for (APTask__c a : planTaskIndexToTask.values()) {
      mapAP.put(a.Id, a);
    }

    Map<Id, ActionPlan__c> insertedActionPlans = new Map<Id, ActionPlan__c>();
    for (ActionPlan__c ap : actionPlansToInsert) {
      insertedActionPlans.put(ap.Id, ap);
    }

    for (APTask__c apTask : planTaskIndexToTask.values()) {
      ActionPlan__c insertedAP;
      APTask__c apt = mapAP.get(apTask.Id);

      if (apt != null) {
        insertedAP = insertedActionPlans.get(apt.Action_Plan__c);
      }

      // check if task exists already
      Task t = new Task();
      t.Subject = apTask.Subject__c;
      t.Priority = apTask.Priority__c;
      // Use proper fallback logic when APTask User__c is null (including for Queue IDs)
      if (apTask?.User__c != null) {
        t.OwnerId = apTask.User__c;
      } else {
        // Get the assigned user/queue ID using proper fallback logic
        // If we have the action plan, use it; otherwise use fallback logic
        if (insertedAP != null) {
          t.OwnerId = ActionPlansBuilderUtilities.getAPTaskTemplateUser(insertedAP, relObjectOwners, apTask);
        } else {
          // Fallback when we don't have action plan context - use current user as last resort
          // This should not normally happen, but prevents null OwnerId
          System.debug(LoggingLevel.WARN, 'No Action Plan context available for Task creation, using current user as fallback');
          t.OwnerId = UserInfo.getUserId();
        }
      }
      t.TaskAPTask__c = apTask.Id;

      if (apTask.Comments__c != null) {
        t.Description = apTask.Comments__c;
      }

      //set reminder based on user's default reminder setting
      if (apTask.Reminder__c == true && apTask.ActivityDate__c != null) {
        t.IsReminderSet = true;
        t.ReminderDateTime = Datetime.newInstance(apTask.ActivityDate__c.year(), apTask.ActivityDate__c.month(), apTask.ActivityDate__c.day(), 0, 0, 0);
        t.ReminderDateTime = t.ReminderDateTime.addMinutes(Integer.valueOf(apTask.Minutes_Reminder__c));
      } else {
        t.IsReminderSet = false;
      }

      //link to Action Plan's Related To Object
      for (String s : ActionPlansUtilities.getCustomRelationshipFields()) {
        String f = s;
        if (f == 'Related_Record__c') {
          continue; // skip text fallback when resolving true lookup field
        }

        Id relatedId = (Id) insertedAP.get(f);
        if (relatedId != null) {
          String objName = relatedId.getSObjectType().getDescribe().getName();
          // Task.WhatId cannot be a Contact or Lead (they go to WhoId)
          if (!objName.equalsIgnoreCase('Contact') && !objName.equalsIgnoreCase('Lead')) {
            t.WhatId = relatedId;
            break;
          }
        }
      }
      // Fallback to Related_Record__c if no dedicated lookup field was found
      if (t.WhatId == null && insertedAP.Related_Record__c != null) {
        System.debug('ActionPlanCreateInvocable: No dedicated lookup field found, checking Related_Record__c');
        String relatedRecordValue = insertedAP.Related_Record__c;
        // Related_Record__c stores the record Id as a string when no dedicated lookup exists
        if (relatedRecordValue != null && (relatedRecordValue.length() == 15 || relatedRecordValue.length() == 18)) {
          try {
            Id relatedId = (Id) relatedRecordValue;
            String objName = relatedId.getSObjectType().getDescribe().getName();
            // Task.WhatId cannot be a Contact or Lead
            if (!objName.equalsIgnoreCase('Contact') && !objName.equalsIgnoreCase('Lead')) {
              System.debug('ActionPlanCreateInvocable: Setting Task.WhatId from Related_Record__c: ' + relatedId);
              t.WhatId = relatedId;
            }
          } catch (Exception e) {
            System.debug('ActionPlanCreateInvocable: Related_Record__c is not a valid Id: ' + relatedRecordValue);
          }
        }
      }

      if (insertedAP.Contact__c != null) {
        t.WhoId = insertedAP.Contact__c;
      } else if (insertedAP.Lead__c != null) {
        t.WhoId = insertedAP.Lead__c;
      }

      t.Type = apTask.Type__c;

      if (t.Id == null) {
        t.Status = apTask.Status__c;
      }
      t.ActivityDate = apTask.ActivityDate__c;

      Database.DMLOptions dmlEmail = new Database.DMLOptions();
      dmlEmail.emailHeader.triggerUserEmail = true;

      Database.DMLOptions dmlNoEmail = new Database.DMLOptions();
      dmlEmail.emailHeader.triggerUserEmail = false;

      if (apTask.SendEmail__c == true) {
        t.setOptions(dmlEmail);
        allTasksToInsert.add(t);
      } else {
        t.setOptions(dmlNoEmail);
        allTasksToInsert.add(t);
      }
    }

    insert allTasksToInsert;

    // Collect all AP IDs for Chatter (and for returning)
    for (ActionPlan__c ap : actionPlansToInsert) {
      createdAPIDs.add(ap.Id);
    }

    Action_Plans_Settings__c mySettings = ActionPlansUtilities.getCustomSetting();

    if (mySettings != null && mySettings.Chatter_Object_Brag__c) {
      ActionPlansBuilderUtilities.generateObjectFeeds(createdAPIDs);
    }

    // Finish by returning all created ActionPlan IDs
    return new List<Id>(createdAPIDs);
  }

  /**
   * Helper method to create an Action Plan from a template for a specific record
   * @param actionPlanTemplate The template to use
   * @param relatedId The ID of the related record (can be null if using WHERE clause)
   * @param actionPlanName Custom name for the Action Plan (optional)
   * @param daysToActionPlanStart Days from today to start the Action Plan
   * @param relatedRecordName Name of the related record (for naming)
   * @param actionPlanFields Set of API field names on the ActionPlan__c object
   * @return ActionPlan__c The created Action Plan (not yet inserted)
   */
  private static ActionPlan__c createActionPlan(
    ActionPlanTemplate__c actionPlanTemplate,
    Id relatedId,
    String actionPlanName,
    Integer daysToActionPlanStart,
    String relatedRecordName,
    Set<String> actionPlanFields
  ) {
    ActionPlan__c ap = new ActionPlan__c();
    ap.Name = String.isBlank(actionPlanName)
      ? ActionPlansUtilities.actionPlanSubjectToName(actionPlanTemplate.Name + ' - ' + (relatedRecordName != null ? relatedRecordName : 'Dynamic'))
      : ActionPlansUtilities.actionPlanSubjectToName(actionPlanName);

    ap.Description__c = actionPlanTemplate.Description__c;
    ap.SkipWeekends__c = actionPlanTemplate.SkipWeekends__c;
    ap.SkipDay__c = actionPlanTemplate.SkipDay__c;
    ap.Action_Plan_Template__c = actionPlanTemplate.Id;
    ap.TaskRecordTypeID__c = actionPlanTemplate.TaskRecordTypeID__c;
    ap.StartDate__c = Date.today().addDays(daysToActionPlanStart == null ? 0 : daysToActionPlanStart);

    if (String.isNotBlank(actionPlanTemplate.Where_Clause__c)) {
      ap.Where_Clause__c = actionPlanTemplate.Where_Clause__c;
    }

    for (String s : ActionPlansUtilities.getCustomRelationshipFields()) {
      ap.put(s, null);
    }

    if (relatedId != null) {
      Schema.DescribeSObjectResult sor = ActionPlansUtilities.getRelatedSObjectDescribe(relatedId);
      String relObjName = sor.getName().toLowerCase();
      String relObjLabel = sor.getLabel();

      ap.Related_Object__c = relObjLabel;
      ap.Related_Record__c = (String) relatedId; // Always set the universal text fallback

      Map<String, String> relFieldMap = ActionPlansUtilities.getRelationshipFieldMap();
      String relObjField = relFieldMap.get(relObjName);

      if (relObjField != null && !relObjField.equalsIgnoreCase('Related_Record__c')) {
        ap.put(relObjField, relatedId);
      }
    } else if (String.isNotBlank(actionPlanTemplate.Target_Object_API_Name__c)) {
      // For dynamic WHERE clause, set the Related_Object__c to the object label
      String objName = actionPlanTemplate.Target_Object_API_Name__c;
      try {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objName);
        if (sObjectType != null) {
          ap.Related_Object__c = sObjectType.getDescribe().getLabel();
        }
      } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error getting object label for ' + objName + ': ' + e.getMessage());
      }
    }

    return ap;
  }

  /**
   * Wrapper class for ActionPlan Request for invocable Apex.
   * @author {@link [David Schach](https://github.com/dschach)}
   * @since 2022
   */
  global class CreateActionPlanRequest {
    @InvocableVariable(Required=false Label='The parent Record ID' Description='Must have a relationship named the related record object name from Action Plan object. Not required if template has a WHERE clause.')
      /**
       * The parent Record ID. Must have a relationship named the related record object name from Action Plan object.
       * Not required if the template uses a WHERE clause for dynamic record selection.
       */
    global Id relatedRecordID;

    @InvocableVariable(Required=false Label='The parent Record IDs' Description='List of record IDs to create action plans for. Use this instead of relatedRecordID when processing multiple records.')
      /**
       * The parent Record IDs. List of record IDs to create action plans for.
       * Use this instead of relatedRecordID when processing multiple records.
       * If both are provided, relatedRecordIDs takes precedence.
       */
    global List<Id> relatedRecordIDs;

    @InvocableVariable(Required=false Label='Days from trigger to start Action Plan' Description='Defaults to 0, the day the plan is created')
      /**
       * Days from trigger to start Action Plan. Defaults to 0, the day the plan is created.
       */
    global Integer daysToActionPlanStart;

    @InvocableVariable(Required=true Label='The Template Id or Name to use' Description='Name is not unique, so ID is preferred')
      /**
       * The template Id or Name to use. (Name is not unique, so ID is preferred)
       */
    global String templateNameOrID;

    @InvocableVariable(Required=false Label='Action Plan Name' Description='If not specified, the Action Plan will be called <Template Name> - <Parent Record Name>')
      /**
       * The Action Plan Name. If not specified, the Action Plan will be called <Template Name> - <Parent Record Name>
       */
    global String actionPlanName;
  }
}