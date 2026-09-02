/**
 * Request for comparing the values of {@link SObjectField}s.
 */
public inherited sharing class SObjectFieldDiffRequest {
  private final SObject sobj1;
  private final SObject sobj2;
  private final List<SObjectFieldReference> fieldReferences;

  private SObjectFieldDiffRequest(Builder builder) {
    this.sobj1 = builder.sobj1;
    this.sobj2 = builder.sobj2;
    this.fieldReferences = builder.fieldReferences;
  }

  public SObject getSObj1() {
    return sobj1;
  }

  public SObject getSObj2() {
    return sobj2;
  }

  public List<SObjectFieldReference> getFieldReferences() {
    return fieldReferences;
  }

  public static Builder newBuilder() {
    return new Builder();
  }

  public Builder toBuilder() {
    return new Builder()
      .setSObjects(this.sobj1, this.sobj2)
      .setFieldReferences(this.fieldReferences);
  }

  public class Builder {
    private SObject sobj1;
    private SObject sobj2;
    private List<SObjectFieldReference> fieldReferences = new List<SObjectFieldReference>();

    public Builder setSObjects(SObject sobj1, SObject sobj2) {
      this.sobj1 = sobj1;
      this.sobj2 = sobj2;
      return this;
    }

    public Builder setFieldReferences(List<SObjectFieldReference> fieldReferences) {
      this.fieldReferences = fieldReferences;
      return this;
    }

    public Builder addFieldReference(SObjectFieldReference fieldReference) {
      this.fieldReferences.add(fieldReference);
      return this;
    }

    public Builder addAllFieldReferences(List<SObjectFieldReference> fieldReferences) {
      this.fieldReferences.addAll(fieldReferences);
      return this;
    }

    public Builder addSObjectField(SObjectField sobjectField) {
      this.fieldReferences.add(SObjectFieldReference.create(sobjectField));
      return this;
    }

    public Builder addAllSObjectFields(List<SObjectField> sobjectFields) {
      for (SObjectField sobjectField : sobjectFields) {
        addSObjectField(sobjectField);
      }
      return this;
    }

    public Builder addFieldName(String fieldName) {
      this.fieldReferences.add(SObjectFieldReference.create(fieldName));
      return this;
    }

    public Builder addAllFieldNames(List<String> fieldNames) {
      for (String fieldName : fieldNames) {
        addFieldName(fieldName);
      }
      return this;
    }

    public SObjectFieldDiffRequest build() {
      return new SObjectFieldDiffRequest(this);
    }
  }
}