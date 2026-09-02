/**
 * Tests for {@link InitializeLotteryResult}.
 */
@IsTest(IsParallel=true)
private class InitializeLotteryResultTest {
  @IsTest
  private static void constructor_initializesDefaults() {
    InitializeLotteryResult result = new InitializeLotteryResult();

    Assert.isNull(result.jobId, 'jobId should default to null');
    Assert.isNull(result.runLogId, 'runLogId should default to null');
    Assert.isNull(result.runLogName, 'runLogName should default to null');
    Assert.isTrue(result.isSuccess, 'isSuccess should default to true');
    Assert.isNull(result.errorMessage, 'errorMessage should default to null');
  }

  @IsTest
  private static void properties_canBeSetAndRead() {
    InitializeLotteryResult result = new InitializeLotteryResult();

    result.jobId = 'test-job-123';
    result.runLogId = '001000000000001AAA';
    result.runLogName = 'LRL-001';
    result.isSuccess = false;
    result.errorMessage = 'Test error';

    Assert.areEqual('test-job-123', result.jobId, 'jobId should be settable');
    Assert.areEqual('001000000000001AAA', result.runLogId, 'runLogId should be settable');
    Assert.areEqual('LRL-001', result.runLogName, 'runLogName should be settable');
    Assert.isFalse(result.isSuccess, 'isSuccess should be settable');
    Assert.areEqual('Test error', result.errorMessage, 'errorMessage should be settable');
  }
}