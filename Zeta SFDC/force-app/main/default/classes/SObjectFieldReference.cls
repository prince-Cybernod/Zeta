/**
 * Represents a reference to an SObject field, either via {@link SObjectField} or a {@link String}.
 */
public with sharing class SObjectFieldReference {
  private final SObjectField sobjectField;
  private String fieldName; // Delayed initialization
  private final SObjectFieldReferenceType type;

  private SObjectFieldReference(Builder builder, SObjectFieldReferenceType type) {
    this.sobjectField = builder.sobjectField;
    this.fieldName = builder.fieldName;
    this.type = type;
  }

  public SObjectField getSObjectField() {
    return sobjectField;
  }

  public String getFieldName() {
    if (String.isBlank(fieldName) && sobjectField != null) {
      // Delaying the describe until the field name is needed
      fieldName = sobjectField.getDescribe().getName();
    }

    return fieldName;
  }

  public SObjectFieldReferenceType getType() {
    return type;
  }

  public static Builder newBuilder() {
    return new Builder();
  }

  public Builder toBuilder() {
    return new Builder().setSObjectField(sobjectField).setFieldName(fieldName);
  }

  public static SObjectFieldReference create(SObjectField sobjectField) {
    return newBuilder().setSObjectField(sobjectField).build();
  }

  public static SObjectFieldReference create(String fieldName) {
    return newBuilder().setFieldName(fieldName).build();
  }

  public class Builder {
    private SObjectField sobjectField;
    private String fieldName;

    private Builder() {
    }

    public Builder setSObjectField(SObjectField sobjectField) {
      this.sobjectField = sobjectField;
      return this;
    }

    public Builder setFieldName(String fieldName) {
      this.fieldName = fieldName;
      return this;
    }

    public SObjectFieldReference build() {
      Preconditions.checkArgument(
        String.isNotBlank(fieldName) || sobjectField != null,
        'Expected either a field name or an SObjectField to be provided.'
      );

      SObjectFieldReferenceType type = sobjectField != null
        ? SObjectFieldReferenceType.SOBJECT_FIELD
        : SObjectFieldReferenceType.FIELD_NAME;

      return new SObjectFieldReference(this, type);
    }
  }
}