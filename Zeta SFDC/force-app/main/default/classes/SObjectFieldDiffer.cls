/**
 * Checks for differences between {@link SObject} fields.
 */
public with sharing class SObjectFieldDiffer {
  /**
   * Returns information about a field difference between two {@link SObject}s.
   */
  public static SObjectFieldDiffResponse getFieldDiff(
    SObject sobj1,
    SObject sobj2,
    SObjectField field
  ) {
    return getFieldDiff(sobj1, sobj2, new List<SObjectField>{ field });
  }

  /**
   * Returns information about field differences between two {@link SObject}s.
   */
  public static SObjectFieldDiffResponse getFieldDiff(
    SObject sobj1,
    SObject sobj2,
    List<SObjectField> fields
  ) {
    List<SObjectFieldReference> diffFields = new List<SObjectFieldReference>();
    for (SObjectField field : fields) {
      diffFields.add(SObjectFieldReference.create(field));
    }

    return getFieldDiff(
      SObjectFieldDiffRequest.newBuilder()
        .setSObjects(sobj1, sobj2)
        .setFieldReferences(diffFields)
        .build()
    );
  }

  /**
   * Returns information about field differences based on the request.
   */
  public static SObjectFieldDiffResponse getFieldDiff(SObjectFieldDiffRequest request) {
    SObjectFieldDiffResponse.Builder responseBuilder = SObjectFieldDiffResponse.newBuilder();

    SObject sobj1 = request.getSObj1();
    SObject sobj2 = request.getSObj2();

    switch on ObjectDiffer.getDiff(sobj1, sobj2).getResponseType() {
      when BOTH_OBJECTS_ARE_NULL {
        return responseBuilder
          .setResponseType(SObjectFieldDiffResponseType.BOTH_SOBJECTS_ARE_NULL)
          .build();
      }
      when ONE_OBJECT_IS_NULL {
        return responseBuilder
          .setResponseType(SObjectFieldDiffResponseType.ONE_SOBJECT_IS_NULL)
          .build();
      }
    }

    Boolean hasDifference = false;
    for (SObjectFieldReference diffField : request.getFieldReferences()) {
      Object value1;
      Object value2;

      switch on diffField.getType() {
        when SOBJECT_FIELD {
          value1 = sobj1.get(diffField.getSObjectField());
          value2 = sobj2.get(diffField.getSObjectField());
        }
        when FIELD_NAME {
          value1 = SObjectFieldPathResolver.getValue(sobj1, diffField.getFieldName());
          value2 = SObjectFieldPathResolver.getValue(sobj2, diffField.getFieldName());
        }
      }

      if (ObjectDiffer.getDiff(value1, value2).isDifferent()) {
        hasDifference = true;
        responseBuilder.addDifference(diffField);
      }
    }

    if (hasDifference) {
      responseBuilder.setResponseType(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT);
    } else {
      responseBuilder.setResponseType(SObjectFieldDiffResponseType.FIELDS_ARE_EQUAL);
    }

    return responseBuilder.build();
  }
}