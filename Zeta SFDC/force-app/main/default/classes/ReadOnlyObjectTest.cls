/**
 * Tests for {@link ReadOnlyObject}.
 */
@IsTest(IsParallel=true)
private class ReadOnlyObjectTest {
  @IsTest
  private static void create_withFieldValues_createsReadOnlyObject() {
    Type clazz = Database.DeleteResult.class;
    Map<String, Object> fieldValues = new Map<String, Object>{
      'id' => UserInfo.getUserId(),
      'success' => true
    };

    Database.DeleteResult deleteResult = (Database.DeleteResult) ReadOnlyObject.create(
      clazz,
      fieldValues
    );

    Assert.isTrue(deleteResult.isSuccess());
    Assert.areEqual(UserInfo.getUserId(), deleteResult.getId());
  }

  @IsTest
  private static void builder_createsReadOnlyObject() {
    Type clazz = Database.DeleteResult.class;
    ReadOnlyObject.Builder builder = ReadOnlyObject.newBuilder(clazz)
      .put('id', UserInfo.getUserId())
      .put('success', true);

    Database.DeleteResult deleteResult = (Database.DeleteResult) builder.build();

    System.assertEquals(true, deleteResult.isSuccess());
    System.assertEquals(UserInfo.getUserId(), deleteResult.getId());
  }
}