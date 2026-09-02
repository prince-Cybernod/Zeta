public without sharing class ApplicationDashboardController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @AuraEnabled
  public static Map<String, Object> getDashboardData() {
    Boolean isOpen = false;
    String timelineName = '';
    String landingContent = null;

    // Pick the timeline the dashboard banner describes. Active__c is a formula
    // (ApplicationOpenDate <= TODAY <= ApplicationCloseDate), so ORDER BY Active__c DESC
    // makes the currently-open timeline win even when an inactive (recently-closed) one
    // has a later open date — keeping this consistent with the picker
    // (ZetaApplicationController.getAvailableTimelines, WHERE Active__c = true). When
    // nothing is active we still return the most recently-opened (now-closed) timeline so
    // the closed-state landing content renders; ApplicationOpenDate <= TODAY excludes
    // future-dated timelines from that fallback.
    String tlQuery =
      'SELECT Id, Name, ApplicationOpenDate, ApplicationCloseDate,' +
      ' Landing_Content_en__c, Landing_Content_es__c' +
      ' FROM ApplicationTimeline' +
      ' WHERE ApplicationOpenDate != NULL' +
      ' AND ApplicationOpenDate <= TODAY' +
      ' ORDER BY Active__c DESC, ApplicationOpenDate DESC' +
      ' LIMIT 1';
    List<ApplicationTimeline> tls = (List<ApplicationTimeline>) databaseRepo.query(tlQuery);

    if (!tls.isEmpty()) {
      ApplicationTimeline tl = tls[0];
      timelineName = tl.Name;
      Date today = Date.today();
      isOpen =
        tl.ApplicationOpenDate != null &&
        tl.ApplicationOpenDate <= today &&
        (tl.ApplicationCloseDate == null ||
        tl.ApplicationCloseDate >= today);

      if (!isOpen) {
        landingContent = selectLandingContent(tl.Landing_Content_en__c, tl.Landing_Content_es__c);
      }
    }

    List<IndividualApplication> apps = new List<IndividualApplication>();

    // Resolve the logged-in parent's contact + household greeting in one query.
    // Family name follows the portal convention "<LastName> Family".
    Id contactId = null;
    String familyName = null;
    Id userId = UserInfo.getUserId();
    List<User> users = (List<User>) databaseRepo.queryWithBinds(
      'SELECT ContactId, Contact.LastName FROM User WHERE Id = :userId LIMIT 1',
      new Map<String, Object>{ 'userId' => userId }
    );
    if (!users.isEmpty()) {
      contactId = users[0].ContactId;
      String lastName = users[0].Contact?.LastName;
      familyName = String.isNotBlank(lastName) ? lastName + ' Family' : null;
    }

    if (contactId != null) {
      List<String> excludedStatuses = new List<String>{ 'Cancelled' };
      String query =
        'SELECT Id, Name, Status, Grade_Applying_To__c, Last_Completed_Step__c,' +
        ' Account.Name, CreatedDate, AppliedDate,' +
        ' Application_Timeline__c, Application_Timeline__r.Name, Application_Timeline__r.ApplicationOpenDate' +
        ' FROM IndividualApplication' +
        ' WHERE SubmittedByContactId = :contactId' +
        ' AND Status NOT IN :excludedStatuses' +
        ' ORDER BY CreatedDate DESC';
      apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        query,
        new Map<String, Object>{ 'contactId' => contactId, 'excludedStatuses' => excludedStatuses }
      );
    }

    List<Map<String, Object>> appList = new List<Map<String, Object>>();
    for (IndividualApplication app : apps) {
      Map<String, Object> appMap = new Map<String, Object>();
      appMap.put('id', app.Id);
      appMap.put('name', app.Name);
      appMap.put('status', app.Status);
      appMap.put('grade', app.Grade_Applying_To__c);
      appMap.put('lastStep', app.Last_Completed_Step__c);
      appMap.put('studentName', app.Account?.Name);
      appMap.put('createdDate', app.CreatedDate);
      appMap.put('isSubmitted', app.AppliedDate != null);
      appMap.put('timelineId', app.Application_Timeline__c);
      appMap.put('timelineName', app.Application_Timeline__r?.Name);
      appMap.put('timelineOpenDate', app.Application_Timeline__r?.ApplicationOpenDate);
      appList.add(appMap);
    }

    return new Map<String, Object>{
      'isOpen' => isOpen,
      'applications' => appList,
      'timelineName' => timelineName,
      'landingContent' => landingContent,
      'familyName' => familyName,
      'timelines' => ZetaApplicationController.getAvailableTimelines()
    };
  }

  private static String selectLandingContent(String enContent, String esContent) {
    String lang = UserInfo.getLanguage();
    String primary = lang != null && lang.startsWith('es') ? esContent : enContent;
    String fallback = lang != null && lang.startsWith('es') ? enContent : esContent;
    return String.isNotBlank(primary) ? primary : fallback;
  }

  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }

  @AuraEnabled
  public static Map<String, Object> withdrawApplication(
    Id applicationId,
    String reason,
    String picklistReason
  ) {
    if (applicationId == null) {
      throw new AuraHandledException('Application ID is required.');
    }
    if (String.isBlank(picklistReason)) {
      throw new AuraHandledException('Please select a reason for withdrawal.');
    }
    // When "Other" is chosen the free-text reason carries the detail; for every
    // other value we mirror the picklist label into Withdrawn_Declined_Reason__c
    // so VR_IndividualApp_WithdrawnDeclinedReason (free text required when
    // Withdrawn/Declined) stays satisfied.
    Boolean isOther = picklistReason == 'Other';
    if (isOther && String.isBlank(reason)) {
      throw new AuraHandledException('Please describe the reason for withdrawal.');
    }

    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      throw new AuraHandledException('Unable to verify your account.');
    }

    String query =
      'SELECT Id, Status, SubmittedByContactId' +
      ' FROM IndividualApplication' +
      ' WHERE Id = :applicationId' +
      ' LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    if (apps.isEmpty()) {
      throw new AuraHandledException('Application not found.');
    }

    IndividualApplication app = apps[0];
    if (app.SubmittedByContactId != contactId) {
      throw new AuraHandledException('You can only withdraw your own applications.');
    }

    // Idempotency guard — every status short of Withdrawn/Declined is still a
    // live application the parent may pull, so only the terminal state is out.
    if (app.Status == 'Withdrawn/Declined') {
      throw new AuraHandledException('This application has already been withdrawn.');
    }

    app.Status = 'Withdrawn/Declined';
    app.Withdrawn_Declined_Reason_Picklist__c = picklistReason;
    app.Withdrawn_Declined_Reason__c = isOther ? reason : picklistReason;
    databaseRepo.updateSObjects(new List<SObject>{ app });

    return new Map<String, Object>{ 'success' => true };
  }
}