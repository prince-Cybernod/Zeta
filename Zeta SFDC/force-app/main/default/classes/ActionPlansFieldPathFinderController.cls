/**
 * Controller for the APFieldPathFinder component
 * @author David Schach
 */
public with sharing class ActionPlansFieldPathFinderController {

    
    /**
     * Gets all user lookup fields for a given object, including fields up to 5 levels deep
     * @param objectName The API name of the object
     * @return Map<String, String> Map of field API names to field labels
     */
    @RemoteAction
    public static Map<String, String> getUserLookupFieldsRemote(String objectName) {
        return ActionPlanTemplateCreationController.getUserLookupFieldsRemote(objectName);
    }
    
    /**
     * Gets all date fields for a given object
     * @param objectName The API name of the object
     * @return Map<String, String> Map of field API names to field labels
     */
    @RemoteAction
    public static Map<String, String> getDateFieldsRemote(String objectName) {
        return ActionPlanTemplateCreationController.getDateFieldsRemote(objectName);
    }

    
    /**
     * Gets all date fields for a given object, including fields up to 5 levels deep
     * Returns both field name and relationship name to allow frontend to decide which to use
     * @param objectName The API name of the object
     * @return Map<String, Map<String, Object>> Map of field paths to field details (fieldName, relationshipName, label)
     */
    @RemoteAction
    public static Map<String, Map<String, Object>> getDateFieldsWithRelationshipsRemote(String objectName) {
        return ActionPlanTemplateCreationController.getDateFieldsWithRelationshipsRemote(objectName);
    }

    /**
     * Gets all user lookup fields for a given object, including fields up to 5 levels deep
     * Returns both field name and relationship name to allow frontend to decide which to use
     * @param objectName The API name of the object
     * @return Map<String, Map<String, Object>> Map of field paths to field details (fieldName, relationshipName, label)
     */
    @RemoteAction
    public static Map<String, Map<String, Object>> getUserLookupFieldsWithRelationshipsRemote(String objectName) {
        return ActionPlanTemplateCreationController.getUserLookupFieldsWithRelationshipsRemote(objectName);
    }
    
    /**
     * Validates a related field path
     * @param objectName The API name of the starting object
     * @param fieldPath The field path to validate (e.g., "Account.Owner.Name")
     * @return Map<String, Object> with validation results (success, message)
     */
    @RemoteAction
    public static Map<String, Object> validateFieldPathRemote(String objectName, String fieldPath) {
        return ActionPlanTemplateCreationController.validateFieldPathRemote(objectName, fieldPath);
    }
}