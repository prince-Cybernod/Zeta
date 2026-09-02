/**
 * Returns the school start date for a given source record by looking up which
 * field on which SObject to read from the global
 * {@code School_Start_Date_Setting__mdt.Default} record.
 *
 * The CMT's {@code Source_Field__c} references an {@link SObject_Field__mdt}
 * row. {@link SObjectFieldCmdtParser} resolves the entity + field tokens; the
 * provider runs dynamic SOQL against the passed record and returns the
 * configured field's value as a {@link Date}.
 *
 * Day-one configuration: {@code AcademicTerm.StartDate}. Callers (controllers)
 * pass an {@code ApplicationTimeline.Academic_Term__c} Id.
 *
 * Datetime fields are converted to {@link Date} in the GMT zone to match the
 * dormant {@code Age_Inconsistency_Flag_c__c} formula's {@code DATEVALUE}
 * semantics.
 *
 * All SOQL — including the CMT lookups — routes through {@link DatabaseRepo}
 * so tests can mock the configuration without depending on the CMT records
 * actually being deployed to the test scratch org.
 */
public with sharing class SchoolStartDateProvider {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @TestVisible
  private static Date overrideValue;

  /**
   * @param recordId the Id of the record whose configured field supplies the
   *                 school start date. Must be an SObject of the type stored
   *                 in the CMT's Source Field reference.
   * @return the resolved date, or {@code null} if the CMT is missing, the
   *         passed record's type does not match the configured entity, or the
   *         record has no value in the configured field.
   */
  public static Date get(Id recordId) {
    if (overrideValue != null) {
      return overrideValue;
    }
    if (recordId == null) {
      return null;
    }

    School_Start_Date_Setting__mdt setting = querySetting();
    if (setting == null || setting.Source_Field__c == null) {
      return null;
    }

    SObject_Field__mdt sourceField = querySourceField(setting.Source_Field__c);
    if (sourceField == null) {
      return null;
    }

    SObjectType entityType = SObjectFieldCmdtParser.getSObjectType(sourceField);
    SObjectField field = SObjectFieldCmdtParser.getSObjectField(sourceField);

    // Defensive: the caller's record Id must match the configured entity. If
    // it doesn't, return null rather than throwing — keeps the UI graceful.
    if (recordId.getSObjectType() != entityType) {
      return null;
    }

    String entityName = entityType.getDescribe().getName();
    String fieldName = field.getDescribe().getName();

    List<SObject> rows = databaseRepo.queryWithBinds(
      'SELECT ' + fieldName + ' FROM ' + entityName + ' WHERE Id = :recordId LIMIT 1',
      new Map<String, Object>{ 'recordId' => recordId }
    );
    if (rows.isEmpty()) {
      return null;
    }

    Object value = rows[0].get(fieldName);
    if (value == null) {
      return null;
    }
    if (value instanceof Date) {
      return (Date) value;
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).dateGmt();
    }
    return null;
  }

  private static School_Start_Date_Setting__mdt querySetting() {
    List<SObject> rows = databaseRepo.queryWithBinds(
      'SELECT Source_Field__c FROM School_Start_Date_Setting__mdt' +
      ' WHERE DeveloperName = :developerName LIMIT 1',
      new Map<String, Object>{ 'developerName' => 'Default' }
    );
    return rows.isEmpty() ? null : (School_Start_Date_Setting__mdt) rows[0];
  }

  private static SObject_Field__mdt querySourceField(Id sourceFieldId) {
    List<SObject> rows = databaseRepo.queryWithBinds(
      'SELECT Entity_Definition__r.QualifiedApiName,' +
      ' Field_Definition__r.QualifiedApiName,' +
      ' Entity_Particle__r.QualifiedApiName' +
      ' FROM SObject_Field__mdt WHERE Id = :sourceFieldId LIMIT 1',
      new Map<String, Object>{ 'sourceFieldId' => sourceFieldId }
    );
    return rows.isEmpty() ? null : (SObject_Field__mdt) rows[0];
  }
}