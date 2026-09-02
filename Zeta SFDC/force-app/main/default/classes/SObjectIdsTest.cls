/**
 * Tests for {@link SObjectIds}.
 */
@IsTest(IsParallel=true)
private class SObjectIdsTest {
  @IsTest
  private static void getSObjectTypeName_accountId_returnsAccount() {
    Id id = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    String sobjectName = SObjectIds.getSObjectTypeName(id);

    Assert.areEqual('Account', sobjectName);
  }

  @IsTest
  private static void getSObjectTypeName_blankId_returnsNull() {
    Id id = null;

    String sobjectName = SObjectIds.getSObjectTypeName(id);

    Assert.isNull(sobjectName);
  }

  @IsTest
  private static void fromSObjects_withoutField_collectsAndReturnsIds() {
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId()) };

    List<Id> userIds = SObjectIds.fromSObjects(users);

    AssertUtil.containsExactly(new List<Id>{ UserInfo.getUserId() }, userIds);
  }

  @IsTest
  private static void fromSObjects_idField_collectsAndReturnsIds() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    List<Opportunity> opportunities = new List<Opportunity>{
      new Opportunity(AccountId = accountId)
    };
    SObjectField field = Schema.Opportunity.AccountId;

    List<Id> ids = SObjectIds.fromSObjects(opportunities, field);

    AssertUtil.containsExactly(new List<Id>{ accountId }, ids);
  }

  @IsTest
  private static void fromSObjects_fieldReference_collectsAndReturnsIds() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
      new OpportunityLineItem(Opportunity = new Opportunity(AccountId = accountId))
    };
    SObjectFieldReference field = SObjectFieldReference.create('Opportunity.AccountId');

    List<Id> ids = SObjectIds.fromSObjects(opportunityLineItems, field);

    AssertUtil.containsExactly(new List<Id>{ accountId }, ids);
  }

  @IsTest
  private static void fromSObjects_otherTypeOfField_throws() {
    List<User> users = new List<User>{ new User(LastName = UserInfo.getLastName()) };
    SObjectField field = Schema.User.LastName;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected the field to be of type: {ID, REFERENCE}. Found: STRING'
    );

    try {
      SObjectIds.fromSObjects(users, field);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  @SuppressWarnings('PMD.AvoidHardcodingId')
  private static void generateFakeId() {
    SObjectType sobjectType = Account.SObjectType;

    String id1 = SObjectIds.generateFakeId(sobjectType);
    String id2 = SObjectIds.generateFakeId(sobjectType);
    String id3 = SObjectIds.generateFakeId(sobjectType);

    Assert.areEqual('001000000000001AAA', id1);
    Assert.areEqual('001000000000002AAA', id2);
    Assert.areEqual('001000000000003AAA', id3);
  }
}