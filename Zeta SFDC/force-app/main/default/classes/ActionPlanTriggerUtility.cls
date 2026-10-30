/**
 * Utility class for creating action plans from triggers
 * @author AI Assistant
 * @since 2023
 * @group Utilities
 */
public without sharing class ActionPlanTriggerUtility {

    /**
     * Simplified method to create action plans for records in a trigger context
     * Uses global trigger context variables (Trigger.new, Trigger.oldMap, Trigger.operationType)
     * Directly calls ActionPlanCreateInvocable.makeActionPlanFromTemplate for all applicable templates
     * @param sObjectType The SObjectType of the records being processed (e.g., Account.SObjectType)
     */
    public static void invoke(Schema.SObjectType sObjectType) {
        if (Trigger.new == null || Trigger.new.isEmpty()) {
            return;
        }

        // Only proceed for update operations if we need to check field changes
        if (Trigger.isUpdate && Trigger.oldMap == null) {
            return;
        }

        String objectApiName = sObjectType.getDescribe().getName();
        System.debug(LoggingLevel.INFO, 'Creating action plans for object type: ' + objectApiName);

        // Find all templates that might apply to this object type
        // Use dynamic SOQL to avoid compilation errors with new fields
        // We need to query ALL templates, not just those with matching Target_Object_API_Name__c
        // Exclude archived templates
        String query = 'SELECT Id, Name, Where_Clause__c, Target_Object_API_Name__c, Trigger_Fields__c, Description__c ' +
                       'FROM ActionPlanTemplate__c ' +
                       'WHERE Archived__c = false';

        List<ActionPlanTemplate__c> allTemplates = Database.query(query);
        System.debug(LoggingLevel.INFO, 'Found ' + allTemplates.size() + ' total templates in the system');

        for (ActionPlanTemplate__c template : allTemplates) {
            // Pre-populate ActionPlansBuilderUtilities cache
            ActionPlansBuilderUtilities.cacheTemplate(template);
            System.debug(LoggingLevel.INFO, 'Template: ' + template.Name +
                         ', Target Object: ' + template.Target_Object_API_Name__c +
                         ', Trigger Fields: ' + template.get('Trigger_Fields__c') +
                         ', Where Clause: ' + template.Where_Clause__c);
        }

        if (allTemplates.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'No action plan templates found');
            return;
        }

        // Filter templates that apply to this object type
        List<ActionPlanTemplate__c> templates = new List<ActionPlanTemplate__c>();

        for (ActionPlanTemplate__c template : allTemplates) {
            Boolean shouldInclude = false;

            // Include templates where Target_Object_API_Name__c matches the current object
            if (template.Target_Object_API_Name__c == objectApiName) {
                System.debug(LoggingLevel.INFO, 'Template ' + template.Name + ' matches object type ' + objectApiName);
                shouldInclude = true;
            }

            // Check if any trigger fields start with the current object name
            if (!shouldInclude && template.get('Trigger_Fields__c') != null) {
                String triggerFieldsStr = (String)template.get('Trigger_Fields__c');
                System.debug(LoggingLevel.INFO, 'Checking trigger fields for template ' + template.Name + ': ' + triggerFieldsStr);

                if (String.isNotBlank(triggerFieldsStr)) {
                    for (String fieldPath : triggerFieldsStr.split(',')) {
                        String trimmedField = fieldPath.trim().toLowerCase();
                        String objectPrefix = objectApiName.toLowerCase() + '.';

                        System.debug(LoggingLevel.INFO, 'Checking if field ' + trimmedField + ' starts with ' + objectPrefix);

                        if (trimmedField.startsWith(objectPrefix)) {
                            System.debug(LoggingLevel.INFO, 'Found template ' + template.Name + ' with trigger field ' + trimmedField + ' that matches object type ' + objectApiName);
                            shouldInclude = true;
                            break;
                        }
                    }
                }
            }

            // Also check WHERE clause for references to this object
            if (!shouldInclude && String.isNotBlank(template.Where_Clause__c)) {
                String whereClause = template.Where_Clause__c.toLowerCase();
                String objectPrefix = objectApiName.toLowerCase() + '.';

                System.debug(LoggingLevel.INFO, 'Checking if WHERE clause contains ' + objectPrefix + ': ' + whereClause);

                if (whereClause.contains(objectPrefix)) {
                    System.debug(LoggingLevel.INFO, 'Found template ' + template.Name + ' with WHERE clause containing reference to ' + objectApiName);
                    shouldInclude = true;
                }
            }

            if (shouldInclude) {
                templates.add(template);
                System.debug(LoggingLevel.INFO, 'Including template: ' + template.Name + ' (ID: ' + template.Id + ') for object type: ' + objectApiName);
            } else {
                System.debug(LoggingLevel.INFO, 'Excluding template: ' + template.Name + ' (ID: ' + template.Id + ') for object type: ' + objectApiName);
            }
        }

        if (templates.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'No action plan templates found for object type: ' + objectApiName);
            return;
        }

        System.debug(LoggingLevel.INFO, 'Found ' + templates.size() + ' templates for object type: ' + objectApiName);

        // Get all record IDs from the trigger context
        Set<Id> recordIds = new Set<Id>();
        for (SObject record : Trigger.new) {
            recordIds.add((Id)record.get('Id'));
        }

        // Query existing action plans to avoid duplicates
        Map<Id, Set<Id>> existingActionPlans = getExistingActionPlans(templates, recordIds);
        System.debug(LoggingLevel.INFO, 'Found ' + existingActionPlans.size() + ' templates with existing action plans');

        // Create requests for each template and record combination
        List<ActionPlanCreateInvocable.CreateActionPlanRequest> allRequests = new List<ActionPlanCreateInvocable.CreateActionPlanRequest>();

        // Process all templates
        for (ActionPlanTemplate__c template : templates) {
            System.debug(LoggingLevel.INFO, 'Processing template: ' + template.Name + ' (ID: ' + template.Id + ')');

            // Check if this template has trigger fields defined
            Boolean hasTriggerFields = false;
            List<String> triggerFieldPaths = new List<String>();

            // Use get() to avoid compilation errors with new fields
            if (template.get('Trigger_Fields__c') != null) {
                String triggerFieldsStr = (String)template.get('Trigger_Fields__c');
                if (String.isNotBlank(triggerFieldsStr)) {
                    hasTriggerFields = true;
                    // Parse the comma-separated list of field paths
                    for (String fieldPath : triggerFieldsStr.split(',')) {
                        triggerFieldPaths.add(fieldPath.trim());
                    }
                    System.debug(LoggingLevel.INFO, 'Template has trigger fields: ' + triggerFieldPaths);
                }
            }

            // For each record in the trigger context
            for (SObject record : Trigger.new) {
                Boolean shouldApplyTemplate = true;

                // If we're in an insert context and the template has trigger fields,
                // we should only create action plans if the trigger fields have values
                if (Trigger.isInsert && hasTriggerFields) {
                    // For insert, check if the trigger fields have values
                    Boolean hasValues = false;

                    for (String fieldPath : triggerFieldPaths) {
                        try {
                            // Handle relationship fields (e.g., Account.Rating)
                            if (fieldPath.contains('.')) {
                                List<String> pathParts = fieldPath.split('\\.');
                                if (pathParts.size() == 2) {
                                    String relationshipField = pathParts[0];
                                    String targetField = pathParts[1];

                                    // Check if this is a cross-object reference for the current object type
                                    String currentObjectName = objectApiName.toLowerCase();
                                    if (relationshipField.toLowerCase() == currentObjectName) {
                                        // This is a direct field on the current record
                                        Object value = record.get(targetField);

                                        if (value != null && String.isNotBlank(String.valueOf(value))) {
                                            System.debug(LoggingLevel.INFO, 'Field ' + targetField + ' has value: ' + value);
                                            hasValues = true;
                                            break;
                                        }
                                    }
                                }
                            } else {
                                // Direct field on the record
                                Object value = record.get(fieldPath);

                                if (value != null && String.isNotBlank(String.valueOf(value))) {
                                    System.debug(LoggingLevel.INFO, 'Field ' + fieldPath + ' has value: ' + value);
                                    hasValues = true;
                                    break;
                                }
                            }
                        } catch (Exception e) {
                            // Log error but continue processing other fields
                            System.debug(LoggingLevel.ERROR, 'Error checking field ' + fieldPath + ': ' + e.getMessage());
                        }
                    }

                    // Only apply the template if at least one trigger field has a value
                    shouldApplyTemplate = hasValues;

                    if (!shouldApplyTemplate) {
                        System.debug(LoggingLevel.INFO, 'Skipping template for record ' + record.Id + ' because no trigger fields have values');
                    }
                }
                // If we're in an update context and the template has trigger fields
                else if (Trigger.isUpdate && hasTriggerFields) {
                    // Check if any of the trigger fields have changed
                    SObject oldRecord = Trigger.oldMap.get((Id)record.get('Id'));
                    Boolean anyFieldChanged = false;

                    for (String fieldPath : triggerFieldPaths) {
                        try {
                            // Handle relationship fields (e.g., Account.Rating)
                            if (fieldPath.contains('.')) {
                                List<String> pathParts = fieldPath.split('\\.');
                                if (pathParts.size() == 2) {
                                    String relationshipField = pathParts[0];
                                    String targetField = pathParts[1];

                                    // Check if this is a cross-object reference for the current object type
                                    String currentObjectName = objectApiName.toLowerCase();
                                    if (relationshipField.toLowerCase() == currentObjectName) {
                                        // This is a direct field on the current record
                                        Object newValue = record.get(targetField);
                                        Object oldValue = oldRecord.get(targetField);

                                        if (newValue != oldValue) {
                                            System.debug(LoggingLevel.INFO, 'Field changed: ' + targetField + ' from ' + oldValue + ' to ' + newValue);
                                            anyFieldChanged = true;
                                            break;
                                        }
                                    } else if (record.getSObject(relationshipField) != null && oldRecord.getSObject(relationshipField) != null) {
                                        // This is a relationship field on the record
                                        Object newValue = record.getSObject(relationshipField).get(targetField);
                                        Object oldValue = oldRecord.getSObject(relationshipField).get(targetField);

                                        if (newValue != oldValue) {
                                            System.debug(LoggingLevel.INFO, 'Field changed: ' + fieldPath + ' from ' + oldValue + ' to ' + newValue);
                                            anyFieldChanged = true;
                                            break;
                                        }
                                    }
                                }
                            } else {
                                // Direct field on the record
                                Object newValue = record.get(fieldPath);
                                Object oldValue = oldRecord.get(fieldPath);

                                if (newValue != oldValue) {
                                    System.debug(LoggingLevel.INFO, 'Field changed: ' + fieldPath + ' from ' + oldValue + ' to ' + newValue);
                                    anyFieldChanged = true;
                                    break;
                                }
                            }
                        } catch (Exception e) {
                            // Log error but continue processing other fields
                            System.debug(LoggingLevel.ERROR, 'Error checking field ' + fieldPath + ': ' + e.getMessage());
                        }
                    }

                    // Only apply the template if at least one trigger field has changed
                    shouldApplyTemplate = anyFieldChanged;

                    if (!shouldApplyTemplate) {
                        System.debug(LoggingLevel.INFO, 'Skipping template for record ' + record.Id + ' because no trigger fields changed');
                    }
                }

                // If we should apply the template
                if (shouldApplyTemplate) {
                    // For templates without WHERE clauses, create a request for this record
                    if (String.isBlank(template.Where_Clause__c)) {
                        // Check if an action plan already exists for this template and record
                        Set<Id> existingRecordsForTemplate = existingActionPlans.get(template.Id);
                        if (existingRecordsForTemplate == null || !existingRecordsForTemplate.contains(record.Id)) {
                            ActionPlanCreateInvocable.CreateActionPlanRequest request = new ActionPlanCreateInvocable.CreateActionPlanRequest();
                            request.templateNameOrID = template.Id;
                            request.relatedRecordID = (Id)record.get('Id');
                            request.daysToActionPlanStart = 0;

                            // Format the action plan name if the record has a Name field
                            if (record.get('Name') != null) {
                                request.actionPlanName = template.Name + ' - ' + record.get('Name');
                            }

                            allRequests.add(request);
                            System.debug(LoggingLevel.INFO, 'Added request for template ' + template.Id + ' and record ' + record.Id);
                        } else {
                            System.debug(LoggingLevel.INFO, 'Skipping duplicate action plan for template ' + template.Id + ' and record ' + record.Id);
                        }
                    } else {
                        // For templates with WHERE clauses, create a single request with all trigger record IDs
                        // This allows ActionPlanCreateInvocable to filter by both WHERE clause and specific record IDs

                        // First check if we already have a request for this template
                        if (!hasWhereClauseRequestForTemplate(allRequests, template.Id)) {
                            ActionPlanCreateInvocable.CreateActionPlanRequest request = new ActionPlanCreateInvocable.CreateActionPlanRequest();
                            request.templateNameOrID = template.Id;
                            request.relatedRecordIDs = new List<Id>(recordIds); // Pass all trigger record IDs
                            request.daysToActionPlanStart = 0;
                            allRequests.add(request);
                            System.debug(LoggingLevel.INFO, 'Added WHERE clause request for template ' + template.Id + ' with ' + recordIds.size() + ' record IDs');
                        } else {
                            System.debug(LoggingLevel.INFO, 'Skipping duplicate WHERE clause request for template ' + template.Id);
                        }
                    }
                }
            }
        }

        if (!allRequests.isEmpty()) {
            // Before making the call, let's check for existing action plans to avoid duplicates
            // This is a direct approach that doesn't rely on the key-based mechanism

            // First, get all the record IDs from the requests
            Set<Id> requestRecordIds = new Set<Id>();
            List<ActionPlanCreateInvocable.CreateActionPlanRequest> uniqueRequestsList = new List<ActionPlanCreateInvocable.CreateActionPlanRequest>();
            Set<String> duplicateDetectionKeys = new Set<String>();

            for (ActionPlanCreateInvocable.CreateActionPlanRequest req : allRequests) {
                // Handle both single ID and list of IDs for duplicate detection
                if (req.relatedRecordIDs != null && !req.relatedRecordIDs.isEmpty()) {
                    requestRecordIds.addAll(req.relatedRecordIDs);
                    // For WHERE clause requests (which use relatedRecordIDs), we want to keep them as bulk requests
                    // but we still need to check for duplicates among the record IDs they contain
                    List<Id> filteredRecordIds = new List<Id>();
                    for (Id recordId : req.relatedRecordIDs) {
                        String key = req.templateNameOrID + '-' + recordId;
                        if (!duplicateDetectionKeys.contains(key)) {
                            filteredRecordIds.add(recordId);
                            duplicateDetectionKeys.add(key);
                        } else {
                            System.debug(LoggingLevel.INFO, 'Duplicate detected for bulk request: ' + key);
                        }
                    }

                    if (!filteredRecordIds.isEmpty()) {
                        req.relatedRecordIDs = filteredRecordIds;
                        uniqueRequestsList.add(req);
                    }
                } else if (req.relatedRecordID != null) {
                    requestRecordIds.add(req.relatedRecordID);
                    // Handle single record ID
                    String key = req.templateNameOrID + '-' + req.relatedRecordID;
                    if (!duplicateDetectionKeys.contains(key)) {
                        uniqueRequestsList.add(req);
                        duplicateDetectionKeys.add(key);
                    } else {
                        System.debug(LoggingLevel.INFO, 'Duplicate detected for single request: ' + key);
                    }
                }
            }

            // Query for existing action plans and filter uniqueRequestsList
            if (!requestRecordIds.isEmpty()) {
                List<String> relationshipFields = ActionPlansUtilities.getCustomRelationshipFields();
                Set<String> templateIds = new Set<String>();

                for (ActionPlanCreateInvocable.CreateActionPlanRequest req : uniqueRequestsList) {
                    templateIds.add(req.templateNameOrID);
                }

                // Build a query to find existing action plans
                String existingPlansQuery = 'SELECT Id, Action_Plan_Template__c';
                for (String field : relationshipFields) {
                    existingPlansQuery += ', ' + field;
                }
                existingPlansQuery += ' FROM ActionPlan__c WHERE Action_Plan_Template__c IN :templateIds AND (';

                Boolean firstField = true;
                for (String field : relationshipFields) {
                    if (!firstField) {
                        existingPlansQuery += ' OR ';
                    }
                    existingPlansQuery += field + ' IN :requestRecordIds';
                    firstField = false;
                }
                existingPlansQuery += ')';

                System.debug(LoggingLevel.INFO, 'Querying for existing action plans: ' + existingPlansQuery);

                // Execute the query and identify existing template-record pairs
                Set<String> existingKeys = new Set<String>();
                Map<String, Schema.SObjectField> apFieldsMap = Schema.SObjectType.ActionPlan__c.fields.getMap();
                for (ActionPlan__c ap : Database.query(existingPlansQuery)) {
                    for (String field : relationshipFields) {
                        // Allow REFERENCE fields OR the universal Related_Record__c text field
                        Schema.DescribeFieldResult dfr = apFieldsMap.get(field)?.getDescribe();
                        if (dfr == null) {
                            continue;
                        }

                        Boolean isReference = dfr.getType() == Schema.DisplayType.REFERENCE;
                        Boolean isRelatedRecord = field.equalsIgnoreCase('Related_Record__c');

                        if (!isReference && !isRelatedRecord) {
                            continue;
                        }

                        try {
                            Object value = ap.get(field);
                            if (value != null) {
                                String idValue = String.valueOf(value);
                                if (idValue.length() == 15 || idValue.length() == 18) {
                                    // Normalize to 18 characters for consistent key matching
                                    Id recordId = (Id) idValue;
                                    Id templateId = (Id) ap.Action_Plan_Template__c;
                                    existingKeys.add(templateId + '-' + recordId);
                                }
                            }
                        } catch (Exception e) {}
                    }
                }

                allRequests = new List<ActionPlanCreateInvocable.CreateActionPlanRequest>();
                for (ActionPlanCreateInvocable.CreateActionPlanRequest req : uniqueRequestsList) {
                    // Normalize template ID for consistent key matching
                    String normalizedTemplateId = req.templateNameOrID;
                    try {
                        normalizedTemplateId = (String) ((Id) req.templateNameOrID);
                    } catch (Exception e) {
                        // Probably a template name, leave as is
                    }

                    if (req.relatedRecordIDs != null && !req.relatedRecordIDs.isEmpty()) {
                        List<Id> finalRecordIds = new List<Id>();
                        for (Id rid : req.relatedRecordIDs) {
                            if (!existingKeys.contains(normalizedTemplateId + '-' + rid)) {
                                finalRecordIds.add(rid);
                            }
                        }
                        if (!finalRecordIds.isEmpty()) {
                            req.relatedRecordIDs = finalRecordIds;
                            allRequests.add(req);
                        }
                    } else if (req.relatedRecordID != null) {
                        if (!existingKeys.contains(normalizedTemplateId + '-' + req.relatedRecordID)) {
                            allRequests.add(req);
                        }
                    }
                }
                System.debug(LoggingLevel.INFO, 'After filtering duplicates and existing plans, we have ' + allRequests.size() + ' requests');
            } else {
                allRequests = uniqueRequestsList;
            }

            // Now make the call with the filtered requests
            if (!allRequests.isEmpty()) {
                System.debug(LoggingLevel.INFO, 'Calling ActionPlanCreateInvocable.makeActionPlanFromTemplate with ' + allRequests.size() + ' requests');
                try {
                    List<Id> createdPlanIds = ActionPlanCreateInvocable.makeActionPlanFromTemplate(allRequests);
                    System.debug(LoggingLevel.INFO, 'Created ' + createdPlanIds.size() + ' action plans');
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error creating action plans: ' + e.getMessage());
                }
            } else {
                System.debug(LoggingLevel.INFO, 'No requests to process after filtering duplicates');
            }
        }
    }

    /**
     * These methods are deprecated and have been replaced by the simplified invoke method above.
     * The new implementation directly calls ActionPlanCreateInvocable.makeActionPlanFromTemplate
     * which now handles filtering by WHERE clause AND record IDs.
     */

    /**
     * Query existing action plans to avoid duplicates
     * @param templates List of templates to check for existing action plans
     * @param recordIds Set of record IDs in the current trigger context
     * @return Map of unique keys (templateId-recordId) to existing ActionPlan__c records
     */
    private static Map<Id, Set<Id>> getExistingActionPlans(List<ActionPlanTemplate__c> templates, Set<Id> recordIds) {
        Map<Id, Set<Id>> existingActionPlans = new Map<Id, Set<Id>>();

        // Get template IDs
        Set<Id> templateIds = new Set<Id>();
        for (ActionPlanTemplate__c template : templates) {
            templateIds.add(template.Id);
        }

        // Get all relationship fields for ActionPlan__c
        List<String> relationshipFields = ActionPlansUtilities.getCustomRelationshipFields();

        // Build dynamic query to find existing action plans
        String query = 'SELECT Id, Action_Plan_Template__c';

        // Add relationship fields to query
        for (String field : relationshipFields) {
            query += ', ' + field;
        }

        query += ' FROM ActionPlan__c WHERE Action_Plan_Template__c IN :templateIds';

        // Add filter for related records
        if (!recordIds.isEmpty()) {
            query += ' AND (';
            Boolean firstField = true;

            for (String field : relationshipFields) {
                if (!firstField) {
                    query += ' OR ';
                }
                query += field + ' IN :recordIds';
                firstField = false;
            }

            query += ')';
        }

        // Execute query
        Map<String, Schema.SObjectField> apFieldsMap = Schema.SObjectType.ActionPlan__c.fields.getMap();
        for (ActionPlan__c ap : Database.query(query)) {
            Id templateId = ap.Action_Plan_Template__c;
            if (!existingActionPlans.containsKey(templateId)) {
                existingActionPlans.put(templateId, new Set<Id>());
            }

            // Find which related record this action plan is for
            for (String field : relationshipFields) {
                // Allow REFERENCE fields OR the universal Related_Record__c text field
                Schema.DescribeFieldResult dfr = apFieldsMap.get(field)?.getDescribe();
                if (dfr == null) {
                    continue;
                }

                Boolean isReference = dfr.getType() == Schema.DisplayType.REFERENCE;
                Boolean isRelatedRecord = field.equalsIgnoreCase('Related_Record__c');

                if (!isReference && !isRelatedRecord) {
                    continue;
                }

                try {
                    Object value = ap.get(field);
                    if (value != null) {
                        String idValue = String.valueOf(value);
                        if (idValue.length() == 15 || idValue.length() == 18) {
                            existingActionPlans.get(templateId).add((Id)idValue);
                        }
                    }
                } catch (Exception e) {}
            }
        }

        return existingActionPlans;
    }

    /**
     * Check if a WHERE clause request already exists for this template
     * Updated to handle the new relatedRecordIDs field logic
     */
    private static Boolean hasWhereClauseRequestForTemplate(List<ActionPlanCreateInvocable.CreateActionPlanRequest> requests, Id templateId) {
        System.debug(LoggingLevel.INFO, 'Checking for existing WHERE clause request for template: ' + templateId);

        for (ActionPlanCreateInvocable.CreateActionPlanRequest req : requests) {
            if (req.templateNameOrID == templateId) {
                System.debug(LoggingLevel.INFO, 'Found request for template ' + templateId +
                           ', relatedRecordID: ' + req.relatedRecordID +
                           ', relatedRecordIDs: ' + req.relatedRecordIDs);

                // A WHERE clause request has relatedRecordIDs populated (new logic)
                // OR has neither relatedRecordID nor relatedRecordIDs (old logic for backward compatibility)
                if ((req.relatedRecordIDs != null && !req.relatedRecordIDs.isEmpty()) ||
                    (req.relatedRecordID == null && (req.relatedRecordIDs == null || req.relatedRecordIDs.isEmpty()))) {
                    System.debug(LoggingLevel.INFO, 'Found existing WHERE clause request for template: ' + templateId);
                    return true;
                }
            }
        }

        System.debug(LoggingLevel.INFO, 'No existing WHERE clause request found for template: ' + templateId);
        return false;
    }

    /**
     * Check if there are existing action plans for records that would match the WHERE clause
     */
    private static Boolean hasExistingActionPlansForWhereClause(Map<Id, Set<Id>> existingActionPlans, Id templateId, Set<Id> recordIds) {
        Set<Id> existingRecordsForTemplate = existingActionPlans.get(templateId);
        if (existingRecordsForTemplate == null) {
            return false;
        }

        for (Id recordId : recordIds) {
            if (existingRecordsForTemplate.contains(recordId)) {
                System.debug(LoggingLevel.INFO, 'Found existing action plan for template ' + templateId + ' and record ' + recordId);
                return true;
            }
        }
        return false;
    }
}