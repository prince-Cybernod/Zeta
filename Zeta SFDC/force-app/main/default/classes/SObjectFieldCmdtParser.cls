/**
 * Parses SObject_Field__mdt custom metadata to extract information.
 */
public with sharing class SObjectFieldCmdtParser {
  /**
   * Returns the SObjectField token for the given field metadata.
   *
   * @param fieldMetadata The field metadata to parse
   * @return The SObjectField token
   * @throws IllegalArgumentException if field metadata is null or invalid
   */
  public static SObjectField getSObjectField(SObject_Field__mdt fieldMetadata) {
    Preconditions.checkNotNull(fieldMetadata, 'SObject Field CMDT cannot be null');

    SObjectType sobjectType = getSObjectType(fieldMetadata);
    String fieldName = getFieldName(fieldMetadata);
    Preconditions.checkNotBlank(fieldName, 'Must have a Field Definition or Entity Particle');

    DescribeSObjectResult describe = SObjectDescribes.get(sobjectType);
    Map<String, SObjectField> fieldMap = describe.fields.getMap();

    Preconditions.checkArgument(
      fieldMap.containsKey(fieldName),
      String.format('Field {0} not found on {1}', new List<Object>{ fieldName, sobjectType })
    );

    return fieldMap.get(fieldName);
  }

  /**
   * Returns the SObjectType token for the given field metadata.
   *
   * @param fieldMetadata The field metadata to parse
   * @return The SObjectType token
   * @throws IllegalArgumentException if field metadata is null or invalid
   */
  public static SObjectType getSObjectType(SObject_Field__mdt fieldMetadata) {
    Preconditions.checkNotNull(fieldMetadata, 'SObject Field CMDT cannot be null');

    String sobjectName = fieldMetadata.Entity_Definition__r?.QualifiedApiName;
    Preconditions.checkNotBlank(sobjectName, 'Must have an Entity Definition');

    DescribeSObjectResult describe = SObjectDescribes.get(sobjectName);
    Preconditions.checkNotNull(
      describe,
      String.format('SObjectType {0} not found', new List<Object>{ sobjectName })
    );

    return describe.getSObjectType();
  }

  private static String getFieldName(SObject_Field__mdt fieldMetadata) {
    String fieldName = null;
    if (fieldMetadata.Field_Definition__r != null) {
      fieldName = fieldMetadata.Field_Definition__r.QualifiedApiName;
    } else if (fieldMetadata.Entity_Particle__r != null) {
      fieldName = fieldMetadata.Entity_Particle__r.QualifiedApiName;
    }

    if (String.isBlank(fieldName)) {
      return null;
    }

    if (fieldName.contains('.')) {
      return fieldName.substringAfter('.');
    }

    return fieldName;
  }
}