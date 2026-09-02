/**
 * Tests for {@link AssertUtil}.
 */
@IsTest
private class AssertUtilTest {
  @IsTest
  private static void areApproximatelyEqual_decimal_passes() {
    Decimal expected = 1;
    Decimal actual = 1;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_decimalWithDelta_passes() {
    Decimal expected = 1;
    Decimal actual = 1;
    Decimal delta = 0.001;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, delta);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_decimalWithMessage_passes() {
    Decimal expected = 1;
    Decimal actual = 1;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_decimalWithDeltaAndMessage_passes() {
    Decimal expected = 1;
    Decimal actual = 1;
    Decimal delta = 0.001;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, delta, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_double_passes() {
    Double expected = 1;
    Double actual = 1;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_doubleWithDelta_passes() {
    Double expected = 1;
    Double actual = 1;
    Double delta = 0.001;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, delta);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_doubleWithMessage_passes() {
    Double expected = 1;
    Double actual = 1;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void areApproximatelyEqual_doubleWithDeltaAndMessage_passes() {
    Double expected = 1;
    Double actual = 1;
    Double delta = 0.001;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.areApproximatelyEqual(expected, actual, delta, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyList_sameLists_passes() {
    List<String> expected = new List<String>{ 'foo', 'bar', 'baz' };
    List<String> actual = new List<String>{ 'foo', 'bar', 'baz' };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyList_expectedIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected list must be defined. Found: null'
    );
    List<Object> expected = null;
    List<Object> actual = new List<Object>();

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void containsExactlyList_actualIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Actual list must be defined. Found: null'
    );
    List<Object> expected = new List<Object>();
    List<Object> actual = null;

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void containsExactlyStringSet_sameSets_passes() {
    Set<String> expected = new Set<String>{ 'foo', 'bar', 'baz' };
    Set<String> actual = new Set<String>{ 'foo', 'bar', 'baz' };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyIdSet_sameSets_passes() {
    // This is inlined to remove the dependency on SObjectIds class.
    // Otherwise we would have a circular dependency. We should fix this better.
    Id accountId1 = '001' + '00000000000' + '1';
    Id accountId2 = '001' + '00000000000' + '2';
    Id accountId3 = '001' + '00000000000' + '3';
    Set<Id> expected = new Set<Id>{ accountId1, accountId2, accountId3 };
    Set<Id> actual = new Set<Id>{ accountId1, accountId2, accountId3 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyIntegerSet_sameSets_passes() {
    Set<Integer> expected = new Set<Integer>{ 1, 2, 3 };
    Set<Integer> actual = new Set<Integer>{ 1, 2, 3 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyDecimalSet_sameSets_passes() {
    Set<Decimal> expected = new Set<Decimal>{ 1.0, 2.0, 3.0 };
    Set<Decimal> actual = new Set<Decimal>{ 1.0, 2.0, 3.0 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyBooleanSet_sameSets_passes() {
    Set<Boolean> expected = new Set<Boolean>{ true, false };
    Set<Boolean> actual = new Set<Boolean>{ true, false };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyDateSet_sameSets_passes() {
    Set<Date> expected = new Set<Date>{
      Date.newInstance(2025, 1, 1),
      Date.newInstance(2025, 1, 2),
      Date.newInstance(2025, 1, 3)
    };
    Set<Date> actual = new Set<Date>{
      Date.newInstance(2025, 1, 1),
      Date.newInstance(2025, 1, 2),
      Date.newInstance(2025, 1, 3)
    };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyDatetimeSet_sameSets_passes() {
    Set<Datetime> expected = new Set<Datetime>{
      Datetime.newInstance(2025, 1, 1, 0, 0, 0),
      Datetime.newInstance(2025, 1, 2, 0, 0, 0),
      Datetime.newInstance(2025, 1, 3, 0, 0, 0)
    };
    Set<Datetime> actual = new Set<Datetime>{
      Datetime.newInstance(2025, 1, 1, 0, 0, 0),
      Datetime.newInstance(2025, 1, 2, 0, 0, 0),
      Datetime.newInstance(2025, 1, 3, 0, 0, 0)
    };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyTimeSet_sameSets_passes() {
    Set<Time> expected = new Set<Time>{
      Time.newInstance(0, 0, 0, 0),
      Time.newInstance(1, 0, 0, 0),
      Time.newInstance(2, 0, 0, 0)
    };
    Set<Time> actual = new Set<Time>{
      Time.newInstance(0, 0, 0, 0),
      Time.newInstance(1, 0, 0, 0),
      Time.newInstance(2, 0, 0, 0)
    };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlySet_expectedIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected set must be defined. Found: null'
    );
    Set<Object> expected = null;
    Set<Object> actual = new Set<Object>();

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void containsExactlySet_actualIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Actual set must be defined. Found: null'
    );
    Set<Object> expected = new Set<Object>();
    Set<Object> actual = null;

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void containsExactlyMap_sameMaps_passes() {
    Map<String, Integer> expected = new Map<String, Integer>{ 'foo' => 1, 'bar' => 2, 'baz' => 3 };
    Map<String, Integer> actual = new Map<String, Integer>{ 'foo' => 1, 'bar' => 2, 'baz' => 3 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.containsExactly(expected, actual);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void containsExactlyMap_expectedIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected map must be defined. Found: null'
    );
    Map<String, Object> expected = null;
    Map<String, Object> actual = new Map<String, Object>();

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void containsExactlyMap_actualIsNull_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Actual map must be defined. Found: null'
    );
    Map<String, Object> expected = new Map<String, Object>();
    Map<String, Object> actual = null;

    try {
      AssertUtil.containsExactly(expected, actual);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void isInRange_decimal_passes() {
    Decimal value = 1;
    Decimal min = 0;
    Decimal max = 2;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.isInRange(value, min, max, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void isInRange_double_passes() {
    Double value = 1.0;
    Double min = 0.0;
    Double max = 2.0;
    String message = 'This is a test';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.isInRange(value, min, max, message);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void isGreaterThan_decimal_passes() {
    Decimal value1 = 1;
    Decimal value2 = 0;
    Decimal tolerance = 0.001;

    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.isGreaterThan(value1, value2, tolerance);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void isGreaterThan_double_passes() {
    Double value1 = 1.0;
    Double value2 = 0.0;
    Double tolerance = 0.001;

    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    AssertUtil.isGreaterThan(value1, value2, tolerance);

    throwing.assertHasNotThrown();
  }
}