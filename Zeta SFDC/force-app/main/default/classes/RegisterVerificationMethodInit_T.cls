@IsTest(IsParallel=false)
private class RegisterVerificationMethodInit_T {
  @IsTest
  static void testInitRegisterVerificationMethod_Success() {
    RegisterVerificationMethodInit.Request req = new RegisterVerificationMethodInit.Request();
    req.method = 'EMAIL';

    RegisterVerificationMethodInit.scenario = RegisterVerificationMethodInit.TestScenario.SUCCESS;

    Test.startTest();
    List<RegisterVerificationMethodInit.Response> responses =
      RegisterVerificationMethodInit.initRegisterVerificationMethod(
        new List<RegisterVerificationMethodInit.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(true, responses[0].success, 'Should be successful');
    System.assertEquals('/s/test-verify', responses[0].redirectUrl, 'Should match redirect URL');
    System.assertEquals(null, responses[0].errorMessage, 'Error message should be null');
  }

  @IsTest
  static void testInitRegisterVerificationMethod_Exception() {
    RegisterVerificationMethodInit.Request req = new RegisterVerificationMethodInit.Request();
    req.method = 'EMAIL';

    RegisterVerificationMethodInit.scenario =
      RegisterVerificationMethodInit.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<RegisterVerificationMethodInit.Response> responses =
      RegisterVerificationMethodInit.initRegisterVerificationMethod(
        new List<RegisterVerificationMethodInit.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
    System.assertNotEquals(null, responses[0].errorMessage, 'Error message should not be null');
  }

  @IsTest
  static void testInitRegisterVerificationMethod_Default() {
    RegisterVerificationMethodInit.Request req = new RegisterVerificationMethodInit.Request();
    req.method = 'EMAIL';

    Test.startTest();
    List<RegisterVerificationMethodInit.Response> responses =
      RegisterVerificationMethodInit.initRegisterVerificationMethod(
        new List<RegisterVerificationMethodInit.Request>{ req }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
  }

  @IsTest
  static void testToVerificationMethod_Conversions() {
    System.assertEquals(
      Auth.VerificationMethod.EMAIL,
      RegisterVerificationMethodInit.toVerificationMethod('EMAIL'),
      'Should resolve EMAIL'
    );
    System.assertEquals(
      Auth.VerificationMethod.EMAIL,
      RegisterVerificationMethodInit.toVerificationMethod(null),
      'Null should default to EMAIL'
    );
    System.assertEquals(
      Auth.VerificationMethod.SMS,
      RegisterVerificationMethodInit.toVerificationMethod('sms'),
      'Should resolve SMS'
    );
    System.assertEquals(
      Auth.VerificationMethod.SALESFORCE_AUTHENTICATOR,
      RegisterVerificationMethodInit.toVerificationMethod('Salesforce_Authenticator'),
      'Should resolve SALESFORCE_AUTHENTICATOR'
    );
    System.assertEquals(
      Auth.VerificationMethod.TOTP,
      RegisterVerificationMethodInit.toVerificationMethod('totp'),
      'Should resolve TOTP'
    );
    System.assertEquals(
      Auth.VerificationMethod.U2F,
      RegisterVerificationMethodInit.toVerificationMethod('u2f'),
      'Should resolve U2F'
    );
    System.assertEquals(
      Auth.VerificationMethod.PASSWORD,
      RegisterVerificationMethodInit.toVerificationMethod('password'),
      'Should resolve PASSWORD'
    );

    try {
      RegisterVerificationMethodInit.toVerificationMethod('INVALID_UNKNOWN_METHOD');
      System.assert(false, 'Should throw exception for unknown method');
    } catch (IllegalArgumentException expected) {
      System.assert(true, 'Expected exception caught');
    }
  }
}