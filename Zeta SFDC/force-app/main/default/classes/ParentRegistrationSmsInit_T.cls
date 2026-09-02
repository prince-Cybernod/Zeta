@IsTest
private class ParentRegistrationSmsInit_T {

  @TestSetup
  static void setup() {
    ParentRegistration_TSB.newBuilder()
      .setParentAccount('Test', 'Parent')
      .setEmail('testparent@example.com')
      .setPhone('5551234567')
      .build();
  }

  @IsTest
  static void testInitSelfRegistrationBySMS_Success() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();

    ParentRegistrationSmsInit.scenario = ParentRegistrationSmsInit.TestScenario.SUCCESS;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationSmsInit.initSelfRegistrationBySMS(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
    Assert.isNotNull(response.contactId, 'ContactId should not be null');
    Assert.isNotNull(response.accountId, 'AccountId should not be null');
  }

  @IsTest
  static void testInitSelfRegistrationBySMS_WithExistingContact() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();
    request.contactId = tsb.getContactId();

    ParentRegistrationSmsInit.scenario = ParentRegistrationSmsInit.TestScenario.WITH_EXISTING_CONTACT;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationSmsInit.initSelfRegistrationBySMS(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
    Assert.areEqual(request.contactId, response.contactId, 'ContactId should match the request');
  }

  @IsTest
  static void testInitSelfRegistrationBySMS_WithoutEmail() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();
    request.email = null;

    ParentRegistrationSmsInit.scenario = ParentRegistrationSmsInit.TestScenario.WITHOUT_EMAIL;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationSmsInit.initSelfRegistrationBySMS(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
  }

  @IsTest
  static void testInitSelfRegistrationBySMS_Exception() {
    ParentRegistrationCommon.RegistrationRequest request = new ParentRegistrationCommon.RegistrationRequest();
    ParentRegistrationSmsInit.scenario = ParentRegistrationSmsInit.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationSmsInit.initSelfRegistrationBySMS(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNotNull(response.errorMessage, 'Error message should not be null');
    Assert.areEqual('Registration Exception. Please contact support.', response.errorMessage, 'Error message should match expected');
  }

}