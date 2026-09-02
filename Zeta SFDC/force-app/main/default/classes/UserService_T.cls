@IsTest
private class UserService_T {

  private static final String TEST_EMAIL = 'testparent@example.com';
  private static final String TEST_PHONE = '5551234567';
  private static final String TEST_FIRST_NAME = 'Test';
  private static final String TEST_LAST_NAME = 'User';
  private static final String TEST_IDENTIFIER = 'test-federation-id';

  @TestSetup
  static void setup() {
    ParentRegistration_TSB.newBuilder()
      .setParentAccount(TEST_FIRST_NAME, TEST_LAST_NAME)
      .setEmail(TEST_EMAIL)
      .setPhone(TEST_PHONE)
      .build();
  }

  @IsTest
  static void getUserCreatesValidUser() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    Id contactId = tsb.getContactId();

    User result = UserService.getUser(
      TEST_EMAIL,
      TEST_PHONE,
      TEST_FIRST_NAME,
      TEST_LAST_NAME,
      TEST_IDENTIFIER,
      contactId
    );

    Assert.areEqual(TEST_EMAIL, result.Email);
    Assert.areEqual(TEST_LAST_NAME, result.LastName);
    Assert.areEqual(TEST_FIRST_NAME, result.FirstName);
    Assert.areEqual(TEST_PHONE, result.MobilePhone);
    Assert.areEqual(TEST_PHONE, result.Phone);
    Assert.isNotNull(result.Alias);
    Assert.isNotNull(result.CommunityNickname);
    Assert.isNotNull(result.Username);
    Assert.areEqual('UTF-8', result.EmailEncodingKey);
    Assert.areEqual('America/Los_Angeles', result.TimeZoneSidKey);
    Assert.areEqual(contactId, result.ContactId);
    Assert.areEqual(TEST_IDENTIFIER, result.FederationIdentifier);
  }

  @IsTest
  static void formatPhoneUsNumberFormatsCorrectly() {
    Assert.areEqual('+64 123456789', UserService.formatPhone('+64 123456789'));
    Assert.areEqual('+1 5551234567', UserService.formatPhone('5551234567'));
    Assert.areEqual('+1 5551234567', UserService.formatPhone('+15551234567'));
    Assert.areEqual('+1 5551234567', UserService.formatPhone('+1 5551234567'));
    Assert.isNull(UserService.formatPhone(''));
    Assert.isNull(UserService.formatPhone(null));
    Assert.isNull(UserService.formatPhone('123'));
  }

  @IsTest
  static void getUserIdByContactIdReturnsCorrectId() {
    Assert.isNull(UserService.getUserIdByContactId(null));

    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    Id contactId = tsb.getContactId();
    Assert.isNull(UserService.getUserIdByContactId(contactId));
  }

  @IsTest
  static void getUniqueEmailAddressReturnsUniqueAddress() {
    String uniqueEmail = UserService.getUniqueEmailAddress();

    Assert.isTrue(uniqueEmail.endsWith('.invalid'));
    Assert.isTrue(uniqueEmail.contains('@'));
    Assert.isTrue(uniqueEmail.contains(UserInfo.getOrganizationId()));

    String anotherEmail = UserService.getUniqueEmailAddress();
    Assert.areNotEqual(uniqueEmail, anotherEmail);
  }

  @IsTest
  static void getTwoFactorMethodsInfoReturnsNullWhenNotFound() {
    TwoFactorMethodsInfo info = UserService.getTwoFactorMethodsInfo(UserInfo.getUserId());
    Assert.isNull(info);
  }

  @IsTest
  static void getAuthProvidersReturnsList() {
    List<ThirdPartyAccountLink> links = UserService.getAuthProviders(UserInfo.getUserId());
    Assert.isNotNull(links);
  }

}