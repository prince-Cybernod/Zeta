/**
 * Utilities for working with {@link Object} in Apex.
 */
public with sharing class ObjectUtil {
  /**
   * Builds and returns an object that cannot be constructed.
   */
  public static Object buildReadOnlyObject(Type clazz, Map<String, Object> fieldValues) {
    return JSON.deserialize(JSON.serialize(fieldValues), clazz);
  }

  /**
   * Returns the value as a {@link Boolean} if it is not null. Otherwise, returns null.
   */
  public static Boolean safeValueOfBoolean(Object value) {
    return value != null ? Boolean.valueOf(value) : null;
  }

  /**
   * Returns the value as a {@link Date} if it is not null. Otherwise, returns null.
   */
  public static Date safeValueOfDate(Object value) {
    return value != null ? Date.valueOf(String.valueOf(value)) : null;
  }

  /**
   * Returns the value as a {@link Datetime} if it is not null. Otherwise, returns null.
   */
  public static Datetime safeValueOfDatetime(Object value) {
    return value != null ? Datetime.valueOf(value) : null;
  }

  /**
   * Returns the value as an {@link Id} if it is not null. Otherwise, returns null.
   */
  public static Id safeValueOfId(Object value) {
    return value != null ? Id.valueOf(safeValueOfString(value)) : null;
  }

  /**
   * Returns the value as an {@link Integer} if it is not null. Otherwise, returns null.
   */
  public static Integer safeValueOfInteger(Object value) {
    return value != null ? Integer.valueOf(value) : null;
  }

  /**
   * Returns the value as an {@link Decimal} if it is not null. Otherwise, returns null.
   */
  public static Decimal safeValueOfDecimal(Object value) {
    return value != null ? Decimal.valueOf(String.valueOf(value)) : null;
  }

  /**
   * Returns the value as a {@link Double} if it is not null. Otherwise, returns null.
   */
  public static Double safeValueOfDouble(Object value) {
    return value != null ? Double.valueOf(String.valueOf(value)) : null;
  }

  /**
   * Returns the value as an {@link Long} if it is not null. Otherwise, returns null.
   */
  public static Long safeValueOfLong(Object value) {
    return value != null ? Long.valueOf(String.valueOf(value)) : null;
  }

  /**
   * Returns the value as a {@link String} if it is not null. Otherwise, returns null.
   */
  public static String safeValueOfString(Object value) {
    return value != null ? String.valueOf(value) : null;
  }
}