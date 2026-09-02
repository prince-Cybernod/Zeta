/**
 * Provides singleton instances of {@link DescribeSObjectResult}s.
 */
public inherited sharing class SObjectDescribes {
  private static final Map<SObjectType, DescribeSObjectResult> RESULT_MAP = new Map<SObjectType, DescribeSObjectResult>();

  /**
   * Returns the describe result for the given sobject type.
   */
  public static DescribeSObjectResult get(SObjectType sobjectType) {
    Preconditions.checkArgument(
      sobjectType != null,
      String.format('SObjectType must have a value. Found {0}', new List<Object>{ sobjectType })
    );

    if (!RESULT_MAP.containsKey(sobjectType)) {
      RESULT_MAP.put(sobjectType, sobjectType.getDescribe(SObjectDescribeOptions.DEFERRED));
    }

    return RESULT_MAP.get(sobjectType);
  }

  /**
   * Returns the describe result for the given sobject name.
   */
  public static DescribeSObjectResult get(String sobjectName) {
    return get(Schema.getGlobalDescribe().get(sobjectName));
  }
}