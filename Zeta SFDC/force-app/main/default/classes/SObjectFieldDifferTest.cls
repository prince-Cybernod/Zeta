/**
 * Tests for {@link SObjectFieldDiffer}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldDifferTest {
  @IsTest
  private static void getFieldDiff_oneField_returnsFieldDiff() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectField field = Schema.Account.Name;

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, field);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual(Schema.Account.Name, response.getDifferences()[0].getSObjectField());
  }

  @IsTest
  private static void getFieldDiff_sobjectsAndFieldsUsingShorthand_returnsFieldDiff() {
    Account acc1 = new Account(Name = 'Test Account 1', Type = 'Customer');
    Account acc2 = new Account(Name = 'Test Account 2', Type = 'Customer');
    List<SObjectField> fields = new List<SObjectField>{ Schema.Account.Name, Schema.Account.Type };

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, fields);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual(Schema.Account.Name, response.getDifferences()[0].getSObjectField());
  }

  @IsTest
  private static void getFieldDiff_identicalSObjects_returnsFieldsAreEqual() {
    Account acc1 = new Account(Name = 'Test Account', Type = 'Customer');
    Account acc2 = new Account(Name = 'Test Account', Type = 'Customer');
    List<SObjectField> fields = new List<SObjectField>{ Schema.Account.Name, Schema.Account.Type };

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, fields);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_EQUAL, response.getResponseType());
    Assert.areEqual(0, response.getDifferences().size());
  }

  @IsTest
  private static void getFieldDiff_bothSObjectsNull_returnsBothSObjectsAreNull() {
    Account acc1 = null;
    Account acc2 = null;
    List<SObjectField> fields = new List<SObjectField>{ Schema.Account.Name };

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, fields);

    Assert.areEqual(
      SObjectFieldDiffResponseType.BOTH_SOBJECTS_ARE_NULL,
      response.getResponseType()
    );
    Assert.areEqual(0, response.getDifferences().size());
  }

  @IsTest
  private static void getFieldDiff_oneSObjectNull_returnsOneSObjectIsNull() {
    Account acc1 = new Account(Name = 'Test Account');
    Account acc2 = null;
    List<SObjectField> fields = new List<SObjectField>{ Schema.Account.Name };

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, fields);

    Assert.areEqual(SObjectFieldDiffResponseType.ONE_SOBJECT_IS_NULL, response.getResponseType());
    Assert.areEqual(0, response.getDifferences().size());
  }

  @IsTest
  private static void getFieldDiff_withRequest_returnsFieldDiff() {
    Account acc1 = new Account(Name = 'Test Account 1', Type = 'Customer');
    Account acc2 = new Account(Name = 'Test Account 2', Type = 'Customer');
    SObjectFieldReference nameRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Schema.Account.Name)
      .build();
    SObjectFieldReference typeRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Schema.Account.Type)
      .build();
    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addFieldReference(nameRef)
      .addFieldReference(typeRef)
      .build();

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(request);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual(Schema.Account.Name, response.getDifferences()[0].getSObjectField());
  }

  @IsTest
  private static void getFieldDiff_withFieldNameReference_returnsFieldDiff() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setFieldName('Name')
      .build();
    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addFieldReference(fieldRef)
      .build();

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(request);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual('Name', response.getDifferences()[0].getFieldName());
  }

  @IsTest
  private static void getFieldDiff_withRelationshipFieldPath_returnsFieldDiff() {
    Account childAccount1 = new Account(
      Name = 'Child Account',
      Parent = new Account(Name = 'Parent Account 1')
    );
    Account childAccount2 = new Account(
      Name = 'Child Account',
      Parent = new Account(Name = 'Parent Account 2')
    );
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setFieldName('Parent.Name')
      .build();
    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(childAccount1, childAccount2)
      .addFieldReference(fieldRef)
      .build();

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(request);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual('Parent.Name', response.getDifferences()[0].getFieldName());
  }

  @IsTest
  private static void getFieldDiff_withMultipleFields_onlyReturnsDifferentFields() {
    Account acc1 = new Account(Name = 'Test Account 1', Type = 'Customer', Phone = '123-456-7890');
    Account acc2 = new Account(Name = 'Test Account 2', Type = 'Customer', Phone = '123-456-7890');
    List<SObjectField> fields = new List<SObjectField>{
      Schema.Account.Name,
      Schema.Account.Type,
      Schema.Account.Phone
    };

    SObjectFieldDiffResponse response = SObjectFieldDiffer.getFieldDiff(acc1, acc2, fields);

    Assert.areEqual(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT, response.getResponseType());
    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual(Schema.Account.Name, response.getDifferences()[0].getSObjectField());
  }
}