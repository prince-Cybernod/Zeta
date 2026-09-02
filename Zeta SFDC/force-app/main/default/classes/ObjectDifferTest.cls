/**
 * Tests for {@link ObjectDiffer}.
 */
@IsTest(IsParallel=true)
private class ObjectDifferTest {
  @IsTest
  private static void getDiff_withObjectsAreEqual_returnsObjectsAreEqual() {
    Object obj1 = 'test';
    Object obj2 = 'test';

    ObjectDiffResponse response = ObjectDiffer.getDiff(obj1, obj2);

    Assert.areEqual(ObjectDiffResponseType.OBJECTS_ARE_EQUAL, response.getResponseType());
  }

  @IsTest
  private static void getDiff_withObjectsAreDifferent_returnsObjectsAreDifferent() {
    Object obj1 = 'test';
    Object obj2 = 'test2';

    ObjectDiffResponse response = ObjectDiffer.getDiff(obj1, obj2);

    Assert.areEqual(ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT, response.getResponseType());
  }

  @IsTest
  private static void getDiff_withOneObjectIsNull_returnsOneObjectIsNull() {
    Object obj1 = 'test';
    Object obj2 = null;

    ObjectDiffResponse response = ObjectDiffer.getDiff(obj1, obj2);

    Assert.areEqual(ObjectDiffResponseType.ONE_OBJECT_IS_NULL, response.getResponseType());
  }

  @IsTest
  private static void getDiff_withBothObjectsAreNull_returnsBothObjectsAreNull() {
    Object obj1 = null;
    Object obj2 = null;

    ObjectDiffResponse response = ObjectDiffer.getDiff(obj1, obj2);

    Assert.areEqual(ObjectDiffResponseType.BOTH_OBJECTS_ARE_NULL, response.getResponseType());
  }
}