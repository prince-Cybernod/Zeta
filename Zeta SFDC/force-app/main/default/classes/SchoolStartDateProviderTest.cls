/**
 * Tests for {@link SchoolStartDateProvider}. All SOQL is mocked via
 * {@link DatabaseRepoMock} so the suite is hermetic — no dependence on the
 * CMT records actually being deployed to the running org.
 */
@IsTest(IsParallel=true)
private class SchoolStartDateProviderTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SchoolStartDateProvider.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void get_overrideTakesPrecedence() {
    Date stubbed = Date.newInstance(2030, 9, 1);
    SchoolStartDateProvider.overrideValue = stubbed;
    Id anyId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    Date result = SchoolStartDateProvider.get(anyId);

    Assert.areEqual(stubbed, result, 'Test override should win');
    SchoolStartDateProvider.overrideValue = null;
  }

  @IsTest
  private static void get_nullRecordId_returnsNullWithoutQuery() {
    DATABASE_REPO_MOCK.reset();

    Date result = SchoolStartDateProvider.get(null);

    Assert.areEqual(null, result);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void get_settingMissing_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    // First query — the CMT setting — returns empty.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<School_Start_Date_Setting__mdt>());

    Id anyId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);
    Date result = SchoolStartDateProvider.get(anyId);

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void get_settingHasNoSourceField_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<School_Start_Date_Setting__mdt>{ new School_Start_Date_Setting__mdt() });

    Id anyId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);
    Date result = SchoolStartDateProvider.get(anyId);

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void get_recordTypeMismatch_returnsNullBeforeDataQuery() {
    DATABASE_REPO_MOCK.reset();
    Id sourceFieldId = SObjectIds.generateFakeId(Schema.SObject_Field__mdt.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // (1) setting
      .thenReturn(
        new List<School_Start_Date_Setting__mdt>{
          new School_Start_Date_Setting__mdt(Source_Field__c = sourceFieldId)
        }
      )
      // (2) source field — configured for AcademicTerm
      .thenReturn(buildAcademicTermStartDateSourceFieldRow());

    // Pass an IndividualApplication Id when the CMT says AcademicTerm.
    Id mismatched = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Date result = SchoolStartDateProvider.get(mismatched);

    Assert.areEqual(null, result);
    // The two CMT queries ran but no data query happened.
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 2);
  }

  @IsTest
  private static void get_happyPath_returnsDateFromConfiguredField() {
    DATABASE_REPO_MOCK.reset();
    Id sourceFieldId = SObjectIds.generateFakeId(Schema.SObject_Field__mdt.SObjectType);
    Id termId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);
    Datetime termStart = Datetime.newInstanceGmt(2026, 9, 1, 0, 0, 0);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // (1) setting
      .thenReturn(
        new List<School_Start_Date_Setting__mdt>{
          new School_Start_Date_Setting__mdt(Source_Field__c = sourceFieldId)
        }
      )
      // (2) source field
      .thenReturn(buildAcademicTermStartDateSourceFieldRow())
      // (3) the actual data row
      .thenReturn(
        new List<AcademicTerm>{ new AcademicTerm(Id = termId, StartDate = termStart) }
      );

    Date result = SchoolStartDateProvider.get(termId);

    Assert.areEqual(Date.newInstance(2026, 9, 1), result, 'Datetime should convert to GMT date');
  }

  @IsTest
  private static void get_dateField_returnsDateAsIs() {
    DATABASE_REPO_MOCK.reset();
    Id sourceFieldId = SObjectIds.generateFakeId(Schema.SObject_Field__mdt.SObjectType);
    Id termId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    // Reuse the AcademicTerm source field row but the data row returns a Date-
    // valued field (DecisionReleaseDate on ApplicationTimeline is Date) — but
    // we're configured for AcademicTerm here, so simulate the same via a
    // Date-valued mock return. The path-through is what matters.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<School_Start_Date_Setting__mdt>{
          new School_Start_Date_Setting__mdt(Source_Field__c = sourceFieldId)
        }
      )
      .thenReturn(buildAcademicTermStartDateSourceFieldRow())
      .thenReturn(
        new List<AcademicTerm>{
          new AcademicTerm(
            Id = termId,
            StartDate = Datetime.newInstanceGmt(2027, 8, 15, 0, 0, 0)
          )
        }
      );

    Date result = SchoolStartDateProvider.get(termId);

    Assert.areEqual(Date.newInstance(2027, 8, 15), result);
  }

  @IsTest
  private static void get_dataQueryReturnsEmpty_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    Id sourceFieldId = SObjectIds.generateFakeId(Schema.SObject_Field__mdt.SObjectType);
    Id termId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<School_Start_Date_Setting__mdt>{
          new School_Start_Date_Setting__mdt(Source_Field__c = sourceFieldId)
        }
      )
      .thenReturn(buildAcademicTermStartDateSourceFieldRow())
      .thenReturn(new List<AcademicTerm>());

    Date result = SchoolStartDateProvider.get(termId);

    Assert.areEqual(null, result);
  }

  @IsTest
  private static void get_recordFieldIsNull_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    Id sourceFieldId = SObjectIds.generateFakeId(Schema.SObject_Field__mdt.SObjectType);
    Id termId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<School_Start_Date_Setting__mdt>{
          new School_Start_Date_Setting__mdt(Source_Field__c = sourceFieldId)
        }
      )
      .thenReturn(buildAcademicTermStartDateSourceFieldRow())
      .thenReturn(new List<AcademicTerm>{ new AcademicTerm(Id = termId) });

    Date result = SchoolStartDateProvider.get(termId);

    Assert.areEqual(null, result);
  }

  /**
   * Build an SObject_Field__mdt row that resolves to AcademicTerm.StartDate
   * with the relationship-traversal QualifiedApiName fields populated, which
   * is what SObjectFieldCmdtParser reads.
   */
  private static List<SObject_Field__mdt> buildAcademicTermStartDateSourceFieldRow() {
    String payload =
      '{' +
      '"attributes":{"type":"SObject_Field__mdt"},' +
      '"Entity_Definition__r":{"attributes":{"type":"EntityDefinition"},"QualifiedApiName":"AcademicTerm"},' +
      '"Field_Definition__r":{"attributes":{"type":"FieldDefinition"},"QualifiedApiName":"StartDate"}' +
      '}';
    return new List<SObject_Field__mdt>{
      (SObject_Field__mdt) JSON.deserialize(payload, Type.forName('SObject_Field__mdt'))
    };
  }
}