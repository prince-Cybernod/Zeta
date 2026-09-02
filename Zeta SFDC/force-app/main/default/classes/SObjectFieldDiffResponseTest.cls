/**
 * Tests for {@link SObjectFieldDiffResponse}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldDiffResponseTest {
  @IsTest
  private static void newBuilder_setsAllFields_fieldsHaveExpectedValues() {
    SObjectFieldDiffResponseType responseType = SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT;
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();
    List<SObjectFieldReference> differences = new List<SObjectFieldReference>{ fieldRef };

    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(responseType)
      .setDifferences(differences)
      .build();

    Assert.areEqual(responseType, response.getResponseType());
    Assert.areEqual(differences, response.getDifferences());
  }

  @IsTest
  private static void newBuilder_withAddDifference_differencesHasExpectedValues() {
    SObjectFieldDiffResponseType responseType = SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT;
    SObjectFieldReference fieldRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();

    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(responseType)
      .addDifference(fieldRef)
      .build();

    Assert.areEqual(1, response.getDifferences().size());
    Assert.areEqual(fieldRef, response.getDifferences()[0]);
  }

  @IsTest
  private static void newBuilder_withAddAllDifferences_differencesHasExpectedValues() {
    SObjectFieldDiffResponseType responseType = SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT;
    SObjectFieldReference nameRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();
    SObjectFieldReference typeRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Type)
      .build();
    List<SObjectFieldReference> differences = new List<SObjectFieldReference>{ nameRef, typeRef };

    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(responseType)
      .addAllDifferences(differences)
      .build();

    Assert.areEqual(2, response.getDifferences().size());
    Assert.areEqual(nameRef, response.getDifferences()[0]);
    Assert.areEqual(typeRef, response.getDifferences()[1]);
  }

  @IsTest
  private static void toBuilder_updatesFields_fieldsHaveExpectedValues() {
    SObjectFieldDiffResponseType responseType = SObjectFieldDiffResponseType.FIELDS_ARE_EQUAL;
    SObjectFieldReference nameRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Name)
      .build();

    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(responseType)
      .addDifference(nameRef)
      .build();

    SObjectFieldReference typeRef = SObjectFieldReference.newBuilder()
      .setSObjectField(Account.Type)
      .build();

    SObjectFieldDiffResponse updatedResponse = response.toBuilder()
      .setResponseType(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT)
      .addDifference(typeRef)
      .build();

    Assert.areEqual(
      SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT,
      updatedResponse.getResponseType()
    );
    Assert.areEqual(2, updatedResponse.getDifferences().size());
    Assert.areEqual(nameRef, updatedResponse.getDifferences()[0]);
    Assert.areEqual(typeRef, updatedResponse.getDifferences()[1]);
  }

  @IsTest
  private static void isDifferent_withFieldsAreEqual_returnsFalse() {
    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(SObjectFieldDiffResponseType.FIELDS_ARE_EQUAL)
      .build();

    Boolean isDifferent = response.isDifferent();

    Assert.areEqual(false, isDifferent);
  }

  @IsTest
  private static void isDifferent_withFieldsAreDifferent_returnsTrue() {
    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder()
      .setResponseType(SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT)
      .build();

    Boolean isDifferent = response.isDifferent();

    Assert.areEqual(true, isDifferent);
  }

  @IsTest
  private static void newBuilder_withNoFieldsSet_fieldsHaveDefaultValues() {
    SObjectFieldDiffResponse response = SObjectFieldDiffResponse.newBuilder().build();

    Assert.areEqual(null, response.getResponseType());
    Assert.areEqual(0, response.getDifferences().size());
  }
}