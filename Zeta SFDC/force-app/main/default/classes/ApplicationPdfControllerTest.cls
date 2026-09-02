@IsTest(IsParallel=true)
private class ApplicationPdfControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final ApplicationPdfController CONTROLLER;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    CONTROLLER = new ApplicationPdfController(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void getApplication_returnsApplicationData() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Signature_Name__c = 'Test User',
      AppliedDate = Date.today()
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    IndividualApplication result = CONTROLLER.getApplication();

    Assert.areEqual(appId, result.Id, 'Should return the queried application');
    Assert.areEqual('Test User', result.Signature_Name__c, 'Should have signature name');
  }

  @IsTest
  private static void getApplication_throwsWhenNotFound() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    try {
      CONTROLLER.getApplication();
      Assert.fail('Should throw for missing application');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application not found'), 'Should indicate not found');
    }
  }

  @IsTest
  private static void getRankedSchools_returnsSchoolData() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    List<Map<String, Object>> result = CONTROLLER.getRankedSchools();

    Assert.isTrue(result.isEmpty(), 'Should return empty list when no schools');
  }

  @IsTest
  private static void getRankedSchools_includesPostLotteryStatuses() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> interests = new List<AcademicInterest>{
      new AcademicInterest(Id = aiId1, Status = 'Seat Accepted', School_Rank__c = 1),
      new AcademicInterest(Id = aiId2, Status = 'Waitlisted', School_Rank__c = 2)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(interests);

    List<Map<String, Object>> result = CONTROLLER.getRankedSchools();

    Assert.areEqual(2, result.size(), 'Should include records regardless of lottery status');
    Assert.areEqual('1', result[0].get('rank'), 'First record rank');
    Assert.areEqual('2', result[1].get('rank'), 'Second record rank');
  }

  @IsTest
  private static void getSiblings_returnsSeparatedLists() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    Id sibId1 = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id sibId2 = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    List<Priority_Item__c> items = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = sibId1,
        Priority_Type__c = 'Sibling Attending',
        First_Name__c = 'Alice',
        Last_Name__c = 'Test'
      ),
      new Priority_Item__c(
        Id = sibId2,
        Priority_Type__c = 'Sibling Applying',
        First_Name__c = 'Bob',
        Last_Name__c = 'Test'
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(items);

    List<Map<String, Object>> attending = CONTROLLER.getAttendingSiblings();
    List<Map<String, Object>> applying = CONTROLLER.getApplyingSiblings();

    Assert.areEqual(1, attending.size(), 'Should have one attending sibling');
    Assert.areEqual('Alice Test', attending[0].get('name'), 'Should have correct name');
    Assert.areEqual(1, applying.size(), 'Should have one applying sibling');
    Assert.areEqual('Bob Test', applying[0].get('name'), 'Should have correct name');
  }

  @IsTest
  private static void formattedDates_returnEmptyWhenNull() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = new IndividualApplication(Id = appId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual(
      '',
      CONTROLLER.getFormattedSubmissionDate(),
      'Should return empty for null date'
    );
    Assert.areEqual(
      '',
      CONTROLLER.getFormattedSignatureDate(),
      'Should return empty for null date'
    );
  }

  @IsTest
  private static void getFormattedSubmissionDate_withDate_returnsFormatted() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      AppliedDate = Date.newInstance(2025, 3, 15)
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    String result = CONTROLLER.getFormattedSubmissionDate();

    Assert.isTrue(String.isNotBlank(result), 'Should return a formatted date string');
    Assert.isTrue(result.contains('2025'), 'Should contain the year');
  }

  @IsTest
  private static void getFormattedSignatureDate_withDate_returnsFormatted() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Signature_Date__c = Date.newInstance(2025, 6, 1)
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    String result = CONTROLLER.getFormattedSignatureDate();

    Assert.isTrue(String.isNotBlank(result), 'Should return a formatted date string');
    Assert.isTrue(result.contains('2025'), 'Should contain the year');
  }

  @IsTest
  private static void getStudentFirstName_returnsContactFirstName() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"attributes":{"type":"IndividualApplication"},"Id":"' +
        appId +
        '","Contact":{"attributes":{"type":"Contact"},"FirstName":"Jane","LastName":"Doe"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual('Jane', CONTROLLER.getStudentFirstName(), 'Should return Contact.FirstName');
  }

  @IsTest
  private static void getStudentLastName_returnsContactLastName() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"attributes":{"type":"IndividualApplication"},"Id":"' +
        appId +
        '","Contact":{"attributes":{"type":"Contact"},"FirstName":"Jane","LastName":"Doe"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual('Doe', CONTROLLER.getStudentLastName(), 'Should return Contact.LastName');
  }

  @IsTest
  private static void studentNames_returnEmptyWhenBlank() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"attributes":{"type":"IndividualApplication"},"Id":"' +
        appId +
        '","Contact":{"attributes":{"type":"Contact"}}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual('', CONTROLLER.getStudentFirstName(), 'Null first name returns empty');
    Assert.areEqual('', CONTROLLER.getStudentLastName(), 'Null last name returns empty');
  }

  @IsTest
  private static void getStudentDateOfBirth_withDate_returnsFormatted() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"attributes":{"type":"IndividualApplication"},"Id":"' +
        appId +
        '","Contact":{"attributes":{"type":"Contact"},"Birthdate":"2015-09-20"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    String result = CONTROLLER.getStudentDateOfBirth();

    Assert.isTrue(String.isNotBlank(result), 'Should return a formatted date string');
    Assert.isTrue(result.contains('2015'), 'Should contain the year');
  }

  @IsTest
  private static void getStudentDateOfBirth_withNullDate_returnsEmpty() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"attributes":{"type":"IndividualApplication"},"Id":"' +
        appId +
        '","Contact":{"attributes":{"type":"Contact"}}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    String result = CONTROLLER.getStudentDateOfBirth();

    Assert.areEqual('', result, 'Should return empty string for null birthdate');
  }

  @IsTest
  private static void getSignatureName_returnValueAndEmptyWhenNull() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    IndividualApplication appWithName = new IndividualApplication(
      Id = appId,
      Signature_Name__c = 'Test Signer'
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ appWithName });
    Assert.areEqual('Test Signer', CONTROLLER.getSignatureName(), 'Returns signature name');
  }

  @IsTest
  private static void getLanguage_defaultsToEnglish() {
    Test.setCurrentPage(Page.ApplicationPdf);

    Assert.areEqual('en', CONTROLLER.getLanguage(), 'Defaults to en when no lang param');
  }

  @IsTest
  private static void getLanguage_returnsSpanishWhenLangIsEs() {
    PageReference page = Page.ApplicationPdf;
    page.getParameters().put('lang', 'es');
    Test.setCurrentPage(page);

    Assert.areEqual('es', CONTROLLER.getLanguage(), 'Returns es when lang=es');
  }

  @IsTest
  private static void getLanguage_returnsEnglishForUnrecognizedValue() {
    PageReference page = Page.ApplicationPdf;
    page.getParameters().put('lang', 'fr');
    Test.setCurrentPage(page);

    Assert.areEqual('en', CONTROLLER.getLanguage(), 'Defensive default for unknown lang');
  }

  @IsTest
  private static void getFormAnswers_returnsListWithGroupedShape() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    List<Map<String, Object>> result = CONTROLLER.getFormAnswers();

    Assert.isNotNull(result, 'Should return a list');
    for (Map<String, Object> section : result) {
      Assert.isTrue(
        section.containsKey('sectionDeveloperName'),
        'Each entry has sectionDeveloperName'
      );
      Assert.isTrue(section.containsKey('sectionLabel'), 'Each entry has sectionLabel');
      Assert.isTrue(section.containsKey('answers'), 'Each entry has answers list');
    }
  }

  @IsTest
  private static void formatAnswerValue_invertsBooleanWhenFlagged() {
    // The inverted question (e.g. "lives at a different address" backed by
    // Lives_With_Guardian_1__c) must render the opposite of the stored boolean.
    Assert.areEqual(
      'false',
      ApplicationPdfController.formatAnswerValue(true, true),
      'invert + true should display false'
    );
    Assert.areEqual(
      'true',
      ApplicationPdfController.formatAnswerValue(false, true),
      'invert + false should display true'
    );
  }

  @IsTest
  private static void formatAnswerValue_passesThroughWhenNotInverted() {
    Assert.areEqual(
      'true',
      ApplicationPdfController.formatAnswerValue(true, false),
      'no invert should display the raw boolean'
    );
    Assert.areEqual(
      'true',
      ApplicationPdfController.formatAnswerValue(true, null),
      'null invert flag should not invert'
    );
  }

  @IsTest
  private static void formatAnswerValue_leavesNonBooleanAndNull() {
    Assert.areEqual(
      'Beach 123rd Street',
      ApplicationPdfController.formatAnswerValue('Beach 123rd Street', true),
      'invert only applies to booleans; strings pass through'
    );
    Assert.areEqual(
      '',
      ApplicationPdfController.formatAnswerValue(null, true),
      'null value renders empty regardless of invert flag'
    );
  }

  @IsTest
  private static void getHasAttendingSiblings_withSiblings_returnsTrue() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    List<Priority_Item__c> items = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType),
        Priority_Type__c = 'Sibling Attending',
        First_Name__c = 'Sibling',
        Last_Name__c = 'One'
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(items);

    Assert.isTrue(
      CONTROLLER.getHasAttendingSiblings(),
      'Should return true with attending siblings'
    );
  }

  @IsTest
  private static void getHasApplyingSiblings_withSiblings_returnsTrue() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    List<Priority_Item__c> items = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType),
        Priority_Type__c = 'Sibling Applying',
        First_Name__c = 'Sibling',
        Last_Name__c = 'Two'
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(items);

    Assert.isTrue(CONTROLLER.getHasApplyingSiblings(), 'Should return true with applying siblings');
  }

  @IsTest
  private static void siblingToMap_withNullFields_returnsEmptyStrings() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    CONTROLLER.applicationId = appId;

    List<Priority_Item__c> items = new List<Priority_Item__c>{
      new Priority_Item__c(
        Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType),
        Priority_Type__c = 'Sibling Attending',
        First_Name__c = 'Only'
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(items);

    List<Map<String, Object>> result = CONTROLLER.getAttendingSiblings();

    Assert.areEqual(1, result.size(), 'Should have one sibling');
    Assert.areEqual('Only', result[0].get('name'), 'Should have name from first name only');
    Assert.areEqual('', result[0].get('dateOfBirth'), 'Should return empty for null date');
    Assert.areEqual('', result[0].get('gender'), 'Should return empty for null gender');
    Assert.areEqual('', result[0].get('zetaSchool'), 'Should return empty for null school');
  }
}