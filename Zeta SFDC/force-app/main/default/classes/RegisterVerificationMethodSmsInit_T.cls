@IsTest(IsParallel=false)
private class RegisterVerificationMethodSmsInit_T {
  @IsTest
  static void testInitRegisterVerificationMethodSMS_Success() {

    RegisterVerificationMethodInit.scenario =
      RegisterVerificationMethodInit.TestScenario.SUCCESS;

    Test.startTest();
    List<RegisterVerificationMethodInit.Response> responses =
      RegisterVerificationMethodSmsInit.initRegisterVerificationMethodSMS(
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(true, responses[0].success, 'Should be successful');
  }

  @IsTest
  static void testInitRegisterVerificationMethodSMS_Exception() {

    RegisterVerificationMethodInit.scenario =
      RegisterVerificationMethodInit.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<RegisterVerificationMethodInit.Response> responses =
      RegisterVerificationMethodSmsInit.initRegisterVerificationMethodSMS(
      );
    Test.stopTest();

    System.assertEquals(1, responses.size(), 'Should return one response');
    System.assertEquals(false, responses[0].success, 'Should not be successful');
  }
}