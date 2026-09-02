/**
 * Tests for {@link SObjectFieldPicklist}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldPicklistTest {
  private static final SObjectFieldPicklist.BaseTest TEST;

  static {
    TEST = new SObjectFieldPicklist.BaseTest(new ExampleSObjectFieldPicklist());
  }

  @IsTest
  private static void getDefaultValue_isNotNull() {
    TEST.getDefaultValue_isNotNull();
  }

  @IsTest
  private static void getValues_hasAllPicklistEntryValues() {
    TEST.getValues_hasAllPicklistEntryValues();
  }

  @IsTest
  private static void isValid_returnsTrue() {
    TEST.isValid_returnsTrue();
  }

  private class ExampleSObjectFieldPicklist extends SObjectFieldPicklist {
    protected override List<PicklistEntry> getPicklistEntries() {
      List<String> entries = new List<String>{ 'Test 1', 'Test 2', 'Test 3' };

      List<PicklistEntry> picklistEntries = new List<PicklistEntry>();
      for (String entry : entries) {
        PicklistEntry picklistEntry = (PicklistEntry) ObjectUtil.buildReadOnlyObject(
          Schema.PicklistEntry.class,
          new Map<String, Object>{ 'active' => true, 'label' => entry, 'value' => entry }
        );

        picklistEntries.add(picklistEntry);
      }

      return picklistEntries;
    }
  }
}