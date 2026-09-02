/**
 * Tests for {@link SObjectFieldReference}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldReferenceTest {
  @IsTest
  private static void newBuilder_withSObjectField_fieldsHaveExpectedValues() {
    SObjectField field = Account.Name;

    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setSObjectField(field)
      .build();

    Assert.areEqual(field, reference.getSObjectField());
    Assert.areEqual('Name', reference.getFieldName());
    Assert.areEqual(SObjectFieldReferenceType.SOBJECT_FIELD, reference.getType());
  }

  @IsTest
  private static void newBuilder_withFieldName_fieldsHaveExpectedValues() {
    String fieldName = 'Name';

    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setFieldName(fieldName)
      .build();

    Assert.areEqual(null, reference.getSObjectField());
    Assert.areEqual(fieldName, reference.getFieldName());
    Assert.areEqual(SObjectFieldReferenceType.FIELD_NAME, reference.getType());
  }

  @IsTest
  private static void newBuilder_withNullSObjectFieldAndNullFieldName_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected either a field name or an SObjectField to be provided.'
    );

    try {
      SObjectFieldReference.newBuilder().build();
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void toBuilder_updatesFieldName_fieldHasExpectedValue() {
    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setFieldName('Name')
      .build();

    SObjectFieldReference updatedReference = reference.toBuilder()
      .setFieldName('CustomField')
      .build();

    Assert.areEqual('CustomField', updatedReference.getFieldName());
  }

  @IsTest
  private static void toBuilder_updatesSObjectField_fieldHasExpectedValue() {
    String fieldName = 'Name';
    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setFieldName(fieldName)
      .build();

    SObjectFieldReference updatedReference = reference.toBuilder()
      .setSObjectField(Account.Name)
      .build();

    Assert.areEqual(Account.Name, updatedReference.getSObjectField());
    Assert.areEqual(fieldName, updatedReference.getFieldName());
    Assert.areEqual(SObjectFieldReferenceType.SOBJECT_FIELD, updatedReference.getType());
  }

  @IsTest
  private static void getType_withNoFieldsSet_returnsNull() {
    SObjectFieldReference reference = (SObjectFieldReference) JSON.deserialize(
      JSON.serialize(new Map<String, Object>()),
      SObjectFieldReference.class
    );

    SObjectFieldReferenceType type = reference.getType();

    Assert.areEqual(null, type);
  }

  @IsTest
  private static void getType_withSObjectField_returnsExpectedValue() {
    SObjectField field = Account.Name;
    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setSObjectField(field)
      .build();

    SObjectFieldReferenceType type = reference.getType();

    Assert.areEqual(SObjectFieldReferenceType.SOBJECT_FIELD, type);
  }

  @IsTest
  private static void getType_withFieldName_returnsExpectedValue() {
    String fieldName = 'Name';
    SObjectFieldReference reference = SObjectFieldReference.newBuilder()
      .setFieldName(fieldName)
      .build();

    SObjectFieldReferenceType type = reference.getType();

    Assert.areEqual(SObjectFieldReferenceType.FIELD_NAME, type);
  }

  @IsTest
  private static void create_withSObjectField_returnsExpectedValue() {
    SObjectField field = Account.Name;

    SObjectFieldReference reference = SObjectFieldReference.create(field);

    Assert.areEqual(field, reference.getSObjectField());
    Assert.areEqual('Name', reference.getFieldName());
    Assert.areEqual(SObjectFieldReferenceType.SOBJECT_FIELD, reference.getType());
  }

  @IsTest
  private static void create_withFieldName_returnsExpectedValue() {
    String fieldName = 'Name';

    SObjectFieldReference reference = SObjectFieldReference.create(fieldName);

    Assert.areEqual(null, reference.getSObjectField());
    Assert.areEqual(fieldName, reference.getFieldName());
    Assert.areEqual(SObjectFieldReferenceType.FIELD_NAME, reference.getType());
  }
}