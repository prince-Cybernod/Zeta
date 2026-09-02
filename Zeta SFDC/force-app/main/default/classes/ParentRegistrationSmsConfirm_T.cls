@IsTest
private class ParentRegistrationSmsConfirm_T {

  @TestSetup
  static void setup() {
    ParentRegistration_TSB.newBuilder()
      .setParentAccount('Test', 'Parent')
      .setEmail('testparent@example.com')
      .setPhone('5551234567')
      .build();
  }

  @IsTest
  static void testVerifySelfRegistrationSMS_Success() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.CodeConfirmationRequest request = tsb.createCodeConfirmationRequest();

    ParentRegistrationSmsConfirm.scenario = ParentRegistrationSmsConfirm.TestScenario.SUCCESS;

    Test.startTest();
    List<ParentRegistrationCommon.ConfirmationResponse> responses =
      ParentRegistrationSmsConfirm.verifySelfRegistrationSMS(new List<ParentRegistrationCommon.CodeConfirmationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.ConfirmationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
    Assert.areEqual('/s/test-success', response.redirectUrl, 'RedirectUrl should match the expected URL');
    Assert.areEqual(tsb.getUserId(), response.userId, 'UserId should match the expected ID');
    Assert.areEqual(tsb.getParentAccountId(), response.accountId, 'AccountId should match the expected ID');
  }

  @IsTest
  static void testVerifySelfRegistrationSMS_TokenNotValid() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.CodeConfirmationRequest request = tsb.createCodeConfirmationRequest();

    ParentRegistrationSmsConfirm.scenario = ParentRegistrationSmsConfirm.TestScenario.INVALID_TOKEN;

    Test.startTest();
    List<ParentRegistrationCommon.ConfirmationResponse> responses =
      ParentRegistrationSmsConfirm.verifySelfRegistrationSMS(new List<ParentRegistrationCommon.CodeConfirmationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.ConfirmationResponse response = responses[0];
    Assert.areEqual('Token not valid', response.errorMessage, 'Error message should match the expected message');
  }

  @IsTest
  static void testVerifySelfRegistrationSMS_ThrowException() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.CodeConfirmationRequest request = tsb.createCodeConfirmationRequest();

    ParentRegistrationSmsConfirm.scenario = ParentRegistrationSmsConfirm.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<ParentRegistrationCommon.ConfirmationResponse> responses =
      ParentRegistrationSmsConfirm.verifySelfRegistrationSMS(new List<ParentRegistrationCommon.CodeConfirmationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.ConfirmationResponse response = responses[0];
    Assert.areEqual('Registration Exception. Please contact support.', response.errorMessage, 'Error message should match the expected message');
  }

}