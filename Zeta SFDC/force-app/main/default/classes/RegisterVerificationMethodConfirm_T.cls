@IsTest(IsParallel=false)
private class RegisterVerificationMethodConfirm_T {
  @IsTest
  static void testVerifyRegisterVerificationMethod_Success() {
    RegisterVerificationMethodConfirm.Request req =
      new RegisterVerificationMethodConfirm.Request();
    req.code = '123456';
    req.method = 'EMAIL';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.SUCCESS;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(
        new List<RegisterVerificationMethodConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(true, responses[0].success, 'Should be successful');
    System.assertEquals('/s/test-success', responses[0].redirectUrl, 'Should match redirect URL');
    System.assertEquals(null, responses[0].errorMessage, 'Error message should be null');
  }

  @IsTest
  static void testVerifyRegisterVerificationMethod_InvalidToken() {
    RegisterVerificationMethodConfirm.Request req =
      new RegisterVerificationMethodConfirm.Request();
    req.code = '000000';
    req.method = 'SMS';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.INVALID_TOKEN;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(
        new List<RegisterVerificationMethodConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
    System.assertEquals('Token not valid', responses[0].errorMessage, 'Should indicate token not valid');
  }

  @IsTest
  static void testVerifyRegisterVerificationMethod_Exception() {
    RegisterVerificationMethodConfirm.Request req =
      new RegisterVerificationMethodConfirm.Request();
    req.code = '123456';
    req.method = 'EMAIL';

    RegisterVerificationMethodConfirm.scenario =
      RegisterVerificationMethodConfirm.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(
        new List<RegisterVerificationMethodConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
    System.assertNotEquals(null, responses[0].errorMessage, 'Error message should not be null');
  }

  @IsTest
  static void testVerifyRegisterVerificationMethod_Default() {
    RegisterVerificationMethodConfirm.Request req =
      new RegisterVerificationMethodConfirm.Request();
    req.code = '123456';
    req.method = 'EMAIL';

    Test.startTest();
    List<RegisterVerificationMethodConfirm.Response> responses =
      RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(
        new List<RegisterVerificationMethodConfirm.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
  }
}