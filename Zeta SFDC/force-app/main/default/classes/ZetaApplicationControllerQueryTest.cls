@IsTest(IsParallel=true)
private class ZetaApplicationControllerQueryTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    ZetaApplicationController.databaseRepo = DATABASE_REPO_MOCK;
  }

  // checkDuplicateBeforeCreate
  @IsTest
  static void checkDuplicateBeforeCreate_withTimelineAndDup_returnsTrue() {
    DATABASE_REPO_MOCK.reset();
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });
    Map<String, Object> result = ZetaApplicationController.checkDuplicateBeforeCreate(
      accountId,
      timelineId
    );
    Assert.isTrue((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateBeforeCreate_withTimelineNoDup_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.checkDuplicateBeforeCreate(
      accountId,
      timelineId
    );
    Assert.isFalse((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateBeforeCreate_nullTimeline_findsActive() {
    DATABASE_REPO_MOCK.reset();
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    // query() for findActiveTimelineId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>{ new ApplicationTimeline(Id = timelineId) });
    // queryWithBinds for dup check
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.checkDuplicateBeforeCreate(
      accountId,
      null
    );
    Assert.isFalse((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateBeforeCreate_noActiveTimeline_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>());
    Map<String, Object> result = ZetaApplicationController.checkDuplicateBeforeCreate(
      accountId,
      null
    );
    Assert.isFalse((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateBeforeCreate_nullAccountId_throws() {
    DATABASE_REPO_MOCK.reset();
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student Account Id is required'
    );
    try {
      ZetaApplicationController.checkDuplicateBeforeCreate(null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  // checkDuplicateApplication
  @IsTest
  static void checkDuplicateApplication_hasDup_returnsTrue() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    // queryWithBinds #1: current app
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = accountId,
            Application_Timeline__c = timelineId
          )
        }
      );
    // queryWithBinds #2: dup found
    Id dupId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = dupId) });
    Map<String, Object> result = ZetaApplicationController.checkDuplicateApplication(appId);
    Assert.isTrue((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateApplication_noDup_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = accountId,
            Application_Timeline__c = timelineId
          )
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.checkDuplicateApplication(appId);
    Assert.isFalse((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateApplication_notFound_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.checkDuplicateApplication(appId);
    Assert.isFalse((Boolean) result.get('isDuplicate'));
  }

  @IsTest
  static void checkDuplicateApplication_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );
    try {
      ZetaApplicationController.checkDuplicateApplication(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  // getSubmissionWarnings
  @IsTest
  static void getSubmissionWarnings_withWarnings_returnsBoth() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          (IndividualApplication) JSON.deserialize(
            '{"Id":"' + appId + '","Age_Inconsistency_Flag_c__c":true,"Outside_of_NY__c":true}',
            IndividualApplication.class
          )
        }
      );
    Map<String, Object> result = ZetaApplicationController.getSubmissionWarnings(appId);
    Assert.isTrue((Boolean) result.get('hasAgeWarning'));
    Assert.isTrue((Boolean) result.get('hasResidencyWarning'));
  }

  @IsTest
  static void getSubmissionWarnings_noWarnings_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });
    Map<String, Object> result = ZetaApplicationController.getSubmissionWarnings(appId);
    Assert.isFalse((Boolean) result.get('hasAgeWarning'));
    Assert.isFalse((Boolean) result.get('hasResidencyWarning'));
  }

  @IsTest
  static void getSubmissionWarnings_notFound_returnsFalse() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.getSubmissionWarnings(appId);
    Assert.isFalse((Boolean) result.get('hasAgeWarning'));
    Assert.isFalse((Boolean) result.get('hasResidencyWarning'));
  }

  // checkEnrollmentStatus
  @IsTest
  static void checkEnrollmentStatus_openTimeline_returnsOpen() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(
        new List<ApplicationTimeline>{
          new ApplicationTimeline(
            ApplicationOpenDate = Date.today().addDays(-10),
            ApplicationCloseDate = Date.today().addDays(10)
          )
        }
      );
    Map<String, Object> result = ZetaApplicationController.checkEnrollmentStatus();
    Assert.isTrue((Boolean) result.get('isOpen'));
  }

  @IsTest
  static void checkEnrollmentStatus_closedTimeline_returnsClosedWithContent() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(
        new List<ApplicationTimeline>{
          new ApplicationTimeline(
            ApplicationOpenDate = Date.today().addDays(-30),
            ApplicationCloseDate = Date.today().addDays(-1),
            Landing_Content_en__c = 'Enrollment closed'
          )
        }
      );
    Map<String, Object> result = ZetaApplicationController.checkEnrollmentStatus();
    Assert.isFalse((Boolean) result.get('isOpen'));
    Assert.areEqual('Enrollment closed', result.get('landingContent'));
  }

  @IsTest
  static void checkEnrollmentStatus_noTimeline_returnsClosed() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>());
    Map<String, Object> result = ZetaApplicationController.checkEnrollmentStatus();
    Assert.isFalse((Boolean) result.get('isOpen'));
    Assert.isNull(result.get('landingContent'));
  }

  // Integration test against a real repo + the real Active__c formula. The enrollment check
  // (findActiveTimeline) must follow the *active* timeline, NOT whichever has the latest open
  // date. Fails on the old `ORDER BY ApplicationOpenDate DESC` query, which pulled up an
  // inactive "misc" timeline. Mirrors the dashboard fix.
  @IsTest
  static void checkEnrollmentStatus_activeAndLaterClosedMisc_picksActive() {
    ZetaApplicationController.databaseRepo = new SystemModeDatabaseRepo();

    insert new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Name = 'Active SY',
        ApplicationOpenDate = Date.today().addDays(-30),
        ApplicationCloseDate = Date.today().addDays(30)
      ),
      // Inactive "misc": already closed but a LATER open date.
      new ApplicationTimeline(
        Name = 'Closed Misc',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(-1),
        Landing_Content_en__c = 'Should not be shown'
      )
    };

    Map<String, Object> result = ZetaApplicationController.checkEnrollmentStatus();

    Assert.isTrue((Boolean) result.get('isOpen'), 'Active timeline should drive isOpen');
    Assert.isNull(
      result.get('landingContent'),
      'An active timeline shows no closed-state landing content'
    );
  }

  // getAvailableTimelines
  @IsTest
  static void getAvailableTimelines_returnsTimelines() {
    DATABASE_REPO_MOCK.reset();
    Id tlId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(
        new List<ApplicationTimeline>{
          new ApplicationTimeline(
            Id = tlId,
            Name = '2026-2027',
            ApplicationOpenDate = Date.today().addDays(-5),
            ApplicationCloseDate = Date.today().addDays(30)
          )
        }
      );
    List<Map<String, Object>> result = ZetaApplicationController.getAvailableTimelines();
    Assert.areEqual(1, result.size());
    Assert.areEqual('2026-2027', result[0].get('name'));
    Assert.isTrue((Boolean) result[0].get('isOpen'));
  }

  @IsTest
  static void getAvailableTimelines_empty_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>());
    List<Map<String, Object>> result = ZetaApplicationController.getAvailableTimelines();
    Assert.isTrue(result.isEmpty());
  }

  // findDraftApplication
  @IsTest
  static void findDraftApplication_withTimeline_returnsDraft() {
    DATABASE_REPO_MOCK.reset();
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    // queryWithBinds #1: getLoggedInContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    // queryWithBinds #2: draft query
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });
    Map<String, Object> result = ZetaApplicationController.findDraftApplication(timelineId);
    Assert.areEqual(appId, result.get('applicationId'));
  }

  @IsTest
  static void findDraftApplication_noContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() }); // ContactId null
    Map<String, Object> result = ZetaApplicationController.findDraftApplication(timelineId);
    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  static void findDraftApplication_nullTimeline_findsActive() {
    DATABASE_REPO_MOCK.reset();
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // queryWithBinds #1: getLoggedInContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    // query(): findActiveTimelineId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>{ new ApplicationTimeline(Id = timelineId) });
    // queryWithBinds #2: draft query - no draft
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    Map<String, Object> result = ZetaApplicationController.findDraftApplication(null);
    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  static void findDraftApplication_nullTimelineNoActive_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>());
    Map<String, Object> result = ZetaApplicationController.findDraftApplication(null);
    Assert.isTrue(result.isEmpty());
  }

  // createApplication
  @IsTest
  static void createApplication_newApp_insertsAndReturnsId() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id guardianAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // queryWithBinds #1: getLoggedInContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    // queryWithBinds #2: getAccountIdForContact
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(AccountId = guardianAccId) });
    // queryWithBinds #3: getPersonContactIdForAccount
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + studentContactId + '"}',
            Account.class
          )
        }
      );
    // queryWithBinds #4: existing check - none
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    // insertSObjects
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();
    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccId,
      'K',
      '1st',
      timelineId
    );
    Assert.isTrue(result.containsKey('applicationId'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> inserted = (List<SObject>) calls[0].get('sobjects');
    IndividualApplication app = (IndividualApplication) inserted[0];
    Assert.areEqual(studentContactId, app.ContactId, 'ContactId should be student PersonContactId');
    Assert.areEqual(contactId, app.SubmittedByContactId, 'SubmittedByContactId should be parent');
    Assert.areEqual(studentAccId, app.AccountId, 'AccountId should be student account');
    Assert.areEqual('Draft', (String) app.get('Status'));
    Assert.areEqual('K', (String) app.get('Grade_Applying_To__c'));
    Assert.areEqual('1st', (String) app.get('Current_Grade__c'));
  }

  @IsTest
  static void createApplication_existingDraft_returnsExistingId() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id existingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(AccountId = studentAccId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ new Account() });
    // existing check - found
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = existingAppId) });
    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccId,
      'K',
      null,
      timelineId
    );
    Assert.areEqual(existingAppId, result.get('applicationId'));
  }

  @IsTest
  static void createApplication_nullTimeline_findsActive() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(AccountId = studentAccId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ new Account() });
    // query() for findActiveTimelineId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>{ new ApplicationTimeline(Id = timelineId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();
    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccId,
      'K',
      null,
      null
    );
    Assert.isTrue(result.containsKey('applicationId'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  static void createApplication_noContact_throws() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() }); // ContactId null
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Logged-in user must have a Contact'
    );
    try {
      ZetaApplicationController.createApplication(studentAccId, 'K', null, timelineId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  static void createApplication_nullStudentAccountId_throws() {
    DATABASE_REPO_MOCK.reset();
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student Account Id is required'
    );
    try {
      ZetaApplicationController.createApplication(null, 'K', null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  static void createApplication_nullGrade_insertsWithoutGrade() {
    // Grade is optional at creation now: the draft is created the moment a
    // student is selected (so the step-1 address widget has a record to bind
    // to) and the grade is persisted later via selectStudent. A null grade must
    // insert a Draft with Grade_Applying_To__c left unset rather than throw.
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id guardianAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // getLoggedInContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    // getAccountIdForContact
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(AccountId = guardianAccId) });
    // getPersonContactIdForAccount
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + studentContactId + '"}',
            Account.class
          )
        }
      );
    // existing draft check - none
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Map<String, Object> result = ZetaApplicationController.createApplication(
      studentAccId,
      null,
      null,
      timelineId
    );

    Assert.isTrue(result.containsKey('applicationId'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    IndividualApplication app = (IndividualApplication) ((List<SObject>) calls[0]
      .get('sobjects'))[0];
    Assert.areEqual('Draft', (String) app.get('Status'));
    Assert.areEqual(studentAccId, app.AccountId, 'AccountId should be the student account');
    Assert.areEqual(
      null,
      app.get('Grade_Applying_To__c'),
      'Grade_Applying_To__c should be unset when no grade is provided'
    );
  }

  @IsTest
  static void createApplication_noActiveTimeline_throws() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(AccountId = studentAccId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ new Account() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>());
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'No active application timeline found'
    );
    try {
      ZetaApplicationController.createApplication(studentAccId, 'K', null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }
}