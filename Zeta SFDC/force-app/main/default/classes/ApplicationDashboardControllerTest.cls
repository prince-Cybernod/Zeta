@IsTest(IsParallel=true)
private class ApplicationDashboardControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    ApplicationDashboardController.databaseRepo = DATABASE_REPO_MOCK;
    ZetaApplicationController.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void getDashboardData_openTimeline_returnsOpenWithApps() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(
        Id = appId,
        Status = 'Draft',
        Grade_Applying_To__c = 'K',
        Last_Completed_Step__c = 2,
        AccountId = accountId
      )
    };

    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(new List<AcademicInterest>());

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Assert.isTrue((Boolean) result.get('isOpen'), 'Timeline should be open');
    Assert.areEqual('SY 2026-27', result.get('timelineName'), 'Should return timeline name');
    Assert.isNull(result.get('landingContent'), 'Open timeline should not have landing content');

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual(1, appList.size(), 'Should return one application');
    Assert.areEqual('Draft', appList[0].get('status'));
    Assert.areEqual('K', appList[0].get('grade'));
    Assert.areEqual(2, appList[0].get('lastStep'));

    List<Map<String, Object>> tlList = (List<Map<String, Object>>) result.get('timelines');
    Assert.isFalse(tlList.isEmpty(), 'Should return available timelines');
  }

  @IsTest
  private static void getDashboardData_appWithTimeline_surfacesTimelineIdAndOpenDate() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    // Application_Timeline__r.* are parent (__r) fields, which can't be set via
    // the SObject constructor — deserialize a JSON shape to populate the parent
    // relationship (the module convention; see ZetaApplicationControllerQueryTest).
    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{' +
        '"Id":"' +
        appId +
        '",' +
        '"Status":"Applied",' +
        '"Grade_Applying_To__c":"1",' +
        '"Application_Timeline__c":"' +
        timelineId +
        '",' +
        '"Application_Timeline__r":{"Name":"SY 2026-27","ApplicationOpenDate":"2026-01-01"}' +
        '}',
      IndividualApplication.class
    );
    List<IndividualApplication> apps = new List<IndividualApplication>{ app };

    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(new List<AcademicInterest>());

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual(1, appList.size(), 'Should return one application');
    Assert.areEqual(
      timelineId,
      appList[0].get('timelineId'),
      'Should surface the timeline lookup Id'
    );
    Assert.areEqual(
      'SY 2026-27',
      appList[0].get('timelineName'),
      'Should surface the timeline name'
    );
    Assert.areEqual(
      Date.newInstance(2026, 1, 1),
      appList[0].get('timelineOpenDate'),
      'Should surface the timeline open date for group ordering'
    );
  }

  // IndividualApplication.Status doesn't move when a school choice gets an
  // offer, so the dashboard must read that off the AcademicInterest rows
  // instead.
  @IsTest
  private static void getDashboardData_appliedWithSeatOffered_surfacesSchoolDecisionStatus() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied')
    };
    List<AcademicInterest> schoolRows = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = appId, Status = 'Seat Offered'),
      new AcademicInterest(IndividualApplicationId = appId, Status = 'Withdrawn/Declined')
    };
    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{ timelines[0] };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(schoolRows);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual('Applied', appList[0].get('status'), 'The raw IA.Status is untouched');
    Assert.areEqual(
      'Seat Offered',
      appList[0].get('schoolDecisionStatus'),
      'A Seat Offered school row must surface even though IA.Status never moved'
    );
  }

  // Offer Rescinded due to Seat Optimization is still actionable, so it
  // behaves like a live offer at the card level, and the priority order
  // picks Seat Accepted over a lower-priority Waitlisted row on the same
  // application.
  @IsTest
  private static void getDashboardData_decisionPriority_offerRescindedAndAcceptedOutrankWaitlisted() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId1, Status = 'Submitted'),
      new IndividualApplication(Id = appId2, Status = 'Submitted')
    };
    List<AcademicInterest> schoolRows = new List<AcademicInterest>{
      new AcademicInterest(
        IndividualApplicationId = appId1,
        Status = 'Offer Rescinded due to Seat Optimization'
      ),
      new AcademicInterest(IndividualApplicationId = appId2, Status = 'Seat Accepted'),
      new AcademicInterest(IndividualApplicationId = appId2, Status = 'Waitlisted')
    };
    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{ timelines[0] };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(schoolRows);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Map<Id, Map<String, Object>> byId = new Map<Id, Map<String, Object>>();
    for (Object o : (List<Object>) result.get('applications')) {
      Map<String, Object> m = (Map<String, Object>) o;
      byId.put((Id) m.get('id'), m);
    }
    Assert.areEqual(
      'Seat Offered',
      byId.get(appId1).get('schoolDecisionStatus'),
      'Offer Rescinded due to Seat Optimization surfaces as an offer at the card level'
    );
    Assert.areEqual(
      'Seat Accepted',
      byId.get(appId2).get('schoolDecisionStatus'),
      'Seat Accepted outranks Waitlisted on the same application'
    );
  }

  // An application with both a current offer and an already-accepted seat
  // must surface the accepted row's school name alongside schoolDecisionStatus,
  // so the dashboard can render both pills.
  @IsTest
  private static void getDashboardData_acceptedAndOffered_surfacesHasAcceptedSeatAndSchoolName() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };
    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied')
    };

    // Parent (__r) fields can't be set via the SObject constructor; deserialize
    // a JSON shape to populate LearningProgram.School__r (the module convention;
    // see getDashboardData_appWithTimeline_surfacesTimelineIdAndOpenDate above).
    AcademicInterest offeredRow = (AcademicInterest) JSON.deserialize(
      '{"IndividualApplicationId":"' + appId + '","Status":"Seat Offered"}',
      AcademicInterest.class
    );
    AcademicInterest acceptedRow = (AcademicInterest) JSON.deserialize(
      '{' +
        '"IndividualApplicationId":"' +
        appId +
        '",' +
        '"Status":"Seat Accepted",' +
        '"LearningProgram":{"School__r":{"Name":"South Bronx","Zeta_School_Name__c":"South Bronx MS"}}' +
        '}',
      AcademicInterest.class
    );
    List<AcademicInterest> schoolRows = new List<AcademicInterest>{ offeredRow, acceptedRow };
    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{ timelines[0] };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(schoolRows);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual(
      'Seat Offered',
      appList[0].get('schoolDecisionStatus'),
      'The current offer still outranks the accepted seat per DECISION_PRIORITY'
    );
    Assert.areEqual(
      true,
      appList[0].get('hasAcceptedSeat'),
      'An accepted row must surface hasAcceptedSeat even though the offer wins the priority race'
    );
    Assert.areEqual(
      'South Bronx MS',
      appList[0].get('acceptedSchoolName'),
      'Zeta_School_Name__c wins over the fallback Name'
    );
  }

  // An accepted-only application (no competing offer) surfaces hasAcceptedSeat
  // and the school name just the same, from a row that has no LearningProgram
  // set at all — the null-safe read must not NPE (SchoolRankingController's
  // own Zeta_School_Name__c-then-Name fallback pattern).
  @IsTest
  private static void getDashboardData_acceptedOnlyNoLearningProgram_surfacesHasAcceptedSeatWithNullName() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied')
    };
    List<AcademicInterest> schoolRows = new List<AcademicInterest>{
      new AcademicInterest(IndividualApplicationId = appId, Status = 'Seat Accepted')
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>())
      .thenReturn(new List<ApplicationTimeline>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(schoolRows);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual(
      true,
      appList[0].get('hasAcceptedSeat'),
      'hasAcceptedSeat must be true even when the accepted row carries no LearningProgram'
    );
    Assert.isNull(
      appList[0].get('acceptedSchoolName'),
      'No LearningProgram means no school name, not an exception'
    );
  }

  // Same accepted-only shape, but with LearningProgram.School__r populated —
  // the name resolves instead of staying null.
  @IsTest
  private static void getDashboardData_acceptedOnlyWithSchool_surfacesAcceptedSchoolName() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied')
    };
    AcademicInterest acceptedRow = (AcademicInterest) JSON.deserialize(
      '{' +
        '"IndividualApplicationId":"' +
        appId +
        '",' +
        '"Status":"Seat Accepted",' +
        '"LearningProgram":{"School__r":{"Name":"Queens Jamaica"}}' +
        '}',
      AcademicInterest.class
    );
    List<AcademicInterest> schoolRows = new List<AcademicInterest>{ acceptedRow };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>())
      .thenReturn(new List<ApplicationTimeline>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps)
      .thenReturn(schoolRows);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.areEqual(true, appList[0].get('hasAcceptedSeat'), 'Should surface hasAcceptedSeat');
    Assert.areEqual(
      'Queens Jamaica',
      appList[0].get('acceptedSchoolName'),
      'Falls back to Name when Zeta_School_Name__c is blank'
    );
  }

  @IsTest
  private static void getDashboardData_closedTimeline_returnsLandingContent() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2025-26',
        ApplicationOpenDate = Date.today().addDays(-60),
        ApplicationCloseDate = Date.today().addDays(-1),
        Landing_Content_en__c = 'Applications are now closed.',
        Landing_Content_es__c = 'Las solicitudes estan cerradas.'
      )
    };

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };

    List<IndividualApplication> apps = new List<IndividualApplication>();

    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Assert.isFalse((Boolean) result.get('isOpen'), 'Closed timeline should not be open');
    Assert.areEqual(
      'Applications are now closed.',
      result.get('landingContent'),
      'Should return English landing content'
    );
  }

  @IsTest
  private static void getDashboardData_noTimeline_returnsClosed() {
    DATABASE_REPO_MOCK.reset();

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = null) };

    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(new List<ApplicationTimeline>())
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(users);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Assert.isFalse((Boolean) result.get('isOpen'), 'No timeline should return closed');
    Assert.areEqual('', result.get('timelineName'), 'Timeline name should be empty');
    Assert.isNull(result.get('landingContent'), 'No timeline means no landing content');

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.isTrue(appList.isEmpty(), 'Should have no applications');
  }

  @IsTest
  private static void getDashboardData_noContact_returnsEmptyApps() {
    DATABASE_REPO_MOCK.reset();

    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    List<ApplicationTimeline> timelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = null) };

    List<ApplicationTimeline> availableTimelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(
        Id = timelineId,
        Name = 'SY 2026-27',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(30)
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.query())
      .thenReturn(timelines)
      .thenReturn(availableTimelines);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(users);

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Assert.isTrue((Boolean) result.get('isOpen'), 'Timeline should be open');

    List<Map<String, Object>> appList = (List<Map<String, Object>>) result.get('applications');
    Assert.isTrue(appList.isEmpty(), 'No contact should mean no applications');
  }

  // Integration test against a real repo + the real Active__c formula. When more than one
  // timeline has an open date, the banner must follow the *active* one, NOT whichever has
  // the latest open date. Fails on the old `ORDER BY ApplicationOpenDate DESC` query, which
  // pulled up an inactive "misc" timeline.
  @IsTest
  private static void getDashboardData_activeAndLaterClosedMisc_picksActive() {
    ApplicationDashboardController.databaseRepo = new SystemModeDatabaseRepo();
    ZetaApplicationController.databaseRepo = new SystemModeDatabaseRepo();

    insert new List<ApplicationTimeline>{
      // Currently active (open now), earlier open date.
      new ApplicationTimeline(
        Name = 'Active SY',
        ApplicationOpenDate = Date.today().addDays(-30),
        ApplicationCloseDate = Date.today().addDays(30)
      ),
      // Inactive "misc": already closed but a LATER open date, so the old query (most
      // recent open date, no Active__c filter) would have grabbed this one.
      new ApplicationTimeline(
        Name = 'Closed Misc',
        ApplicationOpenDate = Date.today().addDays(-5),
        ApplicationCloseDate = Date.today().addDays(-1),
        Landing_Content_en__c = 'Should not be shown'
      )
    };

    Map<String, Object> result = ApplicationDashboardController.getDashboardData();

    Assert.isTrue((Boolean) result.get('isOpen'), 'Active timeline should drive isOpen');
    Assert.areEqual(
      'Active SY',
      result.get('timelineName'),
      'Banner should name the active timeline, not the inactive misc one'
    );
    Assert.isNull(
      result.get('landingContent'),
      'An active timeline shows no closed-state landing content'
    );
  }

  @IsTest
  private static void withdrawApplication_draftApp_succeeds() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Draft', SubmittedByContactId = contactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    Map<String, Object> result = ApplicationDashboardController.withdrawApplication(
      appId,
      'Changed my mind',
      'Other'
    );

    Assert.areEqual(true, result.get('success'), 'Should return success');
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, calls.size(), 'Should call updateSObjects once');
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual('Changed my mind', (String) updated[0].get('Withdrawn_Declined_Reason__c'));
  }

  @IsTest
  private static void withdrawApplication_appliedApp_succeeds() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied', SubmittedByContactId = contactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    Map<String, Object> result = ApplicationDashboardController.withdrawApplication(
      appId,
      'Moved out of district',
      'Other'
    );

    Assert.areEqual(true, result.get('success'), 'Should return success');
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual(
      'Moved out of district',
      (String) updated[0].get('Withdrawn_Declined_Reason__c')
    );
  }

  @IsTest
  private static void withdrawApplication_eligibleApp_succeeds() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Eligible', SubmittedByContactId = contactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    Map<String, Object> result = ApplicationDashboardController.withdrawApplication(
      appId,
      null,
      'Relocation'
    );

    Assert.areEqual(true, result.get('success'), 'Should return success');
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual('Relocation', (String) updated[0].get('Withdrawn_Declined_Reason__c'));
  }

  @IsTest
  private static void withdrawApplication_blankPicklistReason_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    try {
      ApplicationDashboardController.withdrawApplication(appId, null, '   ');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
  }

  @IsTest
  private static void withdrawApplication_otherWithBlankReason_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    try {
      ApplicationDashboardController.withdrawApplication(appId, '   ', 'Other');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
  }

  @IsTest
  private static void withdrawApplication_standardPicklistValue_mirrorsToReason() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Draft', SubmittedByContactId = contactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    ApplicationDashboardController.withdrawApplication(appId, null, 'Relocation');

    List<SObject> updated = (List<SObject>) DATABASE_REPO_MOCK.getCalls(
        DATABASE_REPO_MOCK.method.updateSObjects()
      )[0]
      .get('sobjects');
    Assert.areEqual(
      'Relocation',
      (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'),
      'Picklist field should hold the selected value'
    );
    Assert.areEqual(
      'Relocation',
      (String) updated[0].get('Withdrawn_Declined_Reason__c'),
      'Free text should mirror the picklist value for the validation rule'
    );
  }

  @IsTest
  private static void withdrawApplication_otherValue_usesFreetextForReason() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Applied', SubmittedByContactId = contactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    ApplicationDashboardController.withdrawApplication(appId, 'Custom free text', 'Other');

    List<SObject> updated = (List<SObject>) DATABASE_REPO_MOCK.getCalls(
        DATABASE_REPO_MOCK.method.updateSObjects()
      )[0]
      .get('sobjects');
    Assert.areEqual(
      'Other',
      (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'),
      'Picklist field should hold Other'
    );
    Assert.areEqual(
      'Custom free text',
      (String) updated[0].get('Withdrawn_Declined_Reason__c'),
      'Free text should hold the custom reason when Other is chosen'
    );
  }

  @IsTest
  private static void withdrawApplication_wrongUser_throws() {
    DATABASE_REPO_MOCK.reset();

    Id loggedInContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id otherContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{
      new User(Id = UserInfo.getUserId(), ContactId = loggedInContactId)
    };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Draft', SubmittedByContactId = otherContactId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      ApplicationDashboardController.withdrawApplication(appId, 'Should fail', 'Other');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Should not update when user mismatch'
    );
  }

  @IsTest
  private static void withdrawApplication_invalidStatus_throws() {
    DATABASE_REPO_MOCK.reset();

    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    List<User> users = new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) };
    List<IndividualApplication> apps = new List<IndividualApplication>{
      new IndividualApplication(
        Id = appId,
        Status = 'Withdrawn/Declined',
        SubmittedByContactId = contactId
      )
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(users)
      .thenReturn(apps);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      ApplicationDashboardController.withdrawApplication(appId, 'Already withdrawn', 'Other');
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Should not update when status is invalid'
    );
  }
}