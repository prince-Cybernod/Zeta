public without sharing class SOQL_Account extends SOQL implements SOQL.Selector {

  public static SOQL_Account query() {
    return new SOQL_Account();
  }

  private SOQL_Account() {
    super(Account.SObjectType);
    withoutSharing();
    systemMode();
    with(Account.Id, Account.PersonContactId, Account.FirstName, Account.LastName);
  }

  public SOQL_Account byRecordTypeId(Id typeId) {
    whereAre(Filter.with(Account.RecordTypeId).equal(typeId));
    return this;
  }

  public SOQL_Account byContactId(String contactId) {
    whereAre(Filter.with(Account.PersonContactId).equal(contactId));
    return this;
  }

  public SOQL_Account byEmailOrPhone(String email, String mobilePhone) {
    SOQL.Filter emailFilter = SOQL.Filter.with(Account.PersonEmail).equal(email);
    SOQL.FilterGroup phoneFilter = SOQL.FilterGroup
      .add(SOQL.Filter.with(Account.PersonMobilePhone).equal(mobilePhone))
      .add(SOQL.Filter.with(Account.Phone).equal(mobilePhone))
      .anyConditionMatching();
    if (String.isNotBlank(email) && String.isNotBlank(mobilePhone)) {
      whereAre(SOQL.FilterGroup.add(emailFilter).add(phoneFilter).anyConditionMatching());
    } else if (String.isNotBlank(email)) {
      whereAre(emailFilter);
    } else if (String.isNotBlank(mobilePhone)) {
      whereAre(phoneFilter);
    }
    return this;
  }

  public SOQL_Account notPortalAccount() {
    whereAre(Filter.with(Account.PersonContactId).notIn(
      SOQL.InnerJoin.of(User.SObjectType).with(User.ContactId)
    ));
    return this;
  }

}