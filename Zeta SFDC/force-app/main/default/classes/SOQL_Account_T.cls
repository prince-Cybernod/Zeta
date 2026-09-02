@IsTest
private class SOQL_Account_T {

  @TestSetup
  static void setup() {
    ParentRegistration_TSB.newBuilder()
      .setParentAccount('Test', 'Parent')
      .setEmail('testparent@example.com')
      .setPhone('5551234567')
      .build();
  }

  @IsTest
  static void testQueryBuilder() {
    ParentRegistration_TSB tsb = ParentRegistration_TSB.getInstance();
    String contactId = tsb.getContactId();

    SOQL_Account q = SOQL_Account.query()
      .byContactId(contactId)
      .byRecordTypeId(UserInfo.getUserId())
      .notPortalAccount();

    Assert.isNotNull(q);
    List<Account> accounts = (List<Account>) q.toList();
    Assert.isNotNull(accounts);
  }

  @IsTest
  static void testByEmailOrPhone() {
    SOQL_Account qBoth = SOQL_Account.query().byEmailOrPhone('testparent@example.com', '5551234567');
    Assert.isNotNull(qBoth);
    List<Account> accsBoth = (List<Account>) qBoth.toList();
    Assert.isNotNull(accsBoth);

    SOQL_Account qEmail = SOQL_Account.query().byEmailOrPhone('testparent@example.com', null);
    Assert.isNotNull(qEmail);

    SOQL_Account qPhone = SOQL_Account.query().byEmailOrPhone(null, '5551234567');
    Assert.isNotNull(qPhone);

    SOQL_Account qNeither = SOQL_Account.query().byEmailOrPhone(null, null);
    Assert.isNotNull(qNeither);
  }

}