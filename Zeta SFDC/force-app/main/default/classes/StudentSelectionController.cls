public without sharing class StudentSelectionController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @TestVisible
  private static DuplicateStudentValidationService dupGuard = new DuplicateStudentValidationServiceImpl();

  @AuraEnabled
  public static List<Map<String, Object>> getStudents() {
    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      return new List<Map<String, Object>>();
    }

    String query =
      'SELECT Account.Id, Account.FirstName, Account.LastName,' +
      ' Account.PersonContact.Birthdate,' +
      ' Account.PersonMailingStreet, Account.PersonMailingCity,' +
      ' Account.PersonMailingState, Account.PersonMailingPostalCode,' +
      ' Account.Apartment_Number__c' +
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
        String streetWithApt = acr.Account.PersonMailingStreet;
        if (String.isNotBlank(acr.Account.Apartment_Number__c)) {
          streetWithApt += ', Apt ' + acr.Account.Apartment_Number__c;
        }
        addrParts.add(streetWithApt);
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

    Set<Id> studentIds = new Set<Id>();
    for (Map<String, Object> s : students) {
      studentIds.add((Id) s.get('id'));
    }
    Set<Id> withSubmittedApplication = new Set<Id>();
    if (!studentIds.isEmpty()) {
      String appQuery =
        'SELECT AccountId FROM IndividualApplication' +
        ' WHERE AccountId IN :studentIds AND AppliedDate != NULL';
      List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        appQuery,
        new Map<String, Object>{ 'studentIds' => studentIds }
      );
      for (IndividualApplication app : apps) {
        withSubmittedApplication.add(app.AccountId);
      }
    }
    for (Map<String, Object> s : students) {
      s.put('hasSubmittedApplication', withSubmittedApplication.contains((Id) s.get('id')));
    }
    return students;
  }

  @AuraEnabled
  public static void updateStudentBirthdate(Id studentAccountId, Date birthdate) {
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');
    Preconditions.checkNotNull(birthdate, 'Birthdate is required');

    Id contactId = getLoggedInContactId();
    Preconditions.checkNotNull(contactId, 'Logged-in user must have a Contact');

    String ownershipQuery =
      'SELECT Id FROM AccountContactRelation' +
      ' WHERE AccountId = :studentAccountId' +
      ' AND ContactId = :contactId' +
      ' AND IsActive = TRUE LIMIT 1';
    List<AccountContactRelation> rels = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      ownershipQuery,
      new Map<String, Object>{ 'studentAccountId' => studentAccountId, 'contactId' => contactId }
    );
    if (rels.isEmpty()) {
      throw new AuraHandledException('You don\'t have permission to update this student.');
    }

    if (hasSubmittedApplication(studentAccountId)) {
      throw new AuraHandledException(
        'This student\'s birthday is locked because an application has been submitted. Contact Zeta to update.'
      );
    }

    Account student = new Account(Id = studentAccountId, PersonBirthdate = birthdate);
    databaseRepo.updateSObjects(new List<Account>{ student });
  }

  private static Boolean hasSubmittedApplication(Id studentAccountId) {
    String query =
      'SELECT Id FROM IndividualApplication' +
      ' WHERE AccountId = :studentAccountId AND AppliedDate != NULL LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'studentAccountId' => studentAccountId }
    );
    return !apps.isEmpty();
  }

  @AuraEnabled
  public static Id createStudent(String studentJson) {
    Preconditions.checkNotBlank(studentJson, 'Student JSON is required');

    Id contactId = getLoggedInContactId();
    Preconditions.checkNotNull(contactId, 'Logged-in user must have a Contact');

    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(studentJson);

    dupGuard.assertNoDuplicate(
      ObjectUtil.safeValueOfString(input.get('firstName')),
      ObjectUtil.safeValueOfString(input.get('lastName')),
      ObjectUtil.safeValueOfString(input.get('birthdate')),
      contactId
    );

    Id studentRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Student')
      .getRecordTypeId();

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('RecordTypeId', studentRtId);
    fields.put('FirstName', input.get('firstName'));
    fields.put('LastName', input.get('lastName'));
    // Date of Birth is optional (e.g. on the "add a sibling" form). A blank
    // string can't be JSON-deserialized into a Date, so only set it when present.
    String birthdate = (String) input.get('birthdate');
    if (String.isNotBlank(birthdate)) {
      fields.put('PersonBirthdate', birthdate);
    }
    // Address fields are now captured separately in the application flow's
    // Student Address section (questionAddress LWC) rather than upfront.
    if (input.containsKey('street')) {
      fields.put('PersonMailingStreet', input.get('street'));
    }
    if (input.containsKey('city')) {
      fields.put('PersonMailingCity', input.get('city'));
    }
    if (input.containsKey('state')) {
      fields.put('PersonMailingState', input.get('state'));
    }
    if (input.containsKey('zip')) {
      fields.put('PersonMailingPostalCode', input.get('zip'));
    }
    if (input.containsKey('street') || input.containsKey('city')) {
      fields.put('PersonMailingCountry', 'US');
    }
    fields.put('PersonGenderIdentity', input.get('gender'));

    Account studentAccount = (Account) JSON.deserialize(JSON.serialize(fields), Account.class);
    databaseRepo.insertSObjects(new List<Account>{ studentAccount });

    AccountContactRelation acr = new AccountContactRelation(
      AccountId = studentAccount.Id,
      ContactId = contactId,
      IsActive = true
    );
    databaseRepo.insertSObjects(new List<AccountContactRelation>{ acr });

    return studentAccount.Id;
  }

  @AuraEnabled(cacheable=true)
  public static Id getGuardianAccountId() {
    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      return null;
    }
    String query = 'SELECT AccountId FROM Contact WHERE Id = :contactId LIMIT 1';
    List<Contact> contacts = (List<Contact>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'contactId' => contactId }
    );
    return contacts.isEmpty() ? null : contacts[0].AccountId;
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, String> getGuardianAddress() {
    Id accountId = getGuardianAccountId();
    if (accountId == null) {
      return new Map<String, String>();
    }
    String query =
      'SELECT PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode' +
      ' FROM Account WHERE Id = :accountId LIMIT 1';
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'accountId' => accountId }
    );
    if (accounts.isEmpty()) {
      return new Map<String, String>();
    }
    Account a = accounts[0];
    Map<String, String> addr = new Map<String, String>();
    addr.put('street', a.PersonMailingStreet != null ? a.PersonMailingStreet : '');
    addr.put('city', a.PersonMailingCity != null ? a.PersonMailingCity : '');
    addr.put('state', a.PersonMailingState != null ? a.PersonMailingState : '');
    addr.put('zip', a.PersonMailingPostalCode != null ? a.PersonMailingPostalCode : '');
    return addr;
  }

  @AuraEnabled
  public static Map<String, Object> selectStudent(
    Id applicationId,
    Id studentAccountId,
    String grade,
    String currentGrade
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');

    String priorGrade = null;
    if (String.isNotBlank(grade)) {
      String priorQuery =
        'SELECT Grade_Applying_To__c FROM IndividualApplication' +
        ' WHERE Id = :applicationId LIMIT 1';
      List<IndividualApplication> priorList = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        priorQuery,
        new Map<String, Object>{ 'applicationId' => applicationId }
      );
      if (!priorList.isEmpty()) {
        priorGrade = priorList[0].Grade_Applying_To__c;
      }
    }

    // Resync ContactId to the newly selected student. The File PDF reads the
    // student's name/DOB from the application's Contact relationship, so it must
    // move with AccountId — otherwise the PDF shows the previously-selected child.
    Id studentContactId = getPersonContactIdForAccount(studentAccountId);

    Map<String, Object> fields = new Map<String, Object>();
    fields.put('Id', applicationId);
    fields.put('AccountId', studentAccountId);
    if (studentContactId != null) {
      fields.put('ContactId', studentContactId);
    }
    if (String.isNotBlank(grade)) {
      fields.put('Grade_Applying_To__c', grade);
    }
    if (String.isNotBlank(currentGrade)) {
      fields.put('Current_Grade__c', currentGrade);
    }

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.updateSObjects(new List<IndividualApplication>{ app });

    if (String.isNotBlank(grade) && String.isNotBlank(priorGrade) && priorGrade != grade) {
      String draftQuery =
        'SELECT Id FROM AcademicInterest' +
        ' WHERE IndividualApplicationId = :applicationId' +
        ' AND Status = :draftStatus';
      List<AcademicInterest> stale = (List<AcademicInterest>) databaseRepo.queryWithBinds(
        draftQuery,
        new Map<String, Object>{ 'applicationId' => applicationId, 'draftStatus' => 'Draft' }
      );
      if (!stale.isEmpty()) {
        databaseRepo.deleteSObjects(stale);
      }
    }

    String selectQuery =
      'SELECT AccountId, Grade_Applying_To__c, Current_Grade__c, Age_Inconsistency_Flag_c__c,' +
      ' Application_Timeline__r.Academic_Term__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> results = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      selectQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    IndividualApplication updated = results[0];

    Map<String, Object> result = new Map<String, Object>();
    result.put('studentAccountId', updated.AccountId);
    result.put('grade', updated.Grade_Applying_To__c);
    result.put('currentGrade', updated.Current_Grade__c);
    result.put('ageInconsistency', updated.Age_Inconsistency_Flag_c__c);
    result.put(
      'schoolStartDate',
      SchoolStartDateProvider.get(updated.Application_Timeline__r?.Academic_Term__c)
    );
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getGradeOptions() {
    List<Schema.PicklistEntry> entries = IndividualApplication.Grade_Applying_To__c
      .getDescribe()
      .getPicklistValues();

    List<Map<String, String>> options = new List<Map<String, String>>();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.isActive()) {
        options.add(
          new Map<String, String>{ 'label' => entry.getLabel(), 'value' => entry.getValue() }
        );
      }
    }
    return options;
  }

  // Birth-year guidance shown beneath the "Grade Applying To" picker when a
  // parent selects Pre-K or Kindergarten ("Students applying to Pre-K must be
  // born in {year}"). Returned as a Map so the LWC can render each grade's note
  // from a single cached call.
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getGradeBirthYearGuidance(Id applicationId) {
    // Birth-year guidance for the Pre-K / Kindergarten note is configured per
    // enrollment cycle on the application's Application Timeline. A blank value
    // (cycle not configured yet) returns null, and the LWC simply omits the note.
    Map<String, Object> result = new Map<String, Object>();
    if (applicationId == null) {
      return result;
    }
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      'SELECT Application_Timeline__r.Pre_K_Birth_Year__c,' +
        ' Application_Timeline__r.Kindergarten_Birth_Year__c' +
        ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (apps.isEmpty()) {
      return result;
    }
    IndividualApplication app = apps[0];
    result.put('preKBirthYear', app.Application_Timeline__r?.Pre_K_Birth_Year__c);
    result.put('kindergartenBirthYear', app.Application_Timeline__r?.Kindergarten_Birth_Year__c);
    return result;
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getApplicationStudent(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    // Student display fields (FirstName/LastName/PersonContact.Birthdate) are
    // selected so internal callers — who run without a parent Contact and get an
    // empty getStudents() list — can still render the application's student. The
    // community flow ignores them (getStudents() already supplies the tile).
    String query =
      'SELECT AccountId, Account.FirstName, Account.LastName, Account.PersonContact.Birthdate,' +
      ' Grade_Applying_To__c, Current_Grade__c, Age_Inconsistency_Flag_c__c,' +
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
    result.put('firstName', app.Account?.FirstName);
    result.put('lastName', app.Account?.LastName);
    result.put('birthdate', app.Account?.PersonContact?.Birthdate);
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

  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }

  private static Id getPersonContactIdForAccount(Id accountId) {
    String query = 'SELECT PersonContactId FROM Account WHERE Id = :accountId LIMIT 1';
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'accountId' => accountId }
    );
    return accounts.isEmpty() ? null : accounts[0].PersonContactId;
  }
}