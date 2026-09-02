/**
 * Different types of responses from checking for field differences.
 */
public enum SObjectFieldDiffResponseType {
  FIELDS_ARE_EQUAL,
  FIELDS_ARE_DIFFERENT,
  ONE_SOBJECT_IS_NULL,
  BOTH_SOBJECTS_ARE_NULL
}