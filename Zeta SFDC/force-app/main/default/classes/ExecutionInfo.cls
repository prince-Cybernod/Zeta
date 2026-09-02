/**
 * Contains information about the current execution context.
 */
public with sharing class ExecutionInfo {
  private final String className;
  private final String methodName;

  public ExecutionInfo() {
    // https://salesforce.stackexchange.com/a/180376/54914
    String stackTrace = new DmlException()
      .getStackTraceString()
      .substringAfter('\n')
      .substringBefore('\n');

    Matcher matcher = Pattern.compile(
        '(?i)^(?:class\\.)?([^.]+)\\.?([^\\.\\:]+)?[\\.\\:]?([^\\.\\:]*): line (\\d+), column (\\d+)$'
      )
      .matcher(stackTrace);
    Integer line;
    Integer column;

    if (matcher.find()) {
      if (String.isBlank(matcher.group(3))) {
        className = matcher.group(1);
        methodName = prettifyMethodName(matcher.group(2));
      } else {
        className = matcher.group(1) + '.' + matcher.group(2);
        methodName = prettifyMethodName(matcher.group(3));
      }
      line = Integer.valueOf(matcher.group(4));
      column = Integer.valueOf(matcher.group(5));
    }
  }

  /**
   * Returns the full name of the current method.
   */
  public String getFullName() {
    return className + '.' + methodName;
  }

  /**
   * Returns the name of the current class.
   */
  public String getClassName() {
    return className;
  }

  /**
   * Returns the name of the current method.
   */
  public String getMethodName() {
    return methodName;
  }

  private static String prettifyMethodName(String name) {
    return (name == null)
      ? null
      : name.replace('<init>', '(constructor) ').replace('__sfdc_', '(getter/setter) ');
  }
}