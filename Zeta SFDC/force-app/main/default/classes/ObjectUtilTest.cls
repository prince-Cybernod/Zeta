/**
 * Tests for {@link ObjectUtil}.
 */
@IsTest(IsParallel=true)
private class ObjectUtilTest {
  @IsTest
  private static void buildReadOnlyObject() {
    Type clazz = Database.DeleteResult.class;
    Map<String, Object> fieldValues = new Map<String, Object>{
      'id' => UserInfo.getUserId(),
      'success' => true
    };

    Database.DeleteResult deleteResult = (Database.DeleteResult) ObjectUtil.buildReadOnlyObject(
      clazz,
      fieldValues
    );

    System.assertEquals(true, deleteResult.isSuccess());
    System.assertEquals(UserInfo.getUserId(), deleteResult.getId());
  }

  @IsTest
  private static void safeValueOfBoolean_hasValue_returnsValue() {
    Object value = true;

    Boolean result = ObjectUtil.safeValueOfBoolean(value);

    System.assertEquals(true, result);
  }

  @IsTest
  private static void safeValueOfBoolean_valueIsNull_returnsNull() {
    Object value = null;

    Boolean result = ObjectUtil.safeValueOfBoolean(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfDate_hasValue_returnsValue() {
    Object value = Date.today();

    Date result = ObjectUtil.safeValueOfDate(value);

    // Asserting with value instead of Date.today() is prevent test flakiness
    System.assertEquals(value, result);
  }

  @IsTest
  private static void safeValueOfDate_valueIsNull_returnsNull() {
    Object value = null;

    Date result = ObjectUtil.safeValueOfDate(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfDatetime_hasValue_returnsValue() {
    Object value = Datetime.now();

    Datetime result = ObjectUtil.safeValueOfDatetime(value);

    // Asserting with value instead of Datetime.now() is prevent test flakiness
    System.assertEquals(value, result);
  }

  @IsTest
  private static void safeValueOfDatetime_valueIsNull_returnsNull() {
    Object value = null;

    Datetime result = ObjectUtil.safeValueOfDatetime(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfId_hasValue_returnsValue() {
    Object value = UserInfo.getUserId();

    Id result = ObjectUtil.safeValueOfId(value);

    System.assertEquals(UserInfo.getUserId(), result);
  }

  @IsTest
  private static void safeValueOfId_valueIsNull_returnsNull() {
    Object value = null;

    Id result = ObjectUtil.safeValueOfId(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfInteger_hasValue_returnsValue() {
    Object value = 10;

    Integer result = ObjectUtil.safeValueOfInteger(value);

    System.assertEquals(10, result);
  }

  @IsTest
  private static void safeValueOfInteger_valueIsNull_returnsNull() {
    Object value = null;

    Integer result = ObjectUtil.safeValueOfInteger(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfDecimal_hasValue_returnsValue() {
    Object value = 10.0;

    Decimal result = ObjectUtil.safeValueOfDecimal(value);

    System.assertEquals(10.0, result);
  }

  @IsTest
  private static void safeValueOfDecimal_valueIsNull_returnsNull() {
    Object value = null;

    Decimal result = ObjectUtil.safeValueOfDecimal(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfDouble_hasValue_returnsValue() {
    Object value = 10.0;

    Double result = ObjectUtil.safeValueOfDouble(value);

    System.assertEquals(10.0, result, 0.0);
  }

  @IsTest
  private static void safeValueOfDouble_valueIsNull_returnsNull() {
    Object value = null;

    Double result = ObjectUtil.safeValueOfDouble(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfLong_hasValue_returnsValue() {
    Object value = 10L;

    Long result = ObjectUtil.safeValueOfLong(value);

    System.assertEquals(10L, result);
  }

  @IsTest
  private static void safeValueOfLong_valueIsNull_returnsNull() {
    Object value = null;

    Long result = ObjectUtil.safeValueOfLong(value);

    System.assertEquals(null, result);
  }

  @IsTest
  private static void safeValueOfString_hasValue_returnsValue() {
    Object value = 'test';

    String result = ObjectUtil.safeValueOfString(value);

    System.assertEquals('test', result);
  }

  @IsTest
  private static void safeValueOfString_valueIsNull_returnsNull() {
    Object value = null;

    String result = ObjectUtil.safeValueOfString(value);

    System.assertEquals(null, result);
  }
}