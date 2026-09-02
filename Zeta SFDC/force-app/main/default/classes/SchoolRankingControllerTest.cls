@IsTest(IsParallel=true)
private class SchoolRankingControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
    SchoolRankingController.databaseRepo = DATABASE_REPO_MOCK;
    SchoolRankingController.eventBusRepo = EVENT_BUS_REPO_MOCK;
  }

  private static Id publishedApplicationId() {
    List<Map<String, Object>> calls = EVENT_BUS_REPO_MOCK.getCalls(
      EVENT_BUS_REPO_MOCK.method.publishSingle()
    );
    Assert.areEqual(1, calls.size(), 'Expected exactly one regeneration event');
    Application_Submitted_Event__e event = (Application_Submitted_Event__e) calls[0].get('event');
    return (Id) event.Application_Id__c;
  }

  @IsTest
  private static void getRankedSchools_returnsAllSchoolsRegardlessOfStatus() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai3 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> interests = new List<AcademicInterest>{
      new AcademicInterest(Id = ai1, School_Rank__c = 1),
      new AcademicInterest(Id = ai2, School_Rank__c = 2),
      new AcademicInterest(Id = ai3, School_Rank__c = 3)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(interests);

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.areEqual(
      3,
      result.size(),
      'Should return all schools regardless of AcademicInterest.Status'
    );
    Assert.areEqual(ai1, (Id) result[0].get('academicInterestId'));
    Assert.areEqual(1, (Decimal) result[0].get('rank'));
  }

  @IsTest
  private static void getRankedSchools_singleSchool_returns() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ new AcademicInterest(Id = ai, School_Rank__c = 1) });

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.areEqual(1, result.size(), 'Single school should still be returned');
    Assert.areEqual(ai, (Id) result[0].get('academicInterestId'));
  }

  @IsTest
  private static void getRankedSchools_emptyResult_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.isTrue(result.isEmpty(), 'No interests should return empty list');
  }

  @IsTest
  private static void getRankedSchools_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    try {
      SchoolRankingController.getRankedSchools(null);
      Assert.fail('Expected exception for null Id');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
  }

  @IsTest
  private static void saveRankings_persistsRanks() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json =
      '[{"academicInterestId":"' +
      ai1 +
      '","rank":1},' +
      '{"academicInterestId":"' +
      ai2 +
      '","rank":2}]';

    SchoolRankingController.saveRankings(applicationId, json);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, calls.size(), 'Should call updateSObjects once');
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual(2, updated.size(), 'Should update both records');
    Assert.areEqual(1, (Decimal) updated[0].get('School_Rank__c'));
    Assert.areEqual(2, (Decimal) updated[1].get('School_Rank__c'));
  }

  @IsTest
  private static void saveRankings_emptyList_skipsUpdate() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolRankingController.saveRankings(applicationId, '[]');

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Empty rankings should not trigger an update'
    );
  }

  @IsTest
  private static void saveRankings_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    try {
      SchoolRankingController.saveRankings(null, '[]');
      Assert.fail('Expected exception for null Id');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  private static void saveRankings_blankJson_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    try {
      SchoolRankingController.saveRankings(applicationId, '');
      Assert.fail('Expected exception for blank JSON');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  private static void saveRankings_draftApp_doesNotRequestRegeneration() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          // AppliedDate null -> draft; no PDF exists yet, so nothing to regenerate
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json = '[{"academicInterestId":"' + ai + '","rank":1}]';

    SchoolRankingController.saveRankings(applicationId, json);

    EVENT_BUS_REPO_MOCK.never(EVENT_BUS_REPO_MOCK.method.publishSingle());
  }

  @IsTest
  private static void saveRankings_submittedApp_publishesRegenerationEvent() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = applicationId,
            Status = 'Applied',
            AppliedDate = Datetime.now()
          )
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    String json = '[{"academicInterestId":"' + ai + '","rank":1}]';

    Integer queueablesBefore = Limits.getQueueableJobs();
    SchoolRankingController.saveRankings(applicationId, json);

    Assert.areEqual(
      applicationId,
      publishedApplicationId(),
      'A submitted app must request regeneration for its own Id'
    );
    Assert.areEqual(
      queueablesBefore,
      Limits.getQueueableJobs(),
      'Regeneration must not run in the caller context: an external user cannot ' +
      'create the File, so the work has to reach the automated process user'
    );
  }

  @IsTest
  private static void saveRankings_withdrawnApp_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Withdrawn/Declined')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json = '[{"academicInterestId":"' + ai + '","rank":1}]';

    try {
      SchoolRankingController.saveRankings(applicationId, json);
      Assert.fail('Expected exception for withdrawn application');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Withdrawn application should not trigger a rankings update'
    );
  }

  // --- withdrawSchoolApplication --------------------------------------------
  // withdrawSchoolApplication queries the AcademicInterest FIRST, then the User
  // (getLoggedInContactId) — the reverse of ApplicationDashboardController — so
  // the queryWithBinds mock returns are enqueued interests-then-users. The parent
  // IndividualApplication is a relationship field that the SObject constructor
  // can't set, so we deserialize a JSON shape (the module convention; see
  // ApplicationDashboardControllerTest / ZetaApplicationControllerQueryTest).
  // AppliedDate is left null (draft) unless a test needs the regeneration branch,
  // which buildSubmittedInterest supplies.

  private static AcademicInterest buildInterest(Id aiId, Id appId, String status, Id submittedBy) {
    return buildInterest(aiId, appId, status, submittedBy, null);
  }

  private static AcademicInterest buildInterest(
    Id aiId,
    Id appId,
    String status,
    Id submittedBy,
    Datetime appliedDate
  ) {
    String applied = appliedDate == null
      ? ''
      : ',"AppliedDate":"' + appliedDate.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') + '"';
    return (AcademicInterest) JSON.deserialize(
      '{' +
        '"Id":"' +
        aiId +
        '","Status":"' +
        status +
        '","IndividualApplicationId":"' +
        appId +
        '","IndividualApplication":{"Id":"' +
        appId +
        '","SubmittedByContactId":"' +
        submittedBy +
        '"' +
        applied +
        '}}',
      AcademicInterest.class
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_standardReason_withdrawsAndClearsFreeText() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai = buildInterest(aiId, appId, 'Applied', contactId);
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolRankingController.withdrawSchoolApplication(aiId, 'Relocation', null);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, calls.size(), 'Should call updateSObjects once');
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should update the single AcademicInterest');
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual(
      'Relocation',
      (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'),
      'Should record the selected picklist reason'
    );
    Assert.isNull(
      updated[0].get('Declined_Withdrawn_Reason__c'),
      'Free-text detail must be blank for a non-Other reason'
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_otherReason_capturesFreeText() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai = buildInterest(aiId, appId, 'Applied', contactId);
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolRankingController.withdrawSchoolApplication(aiId, 'Other', 'we moved');

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual('Other', (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'));
    Assert.areEqual(
      'we moved',
      (String) updated[0].get('Declined_Withdrawn_Reason__c'),
      'Other should persist the free-text detail'
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_wrongOwner_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id loggedInContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id otherContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai = buildInterest(aiId, appId, 'Applied', otherContactId);
    List<User> users = new List<User>{
      new User(Id = UserInfo.getUserId(), ContactId = loggedInContactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolRankingController.withdrawSchoolApplication(aiId, 'Relocation', null);
      Assert.fail('Expected an exception when withdrawing another family\'s school');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('your own'),
        'Ownership failure should say the caller can only withdraw their own: ' + e.getMessage()
      );
    }

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'A failed ownership check must not update the record'
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_alreadyWithdrawn_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // Owned by the caller (ownership passes) but already withdrawn, so the
    // idempotency guard — not the ownership check — is what fires.
    AcademicInterest ai = buildInterest(aiId, appId, 'Withdrawn/Declined', contactId);
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolRankingController.withdrawSchoolApplication(aiId, 'Relocation', null);
      Assert.fail('Expected an exception when re-withdrawing a withdrawn school');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('already been withdrawn'),
        'Idempotency guard should say the school was already withdrawn: ' + e.getMessage()
      );
    }

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Re-withdrawing must not update the record'
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_blankReason_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // checkNotBlank fires before any query, so no repo mocking is needed.
    try {
      SchoolRankingController.withdrawSchoolApplication(aiId, '', null);
      Assert.fail('Expected an exception for a blank withdrawal reason');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('required'),
        'A blank reason should report that a reason is required: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void withdrawSchoolApplication_submittedApp_publishesRegenerationEvent() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai = buildInterest(aiId, appId, 'Applied', contactId, Datetime.now());
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    Integer queueablesBefore = Limits.getQueueableJobs();
    SchoolRankingController.withdrawSchoolApplication(aiId, 'Relocation', null);

    Assert.areEqual(
      appId,
      publishedApplicationId(),
      'Withdrawing a school on a submitted app must request regeneration for the parent app'
    );
    Assert.areEqual(
      queueablesBefore,
      Limits.getQueueableJobs(),
      'Regeneration must not run in the caller context: an external user cannot ' +
      'create the File, so the work has to reach the automated process user'
    );
  }

  @IsTest
  private static void withdrawSchoolApplication_draftApp_doesNotRequestRegeneration() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AcademicInterest ai = buildInterest(aiId, appId, 'Applied', contactId);
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(users);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolRankingController.withdrawSchoolApplication(aiId, 'Relocation', null);

    EVENT_BUS_REPO_MOCK.never(EVENT_BUS_REPO_MOCK.method.publishSingle());
  }
}