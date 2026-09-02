/**
 * Base class that creates a {@link VisualEditor.DynamicPickList} for a {@link SObjectField}.
 */
public abstract with sharing class SObjectFieldPicklist extends VisualEditor.DynamicPickList {
  /**
   * Override this method to specify the {@link PicklistEntry} objects that will be used in the
   * {@link VisualEditor.DynamicPickList}.
   */
  protected abstract List<PicklistEntry> getPicklistEntries();

  /**
   * Builds and returns the default {@link VisualEditor.DataRow} for this {@link SObjectField}.
   */
  public override VisualEditor.DataRow getDefaultValue() {
    for (PicklistEntry picklistEntry : getPicklistEntries()) {
      if (picklistEntry.isDefaultValue()) {
        return new VisualEditor.DataRow(picklistEntry.getLabel(), picklistEntry.getValue());
      }
    }

    // --None-- is used as the default empty value in Picklists in the Salesforce UI
    return new VisualEditor.DataRow('--None--', null);
  }

  /**
   * Builds and returns the {@link VisualEditor.DynamicPickListRows} for this {@link SObjectField}.
   */
  public virtual override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows pickListRows = new VisualEditor.DynamicPickListRows();
    for (PicklistEntry picklistEntry : getPicklistEntries()) {
      pickListRows.addRow(
        new VisualEditor.DataRow(picklistEntry.getLabel(), picklistEntry.getValue())
      );
    }

    return pickListRows;
  }

  /**
   * Always returns true. Added to improve performance. See notes.
   *
   * From the documentation:
   * isValid() runs in Experience Cloud sites when the page loads. If you did not implement the method, the default
   * implementation runs getValues(). Running getValues() causes performance degradations. Implement a non-operational
   * isValid() method to avoid potential performance degradations.
   *
   * @see https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/components_config_for_app_builder_dynamic_picklists.htm
   */
  public Boolean isValid(String unused) {
    return true;
  }

  /**
   * Base tests for an implementation of {@link SObjectFieldPicklist}.
   */
  @TestVisible
  private class BaseTest {
    private final SObjectFieldPicklist sobjectFieldPicklist;

    @TestVisible
    private BaseTest(SObjectFieldPicklist sobjectFieldPicklist) {
      this.sobjectFieldPicklist = sobjectFieldPicklist;
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getDefaultValue_isNotNull() {
      VisualEditor.DataRow defaultValue = sobjectFieldPicklist.getDefaultValue();

      Assert.isNotNull(defaultValue);
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getValues_hasAllPicklistEntryValues() {
      List<PicklistEntry> picklistEntries = sobjectFieldPicklist.getPicklistEntries();
      Set<String> picklistEntryValues = new Set<String>();
      for (PicklistEntry picklistEntry : picklistEntries) {
        picklistEntryValues.add(picklistEntry.getValue());
      }

      VisualEditor.DynamicPickListRows pickListRows = sobjectFieldPicklist.getValues();

      for (Integer i = 0; i < pickListRows.size(); i++) {
        VisualEditor.DataRow row = pickListRows.get(i);
        Assert.isTrue(
          picklistEntryValues.contains((String) row.getValue()),
          'SObjectField Picklist should contain ' + row.getValue()
        );
      }
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void isValid_returnsTrue() {
      Boolean isValid = sobjectFieldPicklist.isValid('');

      Assert.isTrue(isValid);
    }
  }
}