/**
 * Tests for {@link SObjectDescribes}.
 */
@IsTest(IsParallel=true)
private class SObjectDescribesTest {
  @IsTest
  private static void get_accountSObjectType_returnsAccountDescribeSObjectResult() {
    SObjectType sobjectType = Schema.Account.SObjectType;

    DescribeSObjectResult result = SObjectDescribes.get(sobjectType);

    Assert.areEqual('Account', result.getName());
  }

  @IsTest
  private static void get_nullSObjectType_throws() {
    SObjectType sobjectType = null;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'SObjectType must have a value. Found null'
    );

    try {
      SObjectDescribes.get(sobjectType);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void get_accountSObjectName_returnsAccountDescribeSObjectResult() {
    String sobjectName = 'Account';

    DescribeSObjectResult result = SObjectDescribes.get(sobjectName);

    Assert.areEqual('Account', result.getName());
  }
}