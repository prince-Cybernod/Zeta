/**
 * Checks for differences between {@link Object}s.
 */
public with sharing class ObjectDiffer {
  public static ObjectDiffResponse getDiff(Object obj1, Object obj2) {
    ObjectDiffResponse.Builder builder = ObjectDiffResponse.newBuilder();

    if (obj1 == null && obj2 == null) {
      return builder.setResponseType(ObjectDiffResponseType.BOTH_OBJECTS_ARE_NULL).build();
    }

    if (obj1 == null || obj2 == null) {
      return builder.setResponseType(ObjectDiffResponseType.ONE_OBJECT_IS_NULL).build();
    }

    if (obj1.equals(obj2)) {
      return builder.setResponseType(ObjectDiffResponseType.OBJECTS_ARE_EQUAL).build();
    }

    return builder.setResponseType(ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT).build();
  }
}