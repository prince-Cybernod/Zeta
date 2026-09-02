/**
 * Tests for {@link SObjectFieldPathResolver}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldPathResolverTest {
  @IsTest
  private static void getValue_withNullSObject_returnsNull() {
    Object result = SObjectFieldPathResolver.getValue(null, 'Account.Name');

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void getValue_withBlankFieldPath_returnsNull() {
    Account acc = new Account(Name = 'Test Account');

    Object result = SObjectFieldPathResolver.getValue(acc, '');

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void getValue_withDirectField_returnsFieldValue() {
    Account acc = new Account(Name = 'Test Account');

    Object result = SObjectFieldPathResolver.getValue(acc, 'Name');

    Assert.areEqual('Test Account', result);
  }

  @IsTest
  private static void getValue_withNullFieldValue_returnsNull() {
    Account acc = new Account();

    Object result = SObjectFieldPathResolver.getValue(acc, 'Name');

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void getValue_withRelationshipField_returnsFieldValue() {
    Account childAccount = new Account(
      Name = 'Child Account',
      Parent = new Account(Name = 'Parent Account')
    );

    Object result = SObjectFieldPathResolver.getValue(childAccount, 'Parent.Name');

    Assert.areEqual('Parent Account', result);
  }

  @IsTest
  private static void getValue_withNullRelationship_returnsNull() {
    Account account = new Account(Name = 'Test Account');

    Object result = SObjectFieldPathResolver.getValue(account, 'Parent.Name');

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void getValue_withMultiLevelRelationship_returnsFieldValue() {
    Account account = new Account(
      Name = 'Child Account',
      Parent = new Account(
        Name = 'Parent Account',
        Parent = new Account(Name = 'Grandparent Account')
      )
    );

    Object result = SObjectFieldPathResolver.getValue(account, 'Parent.Parent.Name');

    Assert.areEqual('Grandparent Account', result);
  }

  @IsTest
  private static void getValue_withNullGrandParentObject_returnsNull() {
    Account account = new Account();

    // Needs Parent.Parent because `Account.Parent` is null, but the loop tries one more time
    Object result = SObjectFieldPathResolver.getValue(account, 'Parent.Parent.Name');

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void getValue_withInvalidFieldPath_throws() {
    Account acc = new Account(Name = 'Test Account');
    AssertThrows.Throwing throwing = AssertThrows.with(
      SObjectException.class,
      'Invalid field InvalidField for Account'
    );

    try {
      SObjectFieldPathResolver.getValue(acc, 'InvalidField');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
}