public without sharing class SchoolSelectionController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @TestVisible
  private static EventBusRepo eventBusRepo = new EventBusRepoImpl();

  @AuraEnabled
  public static Map<String, Object> getEligibleSchools(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String appQuery =
      'SELECT Grade_Applying_To__c, AccountId, Application_Timeline__c,' +
      ' Account.PersonMailingStreet,' +
      ' Account.PersonMailingCity,' +
      ' Account.PersonMailingState,' +
      ' Account.PersonMailingPostalCode,' +
      ' Account.PersonMailingLatitude,' +
      ' Account.PersonMailingLongitude,' +
      ' Primary_Guardian__r.PersonMailingStreet,' +
      ' Primary_Guardian__r.PersonMailingCity,' +
      ' Primary_Guardian__r.PersonMailingState,' +
      ' Primary_Guardian__r.PersonMailingPostalCode,' +
      ' Primary_Guardian__r.PersonMailingLatitude,' +
      ' Primary_Guardian__r.PersonMailingLongitude' +
      ' FROM IndividualApplication' +
      ' WHERE Id = :applicationId' +
      ' LIMIT 1';
    List<IndividualApplication> appResults = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(!appResults.isEmpty(), 'Application not found');
    IndividualApplication app = appResults[0];
    Preconditions.checkArgument(
      String.isNotBlank(app.Grade_Applying_To__c),
      'Application must have a grade selected before choosing schools'
    );
    Preconditions.checkNotNull(
      app.Application_Timeline__c,
      'Application is not linked to an application timeline'
    );

    Id timelineId = app.Application_Timeline__c;

    String grade = app.Grade_Applying_To__c;
    List<String> fields = new List<String>{
      'Id',
      'Name',
      'Grade__c',
      'Program_Term_Application_Timeline__c',
      'Program_Term_Application_Timeline__r.LearningProgramId',
      'Program_Term_Application_Timeline__r.AcademicTermId',
      'Program_Term_Application_Timeline__r.LearningProgram.School__c',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Name',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Zeta_School_Name__c',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingStreet',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingCity',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingState',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingPostalCode',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingLatitude',
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.BillingLongitude'
    };

    String query =
      'SELECT ' +
      String.join(fields, ', ') +
      ' FROM Lottery_Capacity__c' +
      ' WHERE Program_Term_Application_Timeline__r.ApplicationTimelineId = :timelineId' +
      ' AND Grade__c = :grade' +
      ' ORDER BY Program_Term_Application_Timeline__r.LearningProgram.School__r.Name ASC';

    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'timelineId' => timelineId, 'grade' => grade }
    );

    Map<Id, Map<String, Object>> schoolMap = new Map<Id, Map<String, Object>>();
    for (Lottery_Capacity__c cap : capacities) {
      Id schoolAcctId = cap.Program_Term_Application_Timeline__r?.LearningProgram?.School__c;
      if (schoolAcctId == null || schoolMap.containsKey(schoolAcctId)) {
        continue;
      }

      Account school = cap.Program_Term_Application_Timeline__r.LearningProgram.School__r;

      Map<String, Object> schoolData = new Map<String, Object>();
      schoolData.put('schoolAccountId', schoolAcctId);
      schoolData.put(
        'name',
        school.Zeta_School_Name__c != null ? school.Zeta_School_Name__c : school.Name
      );
      schoolData.put('street', school.BillingStreet);
      schoolData.put('city', school.BillingCity);
      schoolData.put('state', school.BillingState);
      schoolData.put('postalCode', school.BillingPostalCode);
      schoolData.put('latitude', school.BillingLatitude);
      schoolData.put('longitude', school.BillingLongitude);
      schoolData.put('lotteryCapacityId', cap.Id);
      schoolData.put(
        'learningProgramId',
        cap.Program_Term_Application_Timeline__r.LearningProgramId
      );
      schoolData.put('academicTermId', cap.Program_Term_Application_Timeline__r.AcademicTermId);

      schoolMap.put(schoolAcctId, schoolData);
    }

    // The map's home pin follows the STUDENT's mailing address (the application
    // Account / student person account). When the student's address is blank
    // (street/state/zip), fall back to the Primary Guardian's mailing address so
    // a brand-new application that captured only a guardian/home address still
    // renders a home pin. Both sources are populated by the same page-1 address
    // sections: "Lives with Guardian 1" (checked) writes the one address to both
    // the student and the guardian; unchecked captures a distinct student address.
    Account student = app.Account;
    Account guardian = app.Primary_Guardian__r;
    Boolean studentHasAddress =
      String.isNotBlank(student?.PersonMailingStreet) &&
      String.isNotBlank(student?.PersonMailingState) &&
      String.isNotBlank(student?.PersonMailingPostalCode);
    Account home = studentHasAddress ? student : guardian;

    Map<String, Object> homeAddr = new Map<String, Object>();
    homeAddr.put('street', home?.PersonMailingStreet);
    homeAddr.put('city', home?.PersonMailingCity);
    homeAddr.put('state', home?.PersonMailingState);
    homeAddr.put('postalCode', home?.PersonMailingPostalCode);
    homeAddr.put('latitude', home?.PersonMailingLatitude);
    homeAddr.put('longitude', home?.PersonMailingLongitude);

    Map<String, Object> result = new Map<String, Object>();
    result.put('schools', schoolMap.values());
    result.put('homeAddress', homeAddr);
    result.put('grade', grade);
    result.put('gradeLabel', getGradeLabel(grade));
    return result;
  }

  @AuraEnabled
  public static List<Map<String, Object>> getSelectedSchools(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Id, LearningProgramId, LearningProgram.School__c,' +
      ' Lottery_Capacity__c, School_Rank__c' +
      ' FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId' +
      ' AND Status = :draftStatus';
    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId, 'draftStatus' => 'Draft' }
    );

    List<Map<String, Object>> selections = new List<Map<String, Object>>();
    for (AcademicInterest ai : interests) {
      Map<String, Object> selection = new Map<String, Object>();
      selection.put('academicInterestId', ai.Id);
      selection.put('schoolAccountId', ai.LearningProgram?.School__c);
      selection.put('learningProgramId', ai.LearningProgramId);
      selection.put('lotteryCapacityId', ai.Lottery_Capacity__c);
      selection.put('rank', ai.School_Rank__c);
      selections.add(selection);
    }
    return selections;
  }

  @AuraEnabled
  public static void saveSchoolSelections(Id applicationId, String selectionsJson) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(selectionsJson, 'Selections JSON is required');

    List<Object> selections = (List<Object>) JSON.deserializeUntyped(selectionsJson);

    Set<Id> capacityIds = new Set<Id>();
    for (Object sel : selections) {
      Map<String, Object> s = (Map<String, Object>) sel;
      Object capId = s.get('lotteryCapacityId');
      if (capId != null) {
        capacityIds.add((Id) capId);
      }
    }

    if (!capacityIds.isEmpty()) {
      String appGradeQuery =
        'SELECT Grade_Applying_To__c FROM IndividualApplication' +
        ' WHERE Id = :applicationId LIMIT 1';
      List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        appGradeQuery,
        new Map<String, Object>{ 'applicationId' => applicationId }
      );
      String applicationGrade = apps.isEmpty() ? null : apps[0].Grade_Applying_To__c;

      String capacityQuery = 'SELECT Id, Grade__c FROM Lottery_Capacity__c WHERE Id IN :capacityIds';
      List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
        capacityQuery,
        new Map<String, Object>{ 'capacityIds' => capacityIds }
      );
      for (Lottery_Capacity__c cap : capacities) {
        if (cap.Grade__c != applicationGrade) {
          throw new AuraHandledException(
            'Selected schools don\'t match your current grade. Please re-select.'
          );
        }
      }
    }

    String deleteQuery =
      'SELECT Id FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId' +
      ' AND Status = :draftStatus';
    List<AcademicInterest> existing = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      deleteQuery,
      new Map<String, Object>{ 'applicationId' => applicationId, 'draftStatus' => 'Draft' }
    );
    if (!existing.isEmpty()) {
      databaseRepo.deleteSObjects(existing);
    }

    List<AcademicInterest> toInsert = new List<AcademicInterest>();

    for (Object sel : selections) {
      toInsert.add(newSchoolChoice(applicationId, (Map<String, Object>) sel, 'Draft'));
    }

    if (!toInsert.isEmpty()) {
      // The wizard skips the ranking step when only one school is chosen, so the
      // ranking step never gets to rank it.
      if (toInsert.size() == 1) {
        toInsert[0].School_Rank__c = 1;
      }
      databaseRepo.insertSObjects(toInsert);
    }
  }

  /**
   * SFR-216: adds schools offered by getEligibleSchools to a submitted application, after its
   * existing choices, while the application window is open. A parent can only add to their own.
   */
  @AuraEnabled
  public static void addSchools(Id applicationId, List<Id> lotteryCapacityIds) {
    IndividualApplication app = (IndividualApplication) databaseRepo.queryWithBinds(
      'SELECT Status, AppliedDate, SubmittedByContactId,' +
        ' Application_Timeline__r.ApplicationCloseDate' +
        ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    )[0];
    Date closeDate = app.Application_Timeline__r?.ApplicationCloseDate;
    Preconditions.checkArgument(
      app.AppliedDate != null &&
        app.Status != 'Withdrawn/Declined' &&
        (closeDate == null || closeDate >= Date.today()),
      'Schools can only be added to a submitted application while the application window is open.'
    );
    Preconditions.checkArgument(
      UserInfo.getUserType() == 'Standard' ||
        app.SubmittedByContactId == ApplicationContext.resolveGuardianContactId(databaseRepo, null),
      'You can only add schools to your own application.'
    );

    Map<Id, Map<String, Object>> offeredByCapacity = new Map<Id, Map<String, Object>>();
    for (
      Map<String, Object> school : (List<Map<String, Object>>) getEligibleSchools(applicationId)
        .get('schools')
    ) {
      offeredByCapacity.put((Id) school.get('lotteryCapacityId'), school);
    }
    // Ranks are unique across every choice on the application, withdrawn ones included.
    Set<Id> schoolsOnApplication = new Set<Id>();
    Decimal rank = 0;
    for (
      AcademicInterest choice : (List<AcademicInterest>) databaseRepo.queryWithBinds(
        'SELECT LearningProgram.School__c, School_Rank__c FROM AcademicInterest' +
          ' WHERE IndividualApplicationId = :applicationId',
        new Map<String, Object>{ 'applicationId' => applicationId }
      )
    ) {
      schoolsOnApplication.add(choice.LearningProgram?.School__c);
      rank = Math.max(rank, choice.School_Rank__c == null ? 0 : choice.School_Rank__c);
    }

    List<AcademicInterest> toInsert = new List<AcademicInterest>();
    for (Id capacityId : lotteryCapacityIds) {
      Map<String, Object> school = offeredByCapacity.get(capacityId);
      Preconditions.checkArgument(
        school != null && schoolsOnApplication.add((Id) school.get('schoolAccountId')),
        'A selected school can\'t be added to this application.'
      );
      AcademicInterest choice = newSchoolChoice(applicationId, school, 'Applied');
      rank += 1;
      choice.School_Rank__c = rank;
      toInsert.add(choice);
    }
    databaseRepo.insertSObjects(toInsert);
    // Keep the File PDF current, like SchoolRankingController.saveRankings.
    eventBusRepo.publish(new Application_Submitted_Event__e(Application_Id__c = applicationId));
  }

  // A school choice from a getEligibleSchools / schoolSelection entry.
  private static AcademicInterest newSchoolChoice(
    Id applicationId,
    Map<String, Object> school,
    String status
  ) {
    Map<String, Object> fields = new Map<String, Object>{
      'IndividualApplicationId' => applicationId,
      'AccountId' => school.get('schoolAccountId'),
      'LearningProgramId' => school.get('learningProgramId'),
      'Lottery_Capacity__c' => school.get('lotteryCapacityId'),
      'AcademicTermId' => school.get('academicTermId'),
      'Status' => status
    };
    return (AcademicInterest) JSON.deserialize(JSON.serialize(fields), AcademicInterest.class);
  }

  @AuraEnabled(cacheable=true)
  public static String getMapPageUrl() {
    PageReference pr = Page.SchoolMapPage;
    String orgDomain = URL.getOrgDomainUrl().toExternalForm();
    return orgDomain + pr.getUrl();
  }

  private static String getGradeLabel(String gradeValue) {
    if (String.isBlank(gradeValue))
      return '';
    for (
      Schema.PicklistEntry pe : IndividualApplication.Grade_Applying_To__c.getDescribe()
        .getPicklistValues()
    ) {
      if (pe.getValue() == gradeValue)
        return pe.getLabel();
    }
    return gradeValue;
  }
}