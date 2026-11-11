@IsTest(IsParallel=false)
private class RegisterVerificationMethodEmailConfirm_T {
  @IsTest
  static void testVerifyRegisterVerificationMethodEmail_Success() {
    RegisterVerificationMethodEmailConfirm.Request req =
      new RegisterVerificationMethodEmailConfirm.Request();
    req.code = '123456';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.SUCCESS;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodEmailConfirm.verifyRegisterVerificationMethodEmail(
        new List<RegisterVerificationMethodEmailConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(true, responses[0].success, 'Should be successful');
  }

  @IsTest
  static void testVerifyRegisterVerificationMethodEmail_InvalidToken() {
    RegisterVerificationMethodEmailConfirm.Request req =
      new RegisterVerificationMethodEmailConfirm.Request();
    req.code = '000000';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.INVALID_TOKEN;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodEmailConfirm.verifyRegisterVerificationMethodEmail(
        new List<RegisterVerificationMethodEmailConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
  }
}