/**
 * Tests for {@link ExecutionInfo}.
 */
@IsTest(IsParallel=true)
private class ExecutionInfoTest {
  @IsTest
  private static void getFullName_returnsClassNameAndMethodName() {
    ExecutionInfo executionInfo = new ExecutionInfo();

    String fullName = executionInfo.getFullName();

    Assert.areEqual(fullName, 'ExecutionInfoTest.getFullName_returnsClassNameAndMethodName');
  }

  @IsTest
  private static void getClassName_returnsClassName() {
    ExecutionInfo executionInfo = new ExecutionInfo();

    String className = executionInfo.getClassName();

    Assert.areEqual(className, 'ExecutionInfoTest');
  }

  @IsTest
  private static void getMethodName_returnsMethodName() {
    ExecutionInfo executionInfo = new ExecutionInfo();

    String methodName = executionInfo.getMethodName();

    Assert.areEqual(methodName, 'getMethodName_returnsMethodName');
  }
}