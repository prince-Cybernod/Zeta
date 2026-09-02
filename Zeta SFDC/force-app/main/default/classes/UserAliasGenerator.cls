public inherited sharing class UserAliasGenerator {

  /**
   * Generates a user alias from first name and last name using smart character selection.
   * - Uses available name if one is blank
   * - Removes special characters and spaces
   * - For long last names (5+ chars): uses first initial + up to 7 chars of last name
   * - For short last names: uses more chars from first name
   * - Ensures alias length is between 3-8 characters
   * - Returns 'na' only if both inputs are invalid
   *
   * @param firstName The user's first name
   * @param lastName The user's last name
   * @return The generated alias or 'na' if both inputs are invalid
   */
  public static String getAlias(String firstName, String lastName) {
    // Clean inputs
    String cleanFirst = String.isBlank(firstName) ? '' : firstName.replaceAll('[^a-zA-Z]', '').toLowerCase();
    String cleanLast = String.isBlank(lastName) ? '' : lastName.replaceAll('[^a-zA-Z]', '').toLowerCase();

    // If both names are empty after cleaning, return default
    if (String.isBlank(cleanFirst) && String.isBlank(cleanLast)) {
      return 'na';
    }

    // If one name is empty, use the other
    if (String.isBlank(cleanFirst)) {
      return cleanLast.substring(0, Math.min(8, cleanLast.length()));
    }

    if (String.isBlank(cleanLast)) {
      return cleanFirst.substring(0, Math.min(8, cleanFirst.length()));
    }

    String alias;

    // If last name is long enough (5+ chars), use first initial + 7 chars of last name
    if (cleanLast.length() >= 5) {
      alias = cleanFirst.substring(0, 1) + cleanLast.substring(0, Math.min(7, cleanLast.length()));
    } else {
      // If last name is shorter, use more chars from first name
      Integer firstNameChars = Math.min(8 - cleanLast.length(), cleanFirst.length());
      alias = cleanFirst.substring(0, firstNameChars) + cleanLast;
    }

    // Ensure alias is between 3-8 characters
    if (alias.length() < 3) {
      // Pad with first name chars if too short
      alias = cleanFirst.substring(0, Math.min(8 - alias.length(), cleanFirst.length())) + alias;
    }

    return alias.substring(0, Math.min(8, alias.length()));
  }

}