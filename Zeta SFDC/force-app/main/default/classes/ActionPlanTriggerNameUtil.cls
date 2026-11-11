/**
 * Utility for generating safe, deterministic trigger and test class names
 * that comply with Salesforce name length limits.
 */
public with sharing class ActionPlanTriggerNameUtil {

  // Static fields
  private static final Integer MAX_TRIGGER_NAME_LEN = 80;
  private static final Integer MAX_CLASS_NAME_LEN = 40;

  // Instance fields

  // Constructors

  // Instance methods

  // Static methods
  /**
   * Produce a safe trigger name for a given SObject API name.
   */
  public static String makeSafeTriggerName(String sObjectName) {
    return makeDeterministicName(sObjectName, '', MAX_TRIGGER_NAME_LEN);
  }

  /**
   * Produce a safe test class name for a given SObject API name.
   */
  public static String makeSafeTestClassName(String sObjectName) {
    return makeDeterministicName(sObjectName, 'T', MAX_CLASS_NAME_LEN);
  }

  /**
   * Core naming function that truncates and appends a short hash when necessary.
   */
  private static String makeDeterministicName(String base, String suffix, Integer maxLen) {
    if (String.isBlank(base)) {
      return ('AP' + suffix).left(maxLen);
    }

    String cleanBase = sanitize(base);
    String prefixedBase = 'AP' + cleanBase;

    Integer needed = prefixedBase.length() + suffix.length();
    if (needed <= maxLen) {
      return prefixedBase + suffix;
    }

    // Reserve space for 8-char hash when truncation is necessary (no underscore separator)
    String hash = shortHash(prefixedBase);
    Integer reserved = hash.length();
    Integer slice = Math.max(1, maxLen - suffix.length() - reserved);

    String head = prefixedBase.substring(0, slice);
    return head + hash + suffix;
  }

  /**
   * Sanitize the base to permitted characters and ensure starts with a letter.
   */
  private static String sanitize(String name) {
    // Remove all non-alphanumeric characters, including underscores
    String s = name.replaceAll('[^A-Za-z0-9]', '');
    if (String.isBlank(s)) {
      s = 'A';
    }
    if (!Pattern.matches('^[A-Za-z].*', s)) {
      s = 'A' + s;
    }
    return s;
  }

  /**
   * Return an uppercase 8-hex short hash from SHA-1 of the input.
   */
  private static String shortHash(String input) {
    Blob b = Crypto.generateDigest('SHA1', Blob.valueOf(input));
    String hex = EncodingUtil.convertToHex(b);
    return hex.substring(0, 8).toUpperCase();
  }
}