public inherited sharing class SOQL_User extends SOQL implements SOQL.Selector {

  public static SOQL_User query() {
    return new SOQL_User();
  }

  private SOQL_User() {
    super(User.SObjectType);
    systemMode();
    with(
      new List<SObjectField>{
        User.Id,
        User.FirstName,
        User.LastName,
        User.Email,
        User.Username,
        User.FederationIdentifier,
        User.IsActive,
        User.Title,
        User.ContactId
      }
    );
  }

  public SOQL_User isActive() {
    whereAre(Filter.with(User.IsActive).isTrue());
    return this;
  }

  public SOQL_User byEmail(String email) {
    whereAre(Filter.with(User.Email).equal(email));
    return this;
  }

  public SOQL_User byFederationIdentifier(String identifier) {
    whereAre(Filter.with(User.FederationIdentifier).equal(identifier));
    return this;
  }

  public SOQL_User byMobilePhone(String phone) {
    whereAre(Filter.with(User.MobilePhone).equal(phone));
    return this;
  }

  public SOQL_User byProfileName(String profileName) {
    whereAre(Filter.with('Profile', Profile.Name).equal(profileName));
    return this;
  }

}