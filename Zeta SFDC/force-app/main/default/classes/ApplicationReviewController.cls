/**
 * Bundles the read-only Apex calls used by the Confirm & Submit review step
 * (LWC `confirmationReview`). Returning all five datasets from a single
 * `@AuraEnabled(cacheable=true)` method lets the LWC use `@wire`, which both
 * dedupes round-trips and serves cached results on subsequent visits.
 *
 * Query logic is duplicated from the existing single-purpose controllers
 * (`SchoolRankingController`, `SiblingSectionController`,
 * `StudentSelectionController`, `ZetaApplicationController`) so we keep one
 * injectable repo seam (`databaseRepo`) for unit tests.
 */
public without sharing class ApplicationReviewController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getReviewBundle(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    Map<String, Object> bundle = new Map<String, Object>();
    bundle.put('schools', getRankedSchools(applicationId));
    bundle.put('siblings', getSiblings(applicationId));
    bundle.put('applicationStudent', getApplicationStudent(applicationId));
    bundle.put('students', getStudents());
    bundle.put('submissionWarnings', getSubmissionWarnings(applicationId));
    return bundle;
  }

  // --- Schools ---------------------------------------------------------------
  // Mirror of SchoolRankingController.getRankedSchools.
  private static List<Map<String, Object>> getRankedSchools(Id applicationId) {
    // NOTE: no Status filter. This must mirror
    // SchoolRankingController.getRankedSchools, which returns AcademicInterest
    // records regardless of Status. submitApplication() flips ranked interests
    // from 'Draft' to 'Applied' (and lottery/waitlist processing moves them on
    // to 'Submitted', 'Eligible', etc.), so a 'Draft'-only filter returns zero
    // schools for any submitted application — which hid the School Rankings
    // review card and its "Update Rankings" button post-submission.
    String query =
      'SELECT Id, LearningProgramId,' +
      ' LearningProgram.School__c, LearningProgram.School__r.Name,' +
      ' LearningProgram.School__r.Zeta_School_Name__c, School_Rank__c, Status' +
      ' FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId' +
      ' ORDER BY School_Rank__c ASC NULLS LAST';
    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    List<Map<String, Object>> schools = new List<Map<String, Object>>();
    for (AcademicInterest ai : interests) {
      Account school = ai.LearningProgram?.School__r;
      Map<String, Object> schoolData = new Map<String, Object>();
      schoolData.put('academicInterestId', ai.Id);
      schoolData.put('schoolAccountId', ai.LearningProgram?.School__c);
      schoolData.put(
        'name',
        school?.Zeta_School_Name__c != null ? school.Zeta_School_Name__c : school?.Name
      );
      schoolData.put('rank', ai.School_Rank__c);
      // Drives the per-school "Withdrawn" badge and gates the withdraw kebab on
      // the review screen (a school already at 'Withdrawn/Declined' can't be
      // withdrawn again).
      schoolData.put('status', ai.Status);
      schools.add(schoolData);
    }
    return schools;
  }

  // --- Siblings --------------------------------------------------------------
  // Mirror of SiblingSectionController.getSiblings.
  private static List<Map<String, Object>> getSiblings(Id applicationId) {
    String query =
      'SELECT Id, Priority_Type__c, First_Name__c, Last_Name__c,' +
      ' Date_of_Birth__c, Gender__c, Sibling_s_Zeta_School__c' +
      ' FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c IN :siblingTypes' +
      ' ORDER BY Priority_Type__c, CreatedDate';
    List<Priority_Item__c> items = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'siblingTypes' => new List<String>{ 'Sibling Attending', 'Sibling Applying' }
      }
    );

    // Return plain maps keyed by field API name — NOT raw Priority_Item__c
    // SObjects. The parent-portal profile has no read access to Priority_Item__c,
    // and the Lightning framework enforces the running user's object access on
    // SObjects returned from an @AuraEnabled method (independent of the
    // system-mode query). Returning raw records made the entire getReviewBundle
    // response fail for portal users, which hid the School Rankings review card
    // and its "Update Rankings" button post-submission. Maps of primitives
    // sidestep that enforcement, matching the other bundle sections.
    List<Map<String, Object>> siblings = new List<Map<String, Object>>();
    for (Priority_Item__c pi : items) {
      siblings.add(
        new Map<String, Object>{
          'Id' => pi.Id,
          'Priority_Type__c' => pi.Priority_Type__c,
          'First_Name__c' => pi.First_Name__c,
          'Last_Name__c' => pi.Last_Name__c,
          'Date_of_Birth__c' => pi.Date_of_Birth__c,
          'Gender__c' => pi.Gender__c,
          'Sibling_s_Zeta_School__c' => pi.Sibling_s_Zeta_School__c
        }
      );
    }
    return siblings;
  }

  // --- Application student ---------------------------------------------------
  // Mirror of StudentSelectionController.getApplicationStudent.
  private static Map<String, Object> getApplicationStudent(Id applicationId) {
    String query =
      'SELECT AccountId, Grade_Applying_To__c, Current_Grade__c, Age_Inconsistency_Flag_c__c,' +
      ' Application_Timeline__r.Academic_Term__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    if (apps.isEmpty()) {
      return new Map<String, Object>();
    }

    IndividualApplication app = apps[0];
    Map<String, Object> result = new Map<String, Object>();
    result.put('studentAccountId', app.AccountId);
    result.put('grade', app.Grade_Applying_To__c);
    result.put('gradeLabel', getGradeLabel(app.Grade_Applying_To__c));
    result.put('currentGrade', app.Current_Grade__c);
    result.put('currentGradeLabel', getGradeLabel(app.Current_Grade__c));
    result.put('ageInconsistency', app.Age_Inconsistency_Flag_c__c);
    result.put(
      'schoolStartDate',
      SchoolStartDateProvider.get(app.Application_Timeline__r?.Academic_Term__c)
    );
    return result;
  }

  // --- Students for guardian -------------------------------------------------
  // Mirror of StudentSelectionController.getStudents.
  private static List<Map<String, Object>> getStudents() {
    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      return new List<Map<String, Object>>();
    }

    String query =
      'SELECT Account.Id, Account.FirstName, Account.LastName,' +
      ' Account.PersonContact.Birthdate,' +
      ' Account.PersonMailingStreet, Account.PersonMailingCity,' +
      ' Account.PersonMailingState, Account.PersonMailingPostalCode' +
      ' FROM AccountContactRelation' +
      ' WHERE ContactId = :contactId' +
      ' AND Account.RecordType.DeveloperName = \'Student\'' +
      ' AND IsActive = TRUE';
    List<AccountContactRelation> relations = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'contactId' => contactId }
    );

    List<Map<String, Object>> students = new List<Map<String, Object>>();
    for (AccountContactRelation acr : relations) {
      Map<String, Object> student = new Map<String, Object>();
      student.put('id', acr.Account.Id);
      student.put('firstName', acr.Account.FirstName);
      student.put('lastName', acr.Account.LastName);
      student.put('birthdate', acr.Account.PersonContact.Birthdate);

      List<String> addrParts = new List<String>();
      if (String.isNotBlank(acr.Account.PersonMailingStreet)) {
        addrParts.add(acr.Account.PersonMailingStreet);
      }
      if (String.isNotBlank(acr.Account.PersonMailingCity)) {
        addrParts.add(acr.Account.PersonMailingCity);
      }
      if (String.isNotBlank(acr.Account.PersonMailingState)) {
        addrParts.add(acr.Account.PersonMailingState);
      }
      if (String.isNotBlank(acr.Account.PersonMailingPostalCode)) {
        addrParts.add(acr.Account.PersonMailingPostalCode);
      }
      student.put('address', String.join(addrParts, ', '));
      students.add(student);
    }
    return students;
  }

  // --- Submission warnings ---------------------------------------------------
  // Mirror of ZetaApplicationController.getSubmissionWarnings.
  private static Map<String, Object> getSubmissionWarnings(Id applicationId) {
    String query =
      'SELECT Age_Inconsistency_Flag_c__c, Outside_of_NY__c, Grade_Applying_To__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    Map<String, Object> result = new Map<String, Object>();
    if (apps.isEmpty()) {
      result.put('hasAgeWarning', false);
      result.put('hasResidencyWarning', false);
      result.put('residencyRequiresCityOnly', false);
      return result;
    }

    IndividualApplication app = apps[0];
    result.put('hasAgeWarning', app.Age_Inconsistency_Flag_c__c == true);
    result.put('hasResidencyWarning', app.Outside_of_NY__c == true);
    // Pre-K and TK require only NYC residency; K-9 (and up) require NY State
    // residency. Drives which residency message the review screen renders.
    // (TK grouped with Pre-K pending client confirmation.)
    result.put(
      'residencyRequiresCityOnly',
      app.Grade_Applying_To__c == 'PK' || app.Grade_Applying_To__c == 'TK'
    );
    return result;
  }

  // --- Helpers ---------------------------------------------------------------
  private static String getGradeLabel(String gradeValue) {
    if (String.isBlank(gradeValue)) {
      return '';
    }
    for (
      Schema.PicklistEntry pe : IndividualApplication.Grade_Applying_To__c.getDescribe()
        .getPicklistValues()
    ) {
      if (pe.getValue() == gradeValue) {
        return pe.getLabel();
      }
    }
    return gradeValue;
  }

  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }
}