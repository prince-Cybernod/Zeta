/**
 * Utilities for working with {@link Assert} methods.
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount')
public with sharing class AssertUtil {
  private static final Double DEFAULT_DELTA = 0.0001.doubleValue();

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Decimal expected, Decimal actual) {
    areApproximatelyEqual(
      ObjectUtil.safeValueOfDouble(expected),
      ObjectUtil.safeValueOfDouble(actual)
    );
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Decimal expected, Decimal actual, Decimal delta) {
    areApproximatelyEqual(
      ObjectUtil.safeValueOfDouble(expected),
      ObjectUtil.safeValueOfDouble(actual),
      ObjectUtil.safeValueOfDouble(delta)
    );
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Decimal expected, Decimal actual, String message) {
    areApproximatelyEqual(
      ObjectUtil.safeValueOfDouble(expected),
      ObjectUtil.safeValueOfDouble(actual),
      DEFAULT_DELTA,
      message
    );
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void areApproximatelyEqual(
    Decimal expected,
    Decimal actual,
    Decimal delta,
    String message
  ) {
    areApproximatelyEqual(
      ObjectUtil.safeValueOfDouble(expected),
      ObjectUtil.safeValueOfDouble(actual),
      ObjectUtil.safeValueOfDouble(delta),
      message
    );
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Double expected, Double actual) {
    areApproximatelyEqual(expected, actual, DEFAULT_DELTA);
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Double expected, Double actual, String message) {
    areApproximatelyEqual(expected, actual, DEFAULT_DELTA, message);
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  public static void areApproximatelyEqual(Double expected, Double actual, Double delta) {
    areApproximatelyEqual(
      expected,
      actual,
      delta,
      String.format(
        'Expected: {0}, Actual: {1}, Delta: {2}',
        new List<Object>{ expected, actual, delta }
      )
    );
  }

  /**
   * Asserts that the two values are within the specified delta.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void areApproximatelyEqual(
    Double expected,
    Double actual,
    Double delta,
    String message
  ) {
    Assert.isTrue(Math.abs(expected - actual) <= delta, message);
  }

  /**
   * Asserts that both lists contain the same elements in order.
   */
  public static void containsExactly(List<Object> expected, List<Object> actual) {
    Preconditions.checkArgument(
      expected != null,
      String.format('Expected list must be defined. Found: {0}', new List<Object>{ expected })
    );
    Preconditions.checkArgument(
      actual != null,
      String.format('Actual list must be defined. Found: {0}', new List<Object>{ actual })
    );

    Assert.areEqual(expected.size(), actual.size(), 'Lists are different lengths');
    for (Integer i = 0; i < expected.size(); i++) {
      Assert.areEqual(
        expected[i],
        actual[i],
        String.format('Element {0} has an unexpected value', new List<Object>{ i })
      );
    }
  }

  /**
   * Asserts that both sets contain the same {@link String} elements.
   */
  public static void containsExactly(Set<String> expected, Set<String> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (String value : expected) {
      expectedSet.add(value);
    }
    for (String value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Id} elements.
   */
  public static void containsExactly(Set<Id> expected, Set<Id> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Id value : expected) {
      expectedSet.add(value);
    }
    for (Id value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Integer} elements.
   */
  public static void containsExactly(Set<Integer> expected, Set<Integer> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Integer value : expected) {
      expectedSet.add(value);
    }
    for (Integer value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Decimal} elements.
   */
  public static void containsExactly(Set<Decimal> expected, Set<Decimal> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Decimal value : expected) {
      expectedSet.add(value);
    }
    for (Decimal value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Boolean} elements.
   */
  public static void containsExactly(Set<Boolean> expected, Set<Boolean> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Boolean value : expected) {
      expectedSet.add(value);
    }
    for (Boolean value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Date} elements.
   */
  public static void containsExactly(Set<Date> expected, Set<Date> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Date value : expected) {
      expectedSet.add(value);
    }
    for (Date value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Datetime} elements.
   */
  public static void containsExactly(Set<Datetime> expected, Set<Datetime> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Datetime value : expected) {
      expectedSet.add(value);
    }
    for (Datetime value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same {@link Time} elements.
   */
  public static void containsExactly(Set<Time> expected, Set<Time> actual) {
    Set<Object> expectedSet = new Set<Object>();
    Set<Object> actualSet = new Set<Object>();

    for (Time value : expected) {
      expectedSet.add(value);
    }
    for (Time value : actual) {
      actualSet.add(value);
    }

    containsExactly(expectedSet, actualSet);
  }

  /**
   * Asserts that both sets contain the same elements.
   */
  public static void containsExactly(Set<Object> expected, Set<Object> actual) {
    Preconditions.checkArgument(
      expected != null,
      String.format('Expected set must be defined. Found: {0}', new List<Object>{ expected })
    );
    Preconditions.checkArgument(
      actual != null,
      String.format('Actual set must be defined. Found: {0}', new List<Object>{ actual })
    );

    Assert.areEqual(expected.size(), actual.size(), 'Sets are different lengths');
    for (Object value : expected) {
      Assert.isTrue(
        actual.contains(value),
        String.format('Actual set does not contain {0}', new List<Object>{ value })
      );
    }
  }

  /**
   * Asserts that both maps contain the same keys and values.
   */
  public static void containsExactly(Map<String, Object> expected, Map<String, Object> actual) {
    Preconditions.checkArgument(
      expected != null,
      String.format('Expected map must be defined. Found: {0}', new List<Object>{ expected })
    );
    Preconditions.checkArgument(
      actual != null,
      String.format('Actual map must be defined. Found: {0}', new List<Object>{ actual })
    );

    Assert.areEqual(expected.size(), actual.size(), 'Maps are different lengths');

    Map<String, Object> expectedCopy = new Map<String, Object>(expected);
    Map<String, Object> actualCopy = new Map<String, Object>(actual);
    for (String key : expected.keySet()) {
      Assert.areEqual(
        expectedCopy.remove(key),
        actualCopy.remove(key),
        String.format('Key {0} has an unexpected value', new List<Object>{ key })
      );
    }

    Assert.isTrue(expectedCopy.isEmpty(), 'Expected map has extra keys: ' + expectedCopy.keySet());
    Assert.isTrue(actualCopy.isEmpty(), 'Actual map has extra keys: ' + actualCopy.keySet());
  }

  /**
   * Asserts that the value is within the expected range.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void isInRange(Decimal value, Decimal min, Decimal max, String message) {
    isInRange(
      ObjectUtil.safeValueOfDouble(value),
      ObjectUtil.safeValueOfDouble(min),
      ObjectUtil.safeValueOfDouble(max),
      message
    );
  }

  /**
   * Asserts that the value is within the expected range.
   */
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void isInRange(Double value, Double min, Double max, String message) {
    Assert.isTrue(
      value >= min && value <= max,
      String.format(
        '{0}. Value: {1}, Expected range: [{2}, {3}]',
        new List<Object>{ message, value, min, max }
      )
    );
  }

  /**
   * Asserts that the first value is greater than the second within a tolerance.
   */
  public static void isGreaterThan(Decimal value1, Decimal value2, Decimal tolerance) {
    isGreaterThan(
      ObjectUtil.safeValueOfDouble(value1),
      ObjectUtil.safeValueOfDouble(value2),
      ObjectUtil.safeValueOfDouble(tolerance)
    );
  }

  /**
   * Asserts that the first value is greater than the second within a tolerance.
   */
  public static void isGreaterThan(Double value1, Double value2, Double tolerance) {
    Assert.isTrue(
      value1 > (value2 + tolerance),
      String.format(
        'Expected {0} to be greater than {1} by at least {2}',
        new List<Object>{ value1, value2, tolerance }
      )
    );
  }
}