/**
 * Builds and returns an sobject that cannot be constructed.
 */
public with sharing class ReadOnlySObject {
  /**
   * Creates the sobject with the given field values.
   */
  public static SObject create(SObjectType sobjectType, Map<String, Object> fieldValues) {
    SObject sobj = sobjectType.newSObject();
    return setReadOnlyFields(sobj, fieldValues);
  }

  /**
   * Sets the given sobject with the given field values.
   */
  public static SObject create(SObject sobj, Map<String, Object> fieldValues) {
    return setReadOnlyFields(sobj, fieldValues);
  }

  /**
   * Returns a new builder to build an sobject with the given type.
   */
  public static Builder newBuilder(SObjectType sobjectType) {
    return new Builder(sobjectType);
  }

  private static SObject setReadOnlyFields(SObject sobj, Map<String, Object> fieldValues) {
    String str = JSON.serialize(sobj);
    Map<String, Object> record = (Map<String, Object>) JSON.deserializeUntyped(str);

    for (String field : fieldValues.keySet()) {
      Object obj = fieldValues.get(field);
      if (obj instanceof List<SObject>) {
        obj = new QueryResult((List<SObject>) obj);
      }
      record.put(field, obj);
    }

    return (SObject) JSON.deserialize(JSON.serialize(record), SObject.class);
  }

  private class QueryResult {
    private final Integer totalSize;
    private final Boolean done = true;
    private final List<SObject> records;

    private QueryResult(List<SObject> records) {
      this.totalSize = records.size();
      this.records = records;
    }
  }

  public class Builder {
    private final SObjectType sobjectType;
    private final Map<String, Object> fieldValues = new Map<String, Object>();

    public Builder put(String fieldName, Object value) {
      fieldValues.put(fieldName, value);
      return this;
    }

    public Builder putAll(Map<String, Object> fieldValues) {
      this.fieldValues.putAll(fieldValues);
      return this;
    }

    public SObject build() {
      return create(sobjectType, fieldValues);
    }

    private Builder(SObjectType sobjectType) {
      this.sobjectType = sobjectType;
    }
  }
}