public without sharing class ZetaApplicationController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @TestVisible
  private static EventBusRepo eventBusRepo = new EventBusRepoImpl();
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getWizardState(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Last_Completed_Step__c, Status, Name, AppliedDate, Account.Name,' +
      ' Application_Timeline__r.ApplicationCloseDate,' +
      ' Application_Timeline__r.Landing_Content_en__c,' +
      ' Application_Timeline__r.Landing_Content_es__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(!apps.isEmpty(), 'Application not found: ' + applicationId);

    Integer lastStep = apps[0].Last_Completed_Step__c != null
      ? Integer.valueOf(apps[0].Last_Completed_Step__c)
      : 0;

    Boolean timelineClosed = false;
    if (apps[0].Application_Timeline__r != null) {
      Date closeDate = apps[0].Application_Timeline__r.ApplicationCloseDate;
      timelineClosed = closeDate != null && closeDate < Date.today();
    }

    Map<String, Object> result = new Map<String, Object>();
    result.put('lastCompletedStep', lastStep);
    result.put('status', apps[0].Status);
    result.put('isSubmitted', apps[0].AppliedDate != null);
    result.put('timelineClosed', timelineClosed);
    result.put('applicationName', apps[0].Name);
    if (apps[0].Account != null) {
      result.put('studentName', apps[0].Account.Name);
    }
    if (apps[0].Application_Timeline__r != null) {
      result.put(
        'landingContent',
        selectLandingContent(
          apps[0].Application_Timeline__r.Landing_Content_en__c,
          apps[0].Application_Timeline__r.Landing_Content_es__c
        )
      );
    }
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static String getTimelineLandingContent(Id timelineId) {
    if (timelineId == null) {
      return null;
    }
    String query =
      'SELECT Landing_Content_en__c, Landing_Content_es__c' +
      ' FROM ApplicationTimeline WHERE Id = :timelineId LIMIT 1';
    List<ApplicationTimeline> tls = (List<ApplicationTimeline>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'timelineId' => timelineId }
    );
    if (tls.isEmpty()) {
      return null;
    }
    return selectLandingContent(tls[0].Landing_Content_en__c, tls[0].Landing_Content_es__c);
  }

  @AuraEnabled
  public static void updateWizardStep(Id applicationId, Integer step) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotNull(step, 'Step is required');
    Preconditions.checkArgument(step >= 0 && step <= 5, 'Step must be between 0 and 5');

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('Id', applicationId);
    fields.put('Last_Completed_Step__c', step);

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.updateSObjects(new List<IndividualApplication>{ app });
  }

  @AuraEnabled
  public static void saveSignature(Id applicationId, String name, String signatureDate) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(name, 'Signature name is required');
    Preconditions.checkNotBlank(signatureDate, 'Signature date is required');

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('Id', applicationId);
    fields.put('Signature_Name__c', name);
    fields.put('Signature_Date__c', Date.valueOf(signatureDate));

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.updateSObjects(new List<IndividualApplication>{ app });
  }

  @AuraEnabled
  public static Map<String, Object> submitApplication(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String validationQuery =
      'SELECT Status, Signature_Name__c, AppliedDate,' +
      ' Employee_Priority__c, Employee_Priority_Guardian__c,' +
      ' Primary_Guardian__c, Secondary_Guardian__c' +
      ' FROM IndividualApplication' +
      ' WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      validationQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(!apps.isEmpty(), 'Application not found: ' + applicationId);
    Preconditions.checkArgument(
      apps[0].AppliedDate == null,
      'Application has already been submitted'
    );
    Preconditions.checkArgument(
      String.isNotBlank(apps[0].Signature_Name__c),
      'Application must be signed before submission'
    );
    Preconditions.checkArgument(
      apps[0].Status == 'Draft',
      'Application must be in Draft status to submit'
    );

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('Id', applicationId);
    fields.put('Status', 'Applied');
    fields.put('AppliedDate', Datetime.now());
    fields.put('Last_Completed_Step__c', 5);

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.updateSObjects(new List<IndividualApplication>{ app });

    // Stamp Self-Reported Zeta Employee on the reported guardian, in-transaction.
    // The async upsert-guardian flow can't reliably set this (TEXT() of an auto-stored
    // Get picklist evaluates blank at runtime), so we set it here where Primary_Guardian__c /
    // Secondary_Guardian__c are already linked. Set-true-only: never clear a prior value.
    if (apps[0].Employee_Priority__c == true) {
      Id employeeGuardianId = null;
      String reported = apps[0].Employee_Priority_Guardian__c;
      if (reported == 'Primary') {
        employeeGuardianId = apps[0].Primary_Guardian__c;
      } else if (reported == 'Secondary') {
        employeeGuardianId = apps[0].Secondary_Guardian__c;
      }
      if (employeeGuardianId != null) {
        Account guardian = new Account(
          Id = employeeGuardianId,
          Self_Reported_Zeta_Employee__c = true
        );
        databaseRepo.updateSObjects(new List<Account>{ guardian });
      }
    }

    String aiQuery =
      'SELECT Id FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId AND Status = :draftStatus';
    List<AcademicInterest> draftInterests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      aiQuery,
      new Map<String, Object>{ 'applicationId' => applicationId, 'draftStatus' => 'Draft' }
    );
    if (!draftInterests.isEmpty()) {
      List<AcademicInterest> toUpdate = new List<AcademicInterest>();
      for (AcademicInterest ai : draftInterests) {
        Map<String, Object> aiFields = new Map<String, Object>();
        aiFields.put('Id', ai.Id);
        aiFields.put('Status', 'Applied');
        toUpdate.add(
          (AcademicInterest) JSON.deserialize(JSON.serialize(aiFields), AcademicInterest.class)
        );
      }
      databaseRepo.updateSObjects(toUpdate);
    }

    eventBusRepo.publish(new Application_Submitted_Event__e(Application_Id__c = applicationId));

    String nameQuery = 'SELECT Name FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> updated = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      nameQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    return new Map<String, Object>{ 'applicationName' => updated[0].Name };
  }

  @AuraEnabled
  public static Map<String, Object> checkAlreadyEnrolled(Id studentAccountId) {
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');

    List<String> excludedStatuses = new List<String>{ 'Rescinded', 'Declined/Withdrawn' };
    String query =
      'SELECT Id FROM AcademicTermEnrollment' +
      ' WHERE LearnerAccountId = :studentAccountId' +
      ' AND EnrollmentStatus NOT IN :excludedStatuses' +
      ' LIMIT 1';
    List<AcademicTermEnrollment> enrollments = (List<AcademicTermEnrollment>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'studentAccountId' => studentAccountId,
        'excludedStatuses' => excludedStatuses
      }
    );

    return new Map<String, Object>{ 'isEnrolled' => !enrollments.isEmpty() };
  }

  @AuraEnabled
  public static Map<String, Object> checkDuplicateBeforeCreate(Id studentAccountId, Id timelineId) {
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');

    if (timelineId == null) {
      timelineId = findActiveTimelineId();
    }
    if (timelineId == null) {
      return new Map<String, Object>{ 'isDuplicate' => false };
    }

    String dupQuery =
      'SELECT Id FROM IndividualApplication' +
      ' WHERE AccountId = :studentAccountId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND AppliedDate != NULL' +
      ' LIMIT 1';
    List<IndividualApplication> dups = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      dupQuery,
      new Map<String, Object>{ 'studentAccountId' => studentAccountId, 'timelineId' => timelineId }
    );

    return new Map<String, Object>{ 'isDuplicate' => !dups.isEmpty() };
  }

  @AuraEnabled
  public static Map<String, Object> checkDuplicateApplication(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String appQuery =
      'SELECT AccountId, Application_Timeline__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    if (apps.isEmpty()) {
      return new Map<String, Object>{ 'isDuplicate' => false };
    }

    IndividualApplication current = apps[0];
    Id accountId = current.AccountId;
    Id timelineId = current.Application_Timeline__c;

    String dupQuery =
      'SELECT Id FROM IndividualApplication' +
      ' WHERE AccountId = :accountId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND AppliedDate != NULL' +
      ' AND Id != :applicationId' +
      ' LIMIT 1';
    List<IndividualApplication> dups = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      dupQuery,
      new Map<String, Object>{
        'accountId' => accountId,
        'timelineId' => timelineId,
        'applicationId' => applicationId
      }
    );

    return new Map<String, Object>{ 'isDuplicate' => !dups.isEmpty() };
  }

  @AuraEnabled
  public static Map<String, Object> getSubmissionWarnings(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Age_Inconsistency_Flag_c__c, Outside_of_NY__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    Map<String, Object> result = new Map<String, Object>();
    if (apps.isEmpty()) {
      result.put('hasAgeWarning', false);
      result.put('hasResidencyWarning', false);
      return result;
    }

    IndividualApplication app = apps[0];
    result.put('hasAgeWarning', app.Age_Inconsistency_Flag_c__c == true);
    result.put('hasResidencyWarning', app.Outside_of_NY__c == true);
    return result;
  }

  @AuraEnabled
  public static Map<String, Object> checkEnrollmentStatus() {
    ApplicationTimeline tl = findActiveTimeline();

    Map<String, Object> result = new Map<String, Object>();
    if (tl == null) {
      result.put('isOpen', false);
      result.put('landingContent', null);
      return result;
    }

    Date today = Date.today();
    Boolean isOpen =
      tl.ApplicationOpenDate != null &&
      tl.ApplicationOpenDate <= today &&
      (tl.ApplicationCloseDate == null ||
      tl.ApplicationCloseDate >= today);

    result.put('isOpen', isOpen);
    if (!isOpen) {
      result.put(
        'landingContent',
        selectLandingContent(tl.Landing_Content_en__c, tl.Landing_Content_es__c)
      );
    }
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getAvailableTimelines() {
    String query =
      'SELECT Id, Name, ApplicationOpenDate, ApplicationCloseDate' +
      ' FROM ApplicationTimeline' +
      ' WHERE Active__c = true' +
      ' ORDER BY ApplicationOpenDate DESC';
    List<ApplicationTimeline> timelines = (List<ApplicationTimeline>) databaseRepo.query(query);

    Date today = Date.today();
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (ApplicationTimeline tl : timelines) {
      Boolean isOpen =
        tl.ApplicationOpenDate != null &&
        tl.ApplicationOpenDate <= today &&
        (tl.ApplicationCloseDate == null ||
        tl.ApplicationCloseDate >= today);

      Map<String, Object> tlMap = new Map<String, Object>();
      tlMap.put('id', tl.Id);
      tlMap.put('name', tl.Name);
      tlMap.put('openDate', tl.ApplicationOpenDate);
      tlMap.put('closeDate', tl.ApplicationCloseDate);
      tlMap.put('isOpen', isOpen);
      result.add(tlMap);
    }
    return result;
  }

  @AuraEnabled
  public static Map<String, Object> findDraftApplication(Id timelineId) {
    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      return new Map<String, Object>();
    }

    if (timelineId == null) {
      timelineId = findActiveTimelineId();
    }
    if (timelineId == null) {
      return new Map<String, Object>();
    }

    List<String> excludedStatuses = new List<String>{ 'Cancelled', 'Withdrawn/Declined' };
    String query =
      'SELECT Id, Last_Completed_Step__c' +
      ' FROM IndividualApplication' +
      ' WHERE SubmittedByContactId = :contactId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND Status NOT IN :excludedStatuses' +
      ' AND AppliedDate = NULL' +
      ' ORDER BY CreatedDate DESC' +
      ' LIMIT 1';
    List<IndividualApplication> drafts = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'contactId' => contactId,
        'timelineId' => timelineId,
        'excludedStatuses' => excludedStatuses
      }
    );

    if (drafts.isEmpty()) {
      return new Map<String, Object>();
    }

    return new Map<String, Object>{ 'applicationId' => drafts[0].Id };
  }

  @AuraEnabled
  public static Map<String, Object> createApplication(
    Id studentAccountId,
    String grade,
    String currentGrade,
    Id timelineId
  ) {
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');
    // Grade is optional at creation: the draft is created as soon as a student
    // is selected (so the step-1 address widget has a record to bind to), and
    // the grade is persisted later via selectStudent when the parent picks it.

    Id contactId = getLoggedInContactId();
    Preconditions.checkNotNull(contactId, 'Logged-in user must have a Contact');

    Id guardianAccountId = ApplicationContext.accountIdForContact(databaseRepo, contactId);
    Id studentContactId = getPersonContactIdForAccount(studentAccountId);

    if (timelineId == null) {
      timelineId = findActiveTimelineId();
    }
    Preconditions.checkNotNull(timelineId, 'No active application timeline found');

    List<String> excludedStatuses = new List<String>{ 'Cancelled', 'Withdrawn/Declined' };
    String existingQuery =
      'SELECT Id FROM IndividualApplication' +
      ' WHERE AccountId = :studentAccountId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND Status NOT IN :excludedStatuses' +
      ' AND AppliedDate = NULL' +
      ' ORDER BY CreatedDate DESC' +
      ' LIMIT 1';
    List<IndividualApplication> existing = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'studentAccountId' => studentAccountId,
        'timelineId' => timelineId,
        'excludedStatuses' => excludedStatuses
      }
    );
    if (!existing.isEmpty()) {
      return new Map<String, Object>{ 'applicationId' => existing[0].Id };
    }

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('ContactId', studentContactId);
    fields.put('SubmittedByContactId', contactId);
    fields.put('AccountId', studentAccountId);
    fields.put('Category', 'Education');
    fields.put('Application_Timeline__c', timelineId);
    if (String.isNotBlank(grade)) {
      fields.put('Grade_Applying_To__c', grade);
    }
    if (guardianAccountId != null) {
      fields.put('Primary_Guardian__c', guardianAccountId);
    }
    if (String.isNotBlank(currentGrade)) {
      fields.put('Current_Grade__c', currentGrade);
    }
    fields.put('Status', 'Draft');

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.insertSObjects(new List<IndividualApplication>{ app });

    return new Map<String, Object>{ 'applicationId' => app.Id };
  }

  private static ApplicationTimeline findActiveTimeline() {
    // Active__c is a formula (ApplicationOpenDate <= TODAY <= ApplicationCloseDate), so
    // ORDER BY Active__c DESC prefers the currently-open timeline even when an inactive
    // (recently-closed) one has a later open date — matching getAvailableTimelines /
    // findActiveTimelineId. When nothing is active we fall back to the most recently-opened
    // (now-closed) timeline for the closed-state landing content; ApplicationOpenDate <= TODAY
    // excludes future-dated timelines from that fallback.
    String query =
      'SELECT Id, Name, ApplicationOpenDate, ApplicationCloseDate,' +
      ' Landing_Content_en__c, Landing_Content_es__c' +
      ' FROM ApplicationTimeline' +
      ' WHERE ApplicationOpenDate != NULL' +
      ' AND ApplicationOpenDate <= TODAY' +
      ' ORDER BY Active__c DESC, ApplicationOpenDate DESC' +
      ' LIMIT 1';
    List<ApplicationTimeline> timelines = (List<ApplicationTimeline>) databaseRepo.query(query);
    return timelines.isEmpty() ? null : timelines[0];
  }

  private static Id findActiveTimelineId() {
    String query =
      'SELECT Id FROM ApplicationTimeline' +
      ' WHERE Active__c = true' +
      ' AND ApplicationOpenDate <= TODAY' +
      ' AND (ApplicationCloseDate >= TODAY OR ApplicationCloseDate = NULL)' +
      ' ORDER BY ApplicationOpenDate DESC' +
      ' LIMIT 1';
    List<ApplicationTimeline> timelines = (List<ApplicationTimeline>) databaseRepo.query(query);
    return timelines.isEmpty() ? null : timelines[0].Id;
  }

  private static String selectLandingContent(String enContent, String esContent) {
    String lang = UserInfo.getLanguage();
    String primary = lang != null && lang.startsWith('es') ? esContent : enContent;
    String fallback = lang != null && lang.startsWith('es') ? enContent : esContent;
    return String.isNotBlank(primary) ? primary : fallback;
  }

  private static Id getPersonContactIdForAccount(Id accountId) {
    String query = 'SELECT PersonContactId FROM Account WHERE Id = :accountId LIMIT 1';
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'accountId' => accountId }
    );
    return accounts.isEmpty() ? null : accounts[0].PersonContactId;
  }

  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }
}