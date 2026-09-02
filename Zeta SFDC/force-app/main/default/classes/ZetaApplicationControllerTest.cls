@IsTest(IsParallel=true)
private class ZetaApplicationControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
    ZetaApplicationController.databaseRepo = DATABASE_REPO_MOCK;
    ZetaApplicationController.eventBusRepo = EVENT_BUS_REPO_MOCK;
  }

  // --- getWizardState ---

  @IsTest
  static void getWizardState_withApplication_returnsState() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"Id":"' +
        appId +
        '","Last_Completed_Step__c":3,"Status":"Draft",' +
        '"Application_Timeline__c":"' +
        timelineId +
        '",' +
        '"Application_Timeline__r":{"Id":"' +
        timelineId +
        '",' +
        '"Landing_Content_en__c":"<p>Welcome back</p>",' +
        '"Landing_Content_es__c":"<p>Bienvenido de nuevo</p>"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.areEqual(3, result.get('lastCompletedStep'));
    Assert.areEqual('Draft', result.get('status'));
    Assert.areEqual(false, result.get('isSubmitted'));
    Assert.isTrue(result.containsKey('applicationName'));
    Assert.areEqual('<p>Welcome back</p>', result.get('landingContent'));
  }

  @IsTest
  static void getWizardState_withoutTimeline_omitsLandingContent() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Last_Completed_Step__c = 1,
      Status = 'Draft'
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.isNull(result.get('landingContent'));
  }

  @IsTest
  static void getWizardState_withNullStep_returnsZero() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(Id = appId, Status = 'Draft');

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.areEqual(0, result.get('lastCompletedStep'));
  }

  @IsTest
  static void getWizardState_notFound_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application not found: ' + appId
    );

    try {
      ZetaApplicationController.getWizardState(appId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void getWizardState_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      ZetaApplicationController.getWizardState(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void getWizardState_submittedTimelineOpen_returnsTimelineClosedFalse() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    String futureDate = String.valueOf(Date.today().addDays(30));

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"Id":"' +
        appId +
        '","Last_Completed_Step__c":5,"Status":"Applied",' +
        '"AppliedDate":"' +
        String.valueOf(Date.today()) +
        '",' +
        '"Application_Timeline__c":"' +
        timelineId +
        '",' +
        '"Application_Timeline__r":{"Id":"' +
        timelineId +
        '","ApplicationCloseDate":"' +
        futureDate +
        '"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.areEqual(true, result.get('isSubmitted'));
    Assert.areEqual(false, result.get('timelineClosed'));
  }

  @IsTest
  static void getWizardState_submittedTimelineClosed_returnsTimelineClosedTrue() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    String yesterday = String.valueOf(Date.today().addDays(-1));

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"Id":"' +
        appId +
        '","Last_Completed_Step__c":5,"Status":"Applied",' +
        '"AppliedDate":"' +
        String.valueOf(Date.today()) +
        '",' +
        '"Application_Timeline__c":"' +
        timelineId +
        '",' +
        '"Application_Timeline__r":{"Id":"' +
        timelineId +
        '","ApplicationCloseDate":"' +
        yesterday +
        '"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.areEqual(true, result.get('isSubmitted'));
    Assert.areEqual(true, result.get('timelineClosed'));
  }

  @IsTest
  static void getWizardState_draftTimelineOpen_returnsTimelineClosedFalse() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    String futureDate = String.valueOf(Date.today().addDays(30));

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"Id":"' +
        appId +
        '","Last_Completed_Step__c":2,"Status":"Draft",' +
        '"Application_Timeline__c":"' +
        timelineId +
        '",' +
        '"Application_Timeline__r":{"Id":"' +
        timelineId +
        '","ApplicationCloseDate":"' +
        futureDate +
        '"}}',
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = ZetaApplicationController.getWizardState(appId);

    Assert.areEqual(false, result.get('isSubmitted'));
    Assert.areEqual(false, result.get('timelineClosed'));
  }

  // --- updateWizardStep ---

  @IsTest
  static void updateWizardStep_validStep_callsUpdate() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    ZetaApplicationController.updateWizardStep(appId, 3);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual(3, (Decimal) updated[0].get('Last_Completed_Step__c'));
  }

  @IsTest
  static void updateWizardStep_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      ZetaApplicationController.updateWizardStep(null, 1);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void updateWizardStep_invalidStep_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Step must be between 0 and 5'
    );

    try {
      ZetaApplicationController.updateWizardStep(appId, 6);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  // --- saveSignature ---

  @IsTest
  static void saveSignature_validInput_callsUpdate() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    ZetaApplicationController.saveSignature(appId, 'Test Signer', '2026-04-14');

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual('Test Signer', (String) updated[0].get('Signature_Name__c'));
    Assert.areEqual(Date.valueOf('2026-04-14'), (Date) updated[0].get('Signature_Date__c'));
  }

  @IsTest
  static void saveSignature_nullName_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Signature name is required'
    );

    try {
      ZetaApplicationController.saveSignature(appId, null, '2026-04-14');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void saveSignature_nullDate_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Signature date is required'
    );

    try {
      ZetaApplicationController.saveSignature(appId, 'Test Signer', null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  // --- submitApplication ---

  @IsTest
  static void submitApplication_validDraft_submitsAndPublishes() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // queryWithBinds #1: validation query
    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Status = 'Draft',
      Signature_Name__c = 'Test Signer'
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    // updateSObjects #1: application update
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    // queryWithBinds #2: AcademicInterest draft query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    // eventBusRepo.publish
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    // queryWithBinds #3: name query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Datetime beforeSubmit = Datetime.now();
    Map<String, Object> result = ZetaApplicationController.submitApplication(appId);

    Assert.isTrue(result.containsKey('applicationName'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishSingle());

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Datetime appliedDate = (Datetime) updated[0].get('AppliedDate');
    Assert.isNotNull(appliedDate, 'AppliedDate must be stamped at submission');
    Long offsetMs = Math.abs(appliedDate.getTime() - beforeSubmit.getTime());
    Assert.isTrue(
      offsetMs < 60000L,
      'AppliedDate must be stamped within 60s of submission moment; offsetMs=' + offsetMs
    );
  }

  @IsTest
  static void submitApplication_notSigned_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(Id = appId, Status = 'Draft');
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application must be signed before submission'
    );

    try {
      ZetaApplicationController.submitApplication(appId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void submitApplication_notDraft_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Status = 'Submitted',
      Signature_Name__c = 'Test Signer'
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application must be in Draft status to submit'
    );

    try {
      ZetaApplicationController.submitApplication(appId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void submitApplication_notFound_throws() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application not found: ' + appId
    );

    try {
      ZetaApplicationController.submitApplication(appId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void submitApplication_employeePrimary_stampsGuardianFlag() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // queryWithBinds #1: validation query — self-reports a Primary employee with the
    // guardian lookup already stamped (the async upsert flow runs on earlier saves).
    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Status = 'Draft',
      Signature_Name__c = 'Test Signer',
      Employee_Priority__c = true,
      Employee_Priority_Guardian__c = 'Primary',
      Primary_Guardian__c = guardianId
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    // updateSObjects #1: application update, #2: guardian flag update
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    // queryWithBinds #2: AcademicInterest draft query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    // queryWithBinds #3: name query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    ZetaApplicationController.submitApplication(appId);

    // Two updateSObjects calls: the application, then the guardian Account.
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 2);
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> guardianUpdate = (List<SObject>) calls[1].get('sobjects');
    Assert.areEqual(1, guardianUpdate.size(), 'Guardian update should carry one Account');
    Assert.areEqual(
      guardianId,
      (Id) guardianUpdate[0].get('Id'),
      'Flag must be stamped on the reported Primary guardian'
    );
    Assert.areEqual(
      true,
      (Boolean) guardianUpdate[0].get('Self_Reported_Zeta_Employee__c'),
      'Self_Reported_Zeta_Employee__c must be set true'
    );
  }

  @IsTest
  static void submitApplication_notEmployee_doesNotStampGuardian() {
    DATABASE_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // queryWithBinds #1: validation query — not an employee, so no flag stamping.
    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Status = 'Draft',
      Signature_Name__c = 'Test Signer',
      Employee_Priority__c = false,
      Employee_Priority_Guardian__c = 'Primary',
      Primary_Guardian__c = guardianId
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    ZetaApplicationController.submitApplication(appId);

    // Only the application update — the guardian flag block must be skipped.
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects(), 1);
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> onlyUpdate = (List<SObject>) calls[0].get('sobjects');
    Assert.isInstanceOfType(
      onlyUpdate[0],
      IndividualApplication.class,
      'The single update must be the IndividualApplication, not a guardian Account'
    );
  }

  // --- checkAlreadyEnrolled ---

  @IsTest
  static void checkAlreadyEnrolled_enrolled_returnsTrue() {
    DATABASE_REPO_MOCK.reset();

    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id enrollmentId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<AcademicTermEnrollment>{ new AcademicTermEnrollment(Id = enrollmentId) }
      );

    Map<String, Object> result = ZetaApplicationController.checkAlreadyEnrolled(accountId);

    Assert.isTrue((Boolean) result.get('isEnrolled'));
  }

  @IsTest
  static void checkAlreadyEnrolled_notEnrolled_returnsFalse() {
    DATABASE_REPO_MOCK.reset();

    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicTermEnrollment>());

    Map<String, Object> result = ZetaApplicationController.checkAlreadyEnrolled(accountId);

    Assert.isFalse((Boolean) result.get('isEnrolled'));
  }

  @IsTest
  static void checkAlreadyEnrolled_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student Account Id is required'
    );

    try {
      ZetaApplicationController.checkAlreadyEnrolled(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  static void getTimelineLandingContent_returnsEnglishContent() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<ApplicationTimeline>{
          new ApplicationTimeline(
            Id = timelineId,
            Landing_Content_en__c = '<p>Welcome to SY 25-26</p>',
            Landing_Content_es__c = '<p>Bienvenido al ano escolar 25-26</p>'
          )
        }
      );

    String result = ZetaApplicationController.getTimelineLandingContent(timelineId);

    Assert.areEqual('<p>Welcome to SY 25-26</p>', result);
  }

  @IsTest
  static void getTimelineLandingContent_nullId_returnsNull() {
    DATABASE_REPO_MOCK.reset();

    String result = ZetaApplicationController.getTimelineLandingContent(null);

    Assert.isNull(result);
  }

  @IsTest
  static void getTimelineLandingContent_notFound_returnsNull() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<ApplicationTimeline>());

    String result = ZetaApplicationController.getTimelineLandingContent(timelineId);

    Assert.isNull(result);
  }

  @IsTest
  static void getTimelineLandingContent_blankPrimary_fallsBackToOtherLanguage() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<ApplicationTimeline>{
          new ApplicationTimeline(
            Id = timelineId,
            Landing_Content_en__c = null,
            Landing_Content_es__c = '<p>Solo en espanol</p>'
          )
        }
      );

    String result = ZetaApplicationController.getTimelineLandingContent(timelineId);

    Assert.areEqual('<p>Solo en espanol</p>', result);
  }

  @IsTest
  static void createApplication_noExisting_insertsDraftAndExcludesWithdrawn() {
    DATABASE_REPO_MOCK.reset();

    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id userContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id userAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // queryWithBinds #1: getLoggedInContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = userContactId) });
    // queryWithBinds #2: getAccountIdForContact
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(Id = userContactId, AccountId = userAccountId) });
    // queryWithBinds #3: getPersonContactIdForAccount (PersonContactId is system-writable
    // only — empty list lets studentContactId resolve to null, which is fine because the
    // insert is mocked below.)
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>());
    // queryWithBinds #4: existing-app dedup — empty
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccountId,
      'K',
      null,
      timelineId
    );

    Assert.isTrue(result.containsKey('applicationId'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());

    List<Map<String, Object>> queryCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    );
    Assert.isTrue(queryCalls.size() >= 4, 'Expected at least 4 queryWithBinds calls');
    String dedupQuery = (String) queryCalls[3].get('query');
    Assert.isTrue(
      dedupQuery.contains('Status NOT IN :excludedStatuses'),
      'Dedup query must exclude withdrawn/cancelled statuses: ' + dedupQuery
    );
    Map<String, Object> bindMap = (Map<String, Object>) queryCalls[3].get('bindMap');
    List<String> excluded = (List<String>) bindMap.get('excludedStatuses');
    Assert.isTrue(
      excluded.contains('Withdrawn/Declined'),
      'excludedStatuses must include Withdrawn/Declined'
    );
    Assert.isTrue(excluded.contains('Cancelled'), 'excludedStatuses must include Cancelled');
  }

  @IsTest
  static void createApplication_activeDraftExists_returnsExistingNoInsert() {
    DATABASE_REPO_MOCK.reset();

    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id userContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id userAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id existingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = userContactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(Id = userContactId, AccountId = userAccountId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = existingAppId) });

    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccountId,
      'K',
      null,
      timelineId
    );

    Assert.areEqual(existingAppId, result.get('applicationId'));
    // No verify-zero on insertSObjects — returning the existing Id proves the
    // early-return branch was taken (insert path would have re-generated a different Id),
    // and the mock requires a queued response before `verify(method, 0)` is valid.
  }
}