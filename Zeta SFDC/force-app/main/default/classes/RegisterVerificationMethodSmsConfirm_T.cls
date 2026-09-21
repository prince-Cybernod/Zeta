@IsTest(IsParallel=false)
private class RegisterVerificationMethodSmsConfirm_T {
  @IsTest
  static void testVerifyRegisterVerificationMethodSMS_Success() {
    RegisterVerificationMethodSmsConfirm.Request req =
      new RegisterVerificationMethodSmsConfirm.Request();
    req.code = '123456';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.SUCCESS;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodSmsConfirm.verifyRegisterVerificationMethodSMS(
        new List<RegisterVerificationMethodSmsConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(true, responses[0].success, 'Should be successful');
  }

  @IsTest
  static void testVerifyRegisterVerificationMethodSMS_InvalidToken() {
    RegisterVerificationMethodSmsConfirm.Request req =
      new RegisterVerificationMethodSmsConfirm.Request();
    req.code = '000000';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.INVALID_TOKEN;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodSmsConfirm.verifyRegisterVerificationMethodSMS(
        new List<RegisterVerificationMethodSmsConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
  }
}