@IsTest
private class ParentRegistrationEmailInit_T {

  @TestSetup
  static void setup() {
    ParentRegistration_TSB.newBuilder()
      .setParentAccount('Test', 'Parent')
      .setEmail('testparent@example.com')
      .setPhone('5551234567')
      .build();
  }

  @IsTest
  static void testInitSelfRegistrationByEmail_Success() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();

    ParentRegistrationEmailInit.scenario = ParentRegistrationEmailInit.TestScenario.SUCCESS;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationEmailInit.initSelfRegistrationByEmail(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
    Assert.areEqual(null, response.selfRegId, 'SelfRegId should be null in test context');
    Assert.isNotNull(response.contactId, 'ContactId should not be null');
    Assert.isNotNull(response.accountId, 'AccountId should not be null');
  }

  @IsTest
  static void testInitSelfRegistrationByEmail_WithExistingContact() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();
    request.contactId = tsb.getContactId();

    ParentRegistrationEmailInit.scenario = ParentRegistrationEmailInit.TestScenario.WITH_EXISTING_CONTACT;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationEmailInit.initSelfRegistrationByEmail(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNull(response.errorMessage, 'Error message should be null');
    Assert.areEqual(request.contactId, response.contactId, 'ContactId should match the request');
    Assert.isNotNull(response.accountId, 'AccountId should not be null');
  }

  @IsTest
  static void testInitSelfRegistrationByEmail_Exception() {
    ParentRegistrationCommon.RegistrationRequest request = new ParentRegistrationCommon.RegistrationRequest();

    ParentRegistrationEmailInit.scenario = ParentRegistrationEmailInit.TestScenario.THROW_EXCEPTION;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationEmailInit.initSelfRegistrationByEmail(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
    ParentRegistrationCommon.RegistrationResponse response = responses[0];
    Assert.isNotNull(response.errorMessage, 'Error message should not be null');
    Assert.areEqual('Registration Exception. Please contact support.', response.errorMessage, 'Error message should match expected');
  }

  @IsTest
  static void testInitSelfRegistrationByEmail_WhenElseNewAccount() {
    ParentRegistrationCommon.RegistrationRequest request = new ParentRegistrationCommon.RegistrationRequest();
    request.firstName = 'NewFirst';
    request.lastName = 'NewLast';
    request.email = 'newparent@example.com';
    request.phone = '5559876543';
    request.contactId = null;

    ParentRegistrationEmailInit.scenario = null;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationEmailInit.initSelfRegistrationByEmail(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
  }

  @IsTest
  static void testInitSelfRegistrationByEmail_WhenElseExistingContact() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    ParentRegistrationCommon.RegistrationRequest request = tsb.createRegistrationRequest();
    request.contactId = tsb.getContactId();

    ParentRegistrationEmailInit.scenario = null;

    Test.startTest();
    List<ParentRegistrationCommon.RegistrationResponse> responses =
      ParentRegistrationEmailInit.initSelfRegistrationByEmail(new List<ParentRegistrationCommon.RegistrationRequest>{ request });
    Test.stopTest();

    Assert.areEqual(1, responses.size(), 'Should return one response');
  }

}