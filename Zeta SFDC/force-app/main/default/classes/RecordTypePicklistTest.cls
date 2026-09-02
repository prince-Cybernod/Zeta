/**
 * Tests for {@link RecordTypePicklist}.
 */
@IsTest(IsParallel=true)
private class RecordTypePicklistTest {
  private static final RecordTypePicklist.BaseTest TEST;

  static {
    TEST = new RecordTypePicklist.BaseTest(new ExampleRecordTypePicklist());
  }

  @IsTest
  private static void getDefaultValue_isNotNull() {
    TEST.getDefaultValue_isNotNull();
  }

  @IsTest
  private static void getValues_hasAllRecordTypeInfos() {
    TEST.getValues_hasAllRecordTypeInfos();
  }

  @IsTest
  private static void isValid_returnsTrue() {
    TEST.isValid_returnsTrue();
  }

  private class ExampleRecordTypePicklist extends RecordTypePicklist {
    protected override List<RecordTypeInfo> getRecordTypeInfos() {
      // Can't use `ReadOnlyObject` because "No suitable constructor found for type" :(
      return Schema.describeSObjects(
          new List<String>{ 'Account' },
          SObjectDescribeOptions.DEFERRED
        )[0]
        .getRecordTypeInfos();
    }
  }
}