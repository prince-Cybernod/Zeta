/**
 * Base class that creates a {@link VisualEditor.DynamicPickList} for a {@link RecordType}.
 */
public abstract with sharing class RecordTypePicklist extends VisualEditor.DynamicPickList {
  /**
   * Override this method to specify the {@link RecordTypeInfo} objects that will be used in the {@link VisualEditor.DynamicPickList}.
   */
  protected abstract List<RecordTypeInfo> getRecordTypeInfos();

  /**
   * Builds and returns the default {@link VisualEditor.DataRow} for this {@link RecordType}.
   *
   * The {@link RecordType.Name} is used as the value because {@link RecordType.DeveloperName} is not available in the
   * response from the UI API.
   *
   * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_type_info.htm
   */
  public override VisualEditor.DataRow getDefaultValue() {
    for (RecordTypeInfo recordTypeInfo : getRecordTypeInfos()) {
      if (recordTypeInfo.isDefaultRecordTypeMapping()) {
        return new VisualEditor.DataRow(recordTypeInfo.getName(), recordTypeInfo.getName());
      }
    }

    // --None-- is used as the default empty value in Picklists in the Salesforce UI
    return new VisualEditor.DataRow('--None--', null);
  }

  /**
   * Builds and returns the {@link VisualEditor.DynamicPickListRows} for this {@link RecordType}.
   *
   * The {@link RecordType.Name} is used as the value because {@link RecordType.DeveloperName} is not available in the
   * response from the UI API.
   *
   * @see https://developer.salesforce.com/docs/atlas.en-us.uiapi.meta/uiapi/ui_api_responses_record_type_info.htm
   */
  public override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows pickListRows = new VisualEditor.DynamicPickListRows();
    for (RecordTypeInfo recordTypeInfo : getRecordTypeInfos()) {
      pickListRows.addRow(
        new VisualEditor.DataRow(recordTypeInfo.getName(), recordTypeInfo.getName())
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
   * Base tests for an implementation of {@link RecordTypePicklist}.
   */
  @TestVisible
  private class BaseTest {
    private final RecordTypePicklist recordTypePicklist;

    @TestVisible
    private BaseTest(RecordTypePicklist recordTypePicklist) {
      this.recordTypePicklist = recordTypePicklist;
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getDefaultValue_isNotNull() {
      VisualEditor.DataRow defaultValue = recordTypePicklist.getDefaultValue();

      Assert.isNotNull(defaultValue);
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getValues_hasAllRecordTypeInfos() {
      Set<String> recordTypes = new Set<String>();
      for (RecordTypeInfo recordTypeInfo : recordTypePicklist.getRecordTypeInfos()) {
        recordTypes.add(recordTypeInfo.getName());
      }

      VisualEditor.DynamicPickListRows pickListRows = recordTypePicklist.getValues();

      for (Integer i = 0; i < pickListRows.size(); i++) {
        VisualEditor.DataRow row = pickListRows.get(i);
        Assert.isTrue(
          recordTypes.contains((String) row.getValue()),
          'RecordType Picklist should contain ' + row.getValue()
        );
      }
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void isValid_returnsTrue() {
      Boolean isValid = recordTypePicklist.isValid('');

      Assert.isTrue(isValid);
    }
  }
}