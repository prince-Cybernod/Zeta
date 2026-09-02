/**
 * Tests for {@link ObjectDiffResponse}.
 */
@IsTest(IsParallel=true)
private class ObjectDiffResponseTest {
  @IsTest
  private static void newBuilder_setsAllFields_fieldsHaveExpectedValues() {
    ObjectDiffResponse.Builder builder = ObjectDiffResponse.newBuilder();

    ObjectDiffResponse response = builder.setResponseType(
        ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT
      )
      .build();

    Assert.areEqual(ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT, response.getResponseType());
  }

  @IsTest
  private static void toBuilder_updatesFields_fieldsHaveExpectedValues() {
    ObjectDiffResponse response = ObjectDiffResponse.newBuilder()
      .setResponseType(ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT)
      .build();

    ObjectDiffResponse updatedResponse = response.toBuilder()
      .setResponseType(ObjectDiffResponseType.OBJECTS_ARE_EQUAL)
      .build();

    Assert.areEqual(ObjectDiffResponseType.OBJECTS_ARE_EQUAL, updatedResponse.getResponseType());
  }

  @IsTest
  private static void isDifferent_withObjectsAreEqual_returnsFalse() {
    ObjectDiffResponse response = ObjectDiffResponse.newBuilder()
      .setResponseType(ObjectDiffResponseType.OBJECTS_ARE_EQUAL)
      .build();

    Boolean isDifferent = response.isDifferent();

    Assert.areEqual(false, isDifferent);
  }

  @IsTest
  private static void isDifferent_withObjectsAreDifferent_returnsTrue() {
    ObjectDiffResponse response = ObjectDiffResponse.newBuilder()
      .setResponseType(ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT)
      .build();

    Boolean isDifferent = response.isDifferent();

    Assert.areEqual(true, isDifferent);
  }
}