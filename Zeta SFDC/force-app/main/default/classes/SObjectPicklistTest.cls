/**
 * Tests for {@link SObjectPicklist}.
 */
@IsTest(IsParallel=true)
private class SObjectPicklistTest {
  private static final SObjectPicklist.BaseTest TEST;

  static {
    TEST = new SObjectPicklist.BaseTest(new ExampleSObjectPicklist());
  }

  @IsTest
  private static void getDefaultValue_isNotNull() {
    TEST.getDefaultValue_isNotNull();
  }

  @IsTest
  private static void getValues_hasAllSObjectValues() {
    TEST.getValues_hasAllSObjectValues();
  }

  @IsTest
  private static void isValid() {
    TEST.isValid_returnsTrue();
  }

  @IsTest
  private static void getLabel_returnsExpectedLabel() {
    TEST.getLabel_returnsExpectedLabel(new Account(Name = 'Test'), 'Test');
  }

  private class ExampleSObjectPicklist extends SObjectPicklist {
    protected override List<SObject> getSObjects() {
      return new List<Account>{
        new Account(Name = 'Test 1'),
        new Account(Name = 'Test 2'),
        new Account(Name = 'Test 3')
      };
    }

    protected override String getLabel(SObject sobj) {
      return ((Account) sobj).Name;
    }
  }
}