/**
 * Tests for {@link Mock}.
 */
@IsTest(IsParallel=true)
private class MockTest {
  @IsTest
  private static void when_mockedToReturnTrue_returnsTrue() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.isDone()).thenReturn(true);

    Boolean result = exampleMock.isDone();

    Assert.isTrue(result);
  }

  @IsTest
  private static void when_mockedToReturnVoid_returnsNull() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.run()).thenReturnVoid();
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    exampleMock.run(null, null);

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void when_mockedToThrow_throws() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.run()).thenThrow(new DmlException('it failed'));
    AssertThrows.Throwing throwing = AssertThrows.with(DmlException.class, 'it failed');

    try {
      exampleMock.run(null, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  // The verify() and never() methods only test the positive cases because the Assert methods throw
  // un-catchable errors
  @IsTest
  private static void verify_calledOnce_succeeds() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.run()).thenReturnVoid();

    exampleMock.run(null, null);

    exampleMock.verify(exampleMock.method.run());
  }

  @IsTest
  private static void verify_calledTwice_succeeds() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.isDone()).thenReturn(false).thenReturn(true);

    Boolean firstResult = exampleMock.isDone();
    Boolean secondResult = exampleMock.isDone();

    exampleMock.verify(exampleMock.method.isDone(), 2);
    Assert.isFalse(firstResult);
    Assert.isTrue(secondResult);
  }

  @IsTest
  private static void never_calledZeroTimes_succeeds() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.isDone()).thenReturn(false);

    exampleMock.isDone();

    exampleMock.never(exampleMock.method.run());
  }

  @IsTest
  private static void getCallCount_calledThreeTimes_returns3() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.run()).thenReturnVoid().thenReturnVoid().thenReturnVoid();

    exampleMock.run(null, null);
    exampleMock.run(null, null);
    exampleMock.run(null, null);

    Assert.areEqual(3, exampleMock.getCallCount(exampleMock.method.run()));
  }

  @IsTest
  private static void getCalls_calledWithParameters_returnsParameters() {
    ExampleMock exampleMock = new ExampleMock();
    exampleMock.when(exampleMock.method.run()).thenReturnVoid();
    String param1 = 'foo';
    Integer param2 = 10;

    exampleMock.run(param1, param2);

    List<Map<String, Object>> calls = exampleMock.getCalls(exampleMock.method.run());
    Assert.areEqual(1, calls.size());
    Assert.areEqual('foo', calls[0].get('param1'));
    Assert.areEqual(10, calls[0].get('param2'));
  }

  /**
   * Example interface that will be mocked.
   */
  private interface Example {
    /**
     * Returns {@code true} when the example is done.
     */
    Boolean isDone();

    /**
     * Executes the process.
     */
    void run(String param1, Integer param2);
  }

  /**
   * {@link Mock} implementation of {@link Example}.
   */
  private class ExampleMock extends Mock implements Example {
    private final Method method = new Method();

    public Boolean isDone() {
      return (Boolean) mockedCall(method.isDone(), new Map<String, Object>());
    }

    public void run(String param1, Integer param2) {
      mockedCall(method.run(), new Map<String, Object>{ 'param1' => param1, 'param2' => param2 });
    }
  }

  // This would normally be an inner class inside ExampleMock, but we can't nest a 2nd time here
  private class Method {
    private String isDone() {
      return new ExecutionInfo().getFullName();
    }

    private String run() {
      return new ExecutionInfo().getFullName();
    }
  }
}