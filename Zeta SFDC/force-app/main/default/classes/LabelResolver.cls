/**
 * Resolves Custom Label API names to their translated display values.
 * CMDT records store Custom Label API names (e.g., 'AppUI_FieldName') in text fields
 * so they can be resolved at runtime via System.Label.get() for i18n support.
 */
public class LabelResolver {
  /**
   * Resolves a Custom Label API name to its display value for the running user's language.
   * Returns the input unchanged if blank or if the label does not exist.
   *
   * @param value The Custom Label API name to resolve (e.g., 'AppUI_FieldName')
   * @return The resolved label value (e.g., 'Name'), or the original input if unresolvable
   */
  public static String resolve(String value) {
    if (String.isBlank(value)) {
      return value;
    }
    try {
      return System.Label.get('', value, '');
    } catch (Exception e) {
      return value;
    }
  }
}