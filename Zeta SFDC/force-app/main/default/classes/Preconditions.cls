/**
 * Convenience methods for a method or constructor to check if it was invoked correctly.
 *
 * Inspired by Guava Preconditions
 * @see https://guava.dev/releases/19.0/api/docs/com/google/common/base/Preconditions.html
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters,PMD.ExcessivePublicCount')
public with sharing class Preconditions {
  /**
   * Throws an {@link IllegalArgumentException} when the expression is false.
   */
  public static void checkArgument(Boolean expression) {
    if (!expression) {
      throw new IllegalArgumentException();
    }
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the expression is false.
   */
  public static void checkArgument(Boolean expression, String errorMessage) {
    if (!expression) {
      throw new IllegalArgumentException(errorMessage);
    }
  }

  /**
   * Throws an {@link IllegalStateException} when the expression is false.
   */
  public static void checkState(Boolean expression) {
    if (!expression) {
      throw new IllegalStateException();
    }
  }

  /**
   * Throws an {@link IllegalStateException} with the error message when the expression is false.
   */
  public static void checkState(Boolean expression, String errorMessage) {
    if (!expression) {
      throw new IllegalStateException(errorMessage);
    }
  }

  /**
   * Throws an {@link NullPointerException} when the object is null.
   */
  public static void checkNotNull(Object obj) {
    checkArgument(obj != null);
  }

  /**
   * Throws an {@link NullPointerException} with the error message when the object is null.
   */
  public static void checkNotNull(Object obj, String errorMessage) {
    checkArgument(obj != null, errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the string is blank.
   */
  public static void checkNotBlank(Object str) {
    checkArgument(String.isNotBlank(ObjectUtil.safeValueOfString(str)));
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the string is blank.
   */
  public static void checkNotBlank(Object str, String errorMessage) {
    checkArgument(String.isNotBlank(ObjectUtil.safeValueOfString(str)), errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the list is null or empty.
   */
  public static void checkNotEmpty(List<Object> collection) {
    checkArgument(collection != null && !collection.isEmpty());
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the list is null or empty.
   */
  public static void checkNotEmpty(List<Object> collection, String errorMessage) {
    checkArgument(collection != null && !collection.isEmpty(), errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the set is null or empty.
   */
  public static void checkNotEmpty(Set<Object> collection) {
    checkArgument(collection != null && !collection.isEmpty());
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the set is null or empty.
   */
  public static void checkNotEmpty(Set<Object> collection, String errorMessage) {
    checkArgument(collection != null && !collection.isEmpty(), errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the map is null or empty.
   */
  public static void checkNotEmpty(Map<String, Object> collection) {
    checkArgument(collection != null && !collection.isEmpty());
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the map is null or empty.
   */
  public static void checkNotEmpty(Map<String, Object> collection, String errorMessage) {
    checkArgument(collection != null && !collection.isEmpty(), errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the collection size does not match the expected size.
   */
  public static void checkCollectionSize(List<Object> collection, Integer expectedSize) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(
      collection.size() == expectedSize,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the collection size does not match the expected size.
   */
  public static void checkCollectionSize(
    List<Object> collection,
    Integer expectedSize,
    String errorMessage
  ) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(collection.size() == expectedSize, errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the set size does not match the expected size.
   */
  public static void checkCollectionSize(Set<Object> collection, Integer expectedSize) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(
      collection.size() == expectedSize,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the set size does not match the expected size.
   */
  public static void checkCollectionSize(
    Set<Object> collection,
    Integer expectedSize,
    String errorMessage
  ) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(collection.size() == expectedSize, errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the map size does not match the expected size.
   */
  public static void checkCollectionSize(Map<Object, Object> collection, Integer expectedSize) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(
      collection.size() == expectedSize,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );
  }

  /**
   * Throws an {@link IllegalArgumentException} with the error message when the map size does not match the expected size.
   */
  public static void checkCollectionSize(
    Map<Object, Object> collection,
    Integer expectedSize,
    String errorMessage
  ) {
    checkCollectionNotNullBeforeCheckingSize(collection, expectedSize);
    checkArgument(collection.size() == expectedSize, errorMessage);
  }

  /**
   * Throws an {@link IllegalArgumentException} when the sobject is null.
   *
   * This is intended to be used after querying for a specific record by Id.
   */
  public static void checkSObjectFoundById(SObject sobj, Id id) {
    Preconditions.checkArgument(
      String.isNotBlank(id),
      String.format('Expected an Id to be provided. Found {0}.', new List<Object>{ id })
    );

    checkSObjectFoundByField(sobj, id, id.getSobjectType(), SObjectFieldReference.create('Id'));
  }

  /**
   * Throws an {@link IllegalArgumentException} when the sobject is null.
   *
   * This is intended to be used after querying for a specific record by the given field.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void checkSObjectFoundByField(
    SObject sobj,
    Object value,
    SObjectType expectedSObjectType,
    SObjectField field
  ) {
    checkSObjectFoundByField(sobj, value, expectedSObjectType, SObjectFieldReference.create(field));
  }

  /**
   * Throws an {@link IllegalArgumentException} when the sobject is null.
   *
   * This is intended to be used after querying for a specific record by the given field.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void checkSObjectFoundByField(
    SObject sobj,
    Object value,
    SObjectType expectedSObjectType,
    SObjectFieldReference field
  ) {
    Preconditions.checkArgument(
      sobj != null,
      String.format(
        'Expected to find {0} with {1} "{2}". Found {3}.',
        new List<Object>{ expectedSObjectType, field.getFieldName(), value, sobj }
      )
    );
  }

  /**
   * Throws an {@link IllegalArgumentException} when the sobject is null.
   *
   * This is intended to be used after querying for a specific record by the given field.
   */
  public static void checkSObjectFoundByName(
    SObject sobj,
    SObjectType expectedSObjectType,
    String name
  ) {
    Preconditions.checkArgument(
      sobj != null,
      String.format(
        'Expected to find {0} with name "{1}". Found {2}.',
        new List<Object>{ expectedSObjectType, name, sobj }
      )
    );
  }

  /**
   * Throws an {@link IllegalArgumentException} when the Id does not have the correct SObjectType.
   */
  public static void checkIdIsSObjectType(Id id, SObjectType expectedSObjectType) {
    Preconditions.checkArgument(
      id?.getSobjectType() == expectedSObjectType,
      String.format(
        'Expected the Id to have an SObjectType of {0}. Received {1}, which has an SObjectType of {2}.',
        new List<Object>{ expectedSObjectType, id, id?.getSobjectType() }
      )
    );
  }

  private static void checkCollectionNotNullBeforeCheckingSize(
    Object collection,
    Integer expectedSize
  ) {
    checkNotNull(
      collection,
      String.format(
        'Expected collection size to be {0}, but the collection was null.',
        new List<Object>{ expectedSize }
      )
    );
  }
}