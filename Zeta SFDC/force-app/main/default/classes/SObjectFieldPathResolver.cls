/**
 * Resolves {@link SObject} field paths and returns values.
 */
public with sharing class SObjectFieldPathResolver {
  /**
   * Returns the value of the field at the specified path.
   */
  public static Object getValue(SObject sobj, String fieldPath) {
    if (sobj == null || String.isBlank(fieldPath)) {
      return null;
    }

    // Split the field path into parts (e.g., "Account.Name" -> ["Account", "Name"])
    List<String> pathParts = fieldPath.split('\\.');

    SObject currentSObject = sobj;

    // Stop before the final field because it contains the value.
    // Fields before it are objects in the relationship (e.g. "Account" in "Account.Name").
    for (Integer i = 0; i < pathParts.size() - 1; i++) {
      if (currentSObject == null) {
        return null;
      }

      // Move to the next object in the relationship
      currentSObject = currentSObject.getSObject(pathParts[i]);
    }

    // If the final record is null, return null
    if (currentSObject == null) {
      return null;
    }

    // The last field in the path contains the value
    String finalField = pathParts[pathParts.size() - 1];

    return currentSObject.get(finalField);
  }
}