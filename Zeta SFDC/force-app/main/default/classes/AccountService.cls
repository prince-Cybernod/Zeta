public inherited sharing class AccountService {

  public static final String ACCOUNT_TYPE_GUARDIAN = Schema.SObjectType.Account.getRecordTypeInfosByName()
    .get('Guardian')
    ?.getRecordTypeId();

  public static Account getAccountByEmailOrPhone(String email, String phone) {
    return (Account) SOQL_Account.query()
      .byRecordTypeId(ACCOUNT_TYPE_GUARDIAN)
      .byEmailOrPhone(email, phone)
      .notPortalAccount()
      .toObject();
  }

  public static Account getAccountByContactId(String contactId) {
    return (Account) SOQL_Account.query()
      .byContactId(contactId)
      .toObject();
  }

  public static Account getNewAccount(
    String email,
    String firstName,
    String lastName,
    String phone,
    String street,
    String city,
    String state,
    String postalCode,
    String country
  ) {
    Id guardianAccountId = createGuardianAccount(
      email,
      firstName,
      lastName,
      phone,
      street,
      city,
      state,
      postalCode,
      country
    );
    return (Account) SOQL_Account.query()
      .byId(guardianAccountId)
      .toObject();
  }

  public static Id createGuardianAccount(
    String email,
    String firstName,
    String lastName,
    String mobilePhone,
    String street,
    String city,
    String state,
    String postalCode,
    String country
  ) {
    Account acc = new Account(
      FirstName = firstName,
      LastName = lastName,
      PersonEmail = email,
      PersonMobilePhone = mobilePhone,
      Phone = mobilePhone,
      PersonMailingStreet = street,
      PersonMailingCity = city,
      PersonMailingState = state,
      PersonMailingPostalCode = postalCode,
      PersonMailingCountry = country,
      RecordTypeId = ACCOUNT_TYPE_GUARDIAN
    );
    insert acc;
    return acc.Id;
  }

}