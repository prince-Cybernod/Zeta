/**
 * @description Base class for mocking an interface.
 */
public abstract with sharing class Mock {
  /**
   * Holds what will be returned for mocked calls.
   */
  private final Map<String, ResultContainer> results = new Map<String, ResultContainer>();
  /**
   * Holds the arguments of calls that have been made.
   */
  private final Map<String, List<Map<String, Object>>> calls = new Map<String, List<Map<String, Object>>>();

  /**
   * Resets the mock to its initial state. This clears all mocked return values and recorded calls.
   * Useful when sharing mock instances across multiple test methods to ensure isolation.
   */
  public void reset() {
    results.clear();
    calls.clear();
  }

  /**
   * Contains the values that will be returned for a mocked call.
   */
  public class ResultContainer {
    private final List<Object> values = new List<Object>();
    private final String method;

    public ResultContainer(String method) {
      this.method = method;
    }

    /**
     * Adds the next value that will be returned for a mocked call.
     */
    public ResultContainer thenReturn(Object result) {
      values.add(result);
      return this;
    }

    /**
     * Adds null as the next value that will be returned for a mocked call.
     */
    public ResultContainer thenReturnVoid() {
      values.add(null);
      return this;
    }

    /**
     * Adds an exception that will be thrown for a mocked call.
     */
    public ResultContainer thenThrow(Exception e) {
      values.add(e);
      return this;
    }
  }

  /**
   * Returns the result that will be returned for a mocked call.
   */
  public ResultContainer when(String method) {
    if (!calls.containsKey(method)) {
      calls.put(method, new List<Map<String, Object>>());
    }

    if (!results.containsKey(method)) {
      results.put(method, new ResultContainer(method));
    }

    return results.get(method);
  }

  /**
   * Verifies that a call was made to a mocked method.
   */
  public void verify(String method) {
    verify(method, 1);
  }

  /**
   * Verifies that a call was made to a mocked method a certain number of times.
   */
  public void verify(String method, Integer times) {
    Assert.areEqual(
      times,
      getCallCount(method),
      String.format('{0} was not called {1} times.', new List<Object>{ method, times })
    );
  }

  /**
   * Verifies that a call was never made to a mocked method.
   */
  public void never(String method) {
    // The error message passed in is built before calling the Assert method. This means it will
    // throw when the method is not in the calls Map. This is why we have logic when building it.
    String errorMessage = String.format(
      'Expected {0} to have never been called',
      new List<Object>{ method }
    );
    Integer callCount = 0;
    if (calls.containsKey(method)) {
      callCount = getCallCount(method);
      if (callCount > 0) {
        errorMessage += String.format(', but was called {0} times.', new List<Object>{ callCount });
      }
    } else {
      errorMessage += '.';
    }

    Assert.isTrue(!calls.containsKey(method) || callCount == 0, errorMessage);
  }

  /**
   * Returns the number of times a mocked method was called.
   */
  public Integer getCallCount(String method) {
    return getCalls(method).size();
  }

  /**
   * Returns the arguments used to make calls to a mocked method.
   */
  public List<Map<String, Object>> getCalls(String method) {
    Preconditions.checkArgument(
      calls.containsKey(method),
      String.format(
        '{0} was not called. Make sure you are using Mock.mockedCall(String method, Map<String, Object> args) to add calls in your Mock implementation.',
        new List<Object>{ method }
      )
    );

    return calls.get(method);
  }

  /**
   * Returns the value for a mocked call.
   *
   * There are a few things to keep in mind:
   *
   * - If the method was not mocked, an exception will be thrown.
   * - If the method was mocked to return multiple values, the values will be returned in the order they were mocked.
   * - If the method was mocked to return an exception, the exception will be thrown.
   */
  protected Object mockedCall(String method, Map<String, Object> args) {
    Preconditions.checkArgument(
      calls.containsKey(method) && results.containsKey(method),
      String.format(
        '{0} was not mocked. Make sure you are using Mock.when(String method) to mock calls before using this method in your Mock implementation.',
        new List<Object>{ method }
      )
    );

    calls.get(method).add(args);
    ResultContainer result = results.get(method);

    Preconditions.checkArgument(
      result.values.size() > 0,
      String.format(
        '{0} was mocked but no return value was provided. Make sure you are using Mock.when(String method).thenReturn(Object result) to mock calls before using this method in your Mock implementation.',
        new List<Object>{ method }
      )
    );

    Object value = result.values.remove(0);
    if (value instanceof Exception) {
      throw (Exception) value;
    } else {
      return value;
    }
  }
}