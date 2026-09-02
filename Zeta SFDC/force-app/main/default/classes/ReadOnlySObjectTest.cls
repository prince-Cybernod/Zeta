/**
 * Tests for {@link ReadOnlySObject}.
 */
@IsTest(IsParallel=true)
private class ReadOnlySObjectTest {
  @IsTest
  private static void create_withFieldValues_createsReadOnlySObject() {
    SObjectType sobjectType = UserLicense.SObjectType;
    Map<String, Object> fieldValues = new Map<String, Object>{ 'UsedLicenses' => 10 };

    UserLicense userLicense = (UserLicense) ReadOnlySObject.create(sobjectType, fieldValues);

    Assert.areEqual(10, userLicense.UsedLicenses);
  }

  @IsTest
  private static void create_withChildObjectField_createsReadOnlySObject() {
    SObject sobj = new Account();
    Map<String, Object> fieldValues = new Map<String, Object>{
      'Opportunities' => new List<Opportunity>{ new Opportunity(Name = 'Test') }
    };

    Account account = (Account) ReadOnlySObject.create(sobj, fieldValues);

    Assert.areEqual(1, account.Opportunities.size());
    Assert.areEqual('Test', account.Opportunities[0].Name);
  }

  @IsTest
  private static void builder_createsReadOnlySObject() {
    SObjectType sobjectType = UserLicense.SObjectType;
    ReadOnlySObject.Builder builder = ReadOnlySObject.newBuilder(sobjectType)
      .put('UsedLicenses', 10);

    UserLicense userLicense = (UserLicense) builder.build();

    Assert.areEqual(10, userLicense.UsedLicenses);
  }

  @IsTest
  private static void builder_withChildObjectField_createsReadOnlySObject() {
    SObjectType sobjectType = Account.SObjectType;
    ReadOnlySObject.Builder builder = ReadOnlySObject.newBuilder(sobjectType)
      .put('Opportunities', new List<Opportunity>{ new Opportunity(Name = 'Test') });

    Account account = (Account) builder.build();

    Assert.areEqual(1, account.Opportunities.size());
    Assert.areEqual('Test', account.Opportunities[0].Name);
  }
}