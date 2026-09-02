/**
 * Tests for {@link SObjectFieldDiffRequest}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldDiffRequestTest {
  @IsTest
  private static void newBuilder_setsAllFields_fieldsHaveExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();
    List<SObjectFieldReference> fieldRefs = new List<SObjectFieldReference>{ fieldRef };

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .setFieldReferences(fieldRefs)
      .build();

    Assert.areEqual(acc1, request.getSObj1());
    Assert.areEqual(acc2, request.getSObj2());
    Assert.areEqual(fieldRefs, request.getFieldReferences());
  }

  @IsTest
  private static void newBuilder_withAddFieldReference_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addFieldReference(fieldRef)
      .build();

    Assert.areEqual(1, request.getFieldReferences().size());
    Assert.areEqual(fieldRef, request.getFieldReferences()[0]);
  }

  @IsTest
  private static void newBuilder_withAddAllFieldReferences_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectFieldReference nameRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();
    SObjectFieldReference typeRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Type)
      .build();
    List<SObjectFieldReference> fieldRefs = new List<SObjectFieldReference>{ nameRef, typeRef };

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addAllFieldReferences(fieldRefs)
      .build();

    Assert.areEqual(2, request.getFieldReferences().size());
    Assert.areEqual(nameRef, request.getFieldReferences()[0]);
    Assert.areEqual(typeRef, request.getFieldReferences()[1]);
  }

  @IsTest
  private static void newBuilder_withAddSObjectField_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectField field = Account.Type;

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addSObjectField(field)
      .build();

    Assert.areEqual(1, request.getFieldReferences().size());
    Assert.areEqual(field, request.getFieldReferences()[0].getSObjectField());
  }

  @IsTest
  private static void newBuilder_withAddAllSObjectFields_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    List<SObjectField> fields = new List<SObjectField>{ Account.Name, Account.Type };

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addAllSObjectFields(fields)
      .build();

    Assert.areEqual(2, request.getFieldReferences().size());
    Assert.areEqual(Account.Name, request.getFieldReferences()[0].getSObjectField());
    Assert.areEqual(Account.Type, request.getFieldReferences()[1].getSObjectField());
  }

  @IsTest
  private static void newBuilder_withAddFieldName_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    String fieldName = 'Name';

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addFieldName(fieldName)
      .build();

    Assert.areEqual(1, request.getFieldReferences().size());
    Assert.areEqual(fieldName, request.getFieldReferences()[0].getFieldName());
  }

  @IsTest
  private static void newBuilder_withAddAllFieldNames_fieldReferencesHasExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    List<String> fields = new List<String>{ 'Name', 'Type' };

    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addAllFieldNames(fields)
      .build();

    Assert.areEqual(2, request.getFieldReferences().size());
    Assert.areEqual('Name', request.getFieldReferences()[0].getFieldName());
    Assert.areEqual('Type', request.getFieldReferences()[1].getFieldName());
  }

  @IsTest
  private static void toBuilder_updatesFields_fieldsHaveExpectedValues() {
    Account acc1 = new Account(Name = 'Test Account 1');
    Account acc2 = new Account(Name = 'Test Account 2');
    SObjectFieldReference nameRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();
    SObjectFieldDiffRequest request = SObjectFieldDiffRequest.newBuilder()
      .setSObjects(acc1, acc2)
      .addFieldReference(nameRef)
      .build();
    Account acc3 = new Account(Name = 'Test Account 3');
    SObjectFieldReference typeRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Type)
      .build();

    SObjectFieldDiffRequest updatedRequest = request.toBuilder()
      .setSObjects(acc1, acc3)
      .addFieldReference(typeRef)
      .build();

    Assert.areEqual(acc1, updatedRequest.getSObj1());
    Assert.areEqual(acc3, updatedRequest.getSObj2());
    Assert.areEqual(2, updatedRequest.getFieldReferences().size());
    Assert.areEqual(nameRef, updatedRequest.getFieldReferences()[0]);
    Assert.areEqual(typeRef, updatedRequest.getFieldReferences()[1]);
  }
}