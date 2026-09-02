@IsTest
public class ParentRegistration_TSB {

  private static ParentRegistration_TSB instance;

  public class Builder {
    private Account testParentAccount;
    private Contact testContact;
    private User testUser;
    private String testEmail;
    private String testPhone;
    private String testCode;
    private String testSelfRegId;
    private String testStartUrl;

    public Builder() {
      this.testEmail = 'test' + Crypto.getRandomInteger() + '@example.com';
      this.testPhone = '555' + String.valueOf(1000000 + Math.abs(Crypto.getRandomInteger())).substring(0, 7);
      this.testCode = '123456';
      this.testSelfRegId = 'TST' + Crypto.getRandomInteger();
      this.testStartUrl = '/s/';
    }

    public Builder setParentAccount(String firstName, String lastName) {
      this.testParentAccount = new Account(
        FirstName = firstName,
        LastName = lastName,
        PersonEmail = this.testEmail,
        Phone = this.testPhone,
        PersonMailingStreet = '123 Test St',
        PersonMailingCity = 'Test City',
        PersonMailingState = 'TX',
        PersonMailingPostalCode = '12345',
        PersonMailingCountry = 'USA',
        RecordTypeId = AccountService.ACCOUNT_TYPE_GUARDIAN
      );
      return this;
    }

    public Builder setParentAccount(
      String firstName,
      String lastName,
      String street,
      String city,
      String state,
      String postalCode,
      String country
    ) {
      this.testParentAccount = new Account(
        FirstName = firstName,
        LastName = lastName,
        PersonEmail = this.testEmail,
        Phone = this.testPhone,
        PersonMailingStreet = street,
        PersonMailingCity = city,
        PersonMailingState = state,
        PersonMailingPostalCode = postalCode,
        PersonMailingCountry = country,
        RecordTypeId = AccountService.ACCOUNT_TYPE_GUARDIAN
      );
      return this;
    }

    public Builder setEmail(String email) {
      this.testEmail = email;
      return this;
    }

    public Builder setPhone(String phone) {
      this.testPhone = phone;
      return this;
    }

    public Builder setPortalUser(String email, String username) {
      String userEmail = (email != null) ? email : this.testEmail;
      String userUsername = (username != null) ? username : userEmail + '.test';

      Profile communityProfile = [SELECT Id FROM Profile WHERE Name = :UserService.PROFILE LIMIT 1];

      this.testUser = new User(
        FirstName = this.testParentAccount?.FirstName ?? 'Test',
        LastName = this.testParentAccount?.LastName ?? 'Parent',
        Email = userEmail,
        MobilePhone = this.testPhone,
        Username = userUsername,
        Alias = 'tparent',
        CommunityNickname = 'TestParent' + Crypto.getRandomInteger(),
        TimeZoneSidKey = 'America/Los_Angeles',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = communityProfile.Id,
        IsActive = true
      );

      return this;
    }

    public ParentRegistration_TSB build() {
      if (testParentAccount != null) {
        insert testParentAccount;
        testContact = [SELECT Id FROM Contact WHERE AccountId = :testParentAccount.Id LIMIT 1];
      }

      if (testUser != null) {
        if (testContact != null && testUser.ContactId == null) {
          testUser.ContactId = testContact.Id;
        }
        insert testUser;
      }

      ParentRegistration_TSB newInstance = new ParentRegistration_TSB(
        testParentAccount,
        testContact,
        testUser,
        testEmail,
        testPhone,
        testCode,
        testSelfRegId,
        testStartUrl
      );

      instance = newInstance;
      return newInstance;
    }

    public ParentRegistration_TSB getInstance() {
      List<Account> accounts = [
        SELECT
          Id,
          FirstName,
          LastName,
          PersonEmail,
          Phone,
          PersonContactId,
          PersonMailingStreet,
          PersonMailingCity,
          PersonMailingState,
          PersonMailingPostalCode,
          PersonMailingCountry
        FROM Account
        WHERE PersonEmail = :testEmail
        LIMIT 1
      ];

      if (!accounts.isEmpty()) {
        Account account = accounts[0];
        Contact contact = [SELECT Id FROM Contact WHERE Id = :account.PersonContactId LIMIT 1];

        List<User> users = [
          SELECT Id
          FROM User
          WHERE Email = :testEmail
          AND IsActive = true
          LIMIT 1
        ];

        User user = !users.isEmpty() ? users[0] : null;

        return new ParentRegistration_TSB(
          account,
          contact,
          user,
          testEmail,
          testPhone,
          testCode,
          testSelfRegId,
          testStartUrl
        );
      }
      return null;
    }
  }

  private Account parentAccount;
  private Contact contact;
  private User user;
  private String email;
  private String phone;
  private String code;
  private String selfRegId;
  private String startUrl;

  private ParentRegistration_TSB(
    Account parentAccount,
    Contact contact,
    User user,
    String email,
    String phone,
    String code,
    String selfRegId,
    String startUrl
  ) {
    this.parentAccount = parentAccount;
    this.contact = contact;
    this.user = user;
    this.email = email;
    this.phone = phone;
    this.code = code;
    this.selfRegId = selfRegId;
    this.startUrl = startUrl;
  }

  public static Builder newBuilder() {
    instance = null;
    return new Builder();
  }

  public static ParentRegistration_TSB getInstance() {
    List<Account> accounts = [
      SELECT
        Id,
        FirstName,
        LastName,
        PersonEmail,
        Phone,
        PersonContactId,
        PersonMailingStreet,
        PersonMailingCity,
        PersonMailingState,
        PersonMailingPostalCode,
        PersonMailingCountry
      FROM Account
      WHERE RecordTypeId = :AccountService.ACCOUNT_TYPE_GUARDIAN
      LIMIT 1
    ];
    if (!accounts.isEmpty()) {
      Account account = accounts[0];
      return getInstance(account.FirstName, account.LastName, account.PersonEmail);
    }
    return null;
  }

  public static ParentRegistration_TSB getInstance(String firstName, String lastName, String email) {
    try {
      List<Account> accounts = [
        SELECT
          Id,
          FirstName,
          LastName,
          PersonEmail,
          Phone,
          PersonContactId,
          PersonMailingStreet,
          PersonMailingCity,
          PersonMailingState,
          PersonMailingPostalCode,
          PersonMailingCountry
        FROM Account
        WHERE FirstName = :firstName
        AND LastName = :lastName
        AND PersonEmail = :email
        LIMIT 1
      ];

      if (!accounts.isEmpty()) {
        Account account = accounts[0];
        Contact contact = [SELECT Id FROM Contact WHERE Id = :account.PersonContactId LIMIT 1];

        List<User> users = [
          SELECT Id
          FROM User
          WHERE Email = :email
          AND IsActive = true
          LIMIT 1
        ];

        User user = !users.isEmpty() ? users[0] : null;

        return new ParentRegistration_TSB(
          account,
          contact,
          user,
          email,
          account.Phone,
          '123456',
          'TST' + Crypto.getRandomInteger(),
          '/s/'
        );
      }
    } catch (Exception e) {}
    return null;
  }

  public ParentRegistrationCommon.RegistrationRequest createRegistrationRequest() {
    ParentRegistrationCommon.RegistrationRequest request = new ParentRegistrationCommon.RegistrationRequest();
    request.firstName = this.parentAccount?.FirstName ?? 'Test';
    request.lastName = this.parentAccount?.LastName ?? 'Parent';
    request.email = this.email;
    request.phone = this.phone;
    request.contactId = this.contact?.Id;
    request.startUrl = this.startUrl;
    request.street = this.parentAccount?.PersonMailingStreet;
    request.city = this.parentAccount?.PersonMailingCity;
    request.state = this.parentAccount?.PersonMailingState;
    request.postalCode = this.parentAccount?.PersonMailingPostalCode;
    request.country = this.parentAccount?.PersonMailingCountry;
    return request;
  }

  public ParentRegistrationCommon.CodeConfirmationRequest createCodeConfirmationRequest() {
    ParentRegistrationCommon.CodeConfirmationRequest request = new ParentRegistrationCommon.CodeConfirmationRequest();
    request.selfRegId = this.selfRegId;
    request.code = this.code;
    request.phone = this.phone;
    request.email = this.email;
    request.startUrl = this.startUrl;
    request.contactId = this.contact?.Id;
    return request;
  }

  public Id getParentAccountId() {
    return this.parentAccount?.Id;
  }

  public Id getContactId() {
    return this.contact?.Id;
  }

  public Id getUserId() {
    return this.user?.Id;
  }

  public String getEmail() {
    return this.email;
  }

  public String getPhone() {
    return this.phone;
  }

  public String getCode() {
    return this.code;
  }

  public String getSelfRegId() {
    return this.selfRegId;
  }

  public String getStartUrl() {
    return this.startUrl;
  }

}