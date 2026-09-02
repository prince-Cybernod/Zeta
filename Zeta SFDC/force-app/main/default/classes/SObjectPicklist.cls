/**
 * Base class that creates a {@link VisualEditor.DynamicPickList} for an {@link SObject}.
 *
 * This is not annotated with {@code IsTest} because we cannot extend from a class with that
 * annotation: "IsTest classes cannot be abstract".
 */
public abstract with sharing class SObjectPicklist extends VisualEditor.DynamicPickList {
  /**
   * Override this method to specify the {@link SObject} objects that will be used in the
   * {@link VisualEditor.DynamicPickList}.
   */
  protected abstract List<SObject> getSObjects();

  /**
   * Override this method to specify the label for this {@link SObject}.
   */
  protected abstract String getLabel(SObject sobj);

  /**
   * Builds and returns the default {@link VisualEditor.DataRow} for this {@link SObject}.
   */
  public override VisualEditor.DataRow getDefaultValue() {
    // --None-- is used as the default empty value in Picklists in the Salesforce UI
    return new VisualEditor.DataRow('--None--', null);
  }

  /**
   * Builds and returns the {@link VisualEditor.DynamicPickListRows} for this {@link SObject}.
   */
  public virtual override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows pickListRows = new VisualEditor.DynamicPickListRows();
    pickListRows.addRow(getDefaultValue());

    for (SObject sobj : getSObjects()) {
      // Even though Id is a subtype of String, we need to explicitly convert it to a String. If we
      // don't, the UI receives the value in an unexpected format (e.g. {value=a0004000004lF3VAAU})
      String value = String.valueOf(sobj.Id);

      pickListRows.addRow(new VisualEditor.DataRow(getLabel(sobj), value));
    }

    return pickListRows;
  }

  /**
   * Returns {@code true} when the value is valid.
   *
   * The documentation recommends to have this just return {@code true}, but we do a check to make
   * sure the value is either null or a {@link String}. This is done because the only supported
   * data type is {@link String}.
   *
   * From the documentation:
   * isValid() runs in Experience Cloud sites when the page loads. If you did not implement the method, the default
   * implementation runs getValues(). Running getValues() causes performance degradations. Implement a non-operational
   * isValid() method to avoid potential performance degradations.
   *
   * @see https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/components_config_for_app_builder_dynamic_picklists.htm
   */
  public override Boolean isValid(Object value) {
    return value == null || value instanceof String;
  }

  /**
   * Base tests for an implementation of {@link SObject}.
   */
  @TestVisible
  private class BaseTest {
    private final SObjectPicklist sobjectPicklist;

    @TestVisible
    private BaseTest(SObjectPicklist sobjectPicklist) {
      this.sobjectPicklist = sobjectPicklist;
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getDefaultValue_isNotNull() {
      VisualEditor.DataRow defaultValue = sobjectPicklist.getDefaultValue();

      Assert.isNotNull(defaultValue);
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getValues_hasAllSObjectValues() {
      List<SObject> sobjects = sobjectPicklist.getSObjects();
      Set<String> sobjectValues = new Set<String>();
      sobjectValues.add((String) sobjectPicklist.getDefaultValue().getValue());
      for (SObject sobj : sobjects) {
        sobjectValues.add(sobj.Id);
      }

      VisualEditor.DynamicPickListRows pickListRows = sobjectPicklist.getValues();

      for (Integer i = 0; i < pickListRows.size(); i++) {
        VisualEditor.DataRow row = pickListRows.get(i);
        Assert.isTrue(
          sobjectValues.contains((String) row.getValue()),
          'SObject Picklist should contain ' + row.getValue()
        );
      }
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void isValid_returnsTrue() {
      Boolean isValid = sobjectPicklist.isValid(null);

      Assert.isTrue(isValid);
    }

    @SuppressWarnings('PMD.MethodNamingConventions')
    @TestVisible
    private void getLabel_returnsExpectedLabel(SObject sobj, String expected) {
      String label = sobjectPicklist.getLabel(sobj);

      Assert.isNotNull(label);
    }
  }
}