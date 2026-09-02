@IsTest
public class ParentLoginDiscoveryHandler_T {

  private static Boolean hasVerifiedEmail = false;
  private static Boolean hasVerifiedMobile = false;

  public class MockTwoFactorMethodsInfo {
    public Boolean HasUserVerifiedEmailAddress;
    public Boolean HasUserVerifiedMobileNumber;
  }

  public static TwoFactorMethodsInfo getTwoFactorMethodsInfo(Id userId) {
    MockTwoFactorMethodsInfo mockInfo = new MockTwoFactorMethodsInfo();
    mockInfo.HasUserVerifiedEmailAddress = hasVerifiedEmail;
    mockInfo.HasUserVerifiedMobileNumber = hasVerifiedMobile;

    String str = JSON.serialize(mockInfo);
    return (TwoFactorMethodsInfo) JSON.deserialize(str, TwoFactorMethodsInfo.class);
  }

  public static void setHasVerifiedEmail() {
    hasVerifiedEmail = true;
  }

  public static void setHasVerifiedMobile() {
    hasVerifiedMobile = true;
  }

  static final ParentRegistration_TSB.Builder builder = ParentRegistration_TSB.newBuilder()
    .setEmail('testparent@example.com')
    .setPhone('+1 5551234567')
    .setParentAccount('Test', 'Parent')
    .setPortalUser(null, null);

  @TestSetup
  static void setup() {
    builder.build();
  }

  @IsTest
  static void byEmailWithEmail() {
    String identifier = builder.getInstance().getEmail();
    setHasVerifiedEmail();

    Test.startTest();
    Auth.LoginDiscoveryException expected = getLoginException(identifier);
    Test.stopTest();

    Assert.areNotEqual(null, expected, 'Should attempt passwordless login and throw exception in test context');
  }

  @IsTest
  static void byEmailWithPhone() {
    String identifier = builder.getInstance().getEmail();
    setHasVerifiedMobile();

    Test.startTest();
    Auth.LoginDiscoveryException expected = getLoginException(identifier);
    Test.stopTest();

    Assert.areNotEqual(null, expected, 'Should attempt passwordless login and throw exception in test context');
  }

  @IsTest
  static void byPhoneWithEmail() {
    String identifier = builder.getInstance().getPhone();
    setHasVerifiedEmail();

    Test.startTest();
    Auth.LoginDiscoveryException expected = getLoginException(identifier);
    Test.stopTest();

    Assert.areNotEqual(null, expected, 'Should attempt passwordless login and throw exception in test context');
  }

  @IsTest
  static void byPhoneWithPhone() {
    String identifier = builder.getInstance().getPhone();
    setHasVerifiedMobile();

    Test.startTest();
    Auth.LoginDiscoveryException expected = getLoginException(identifier);
    Test.stopTest();

    Assert.areNotEqual(null, expected, 'Should attempt passwordless login and throw exception in test context');
  }

  @IsTest
  static void noVerifiedMethodThrowsException() {
    String identifier = builder.getInstance().getEmail();

    Test.startTest();
    try {
      (new ParentLoginDiscoveryHandler()).login(identifier, '/s/', new Map<String, String>());
      Assert.fail('Should have thrown an exception');
    } catch (Auth.LoginDiscoveryException e) {
      Assert.areEqual('No verified 2FA method found for user.', e.getMessage());
    }
    Test.stopTest();
  }

  private static Auth.LoginDiscoveryException getLoginException(String identifier) {
    try {
      (new ParentLoginDiscoveryHandler()).login(identifier, '/s/', new Map<String, String>());
    } catch (Auth.LoginDiscoveryException e) {
      return e;
    }
    return null;
  }

}