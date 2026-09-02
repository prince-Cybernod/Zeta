/**
 * Backs the internal intake screen, where a Zeta teammate submits on a family's
 * behalf.
 *
 * The parent portal never has to ask which family it is acting for. Staff do, so
 * every entry point here takes the guardian explicitly instead of inferring it
 * from the session.
 */
public without sharing class InternalApplicationController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @TestVisible
  private static DuplicateStudentValidationService dupGuard = new DuplicateStudentValidationServiceImpl();

  private static final String GUARDIAN_RECORD_TYPE = 'Guardian';
  private static final String STUDENT_RECORD_TYPE = 'Student';
  private static final String TEAM_ASSISTED = 'Team-Assisted Conversion';

  /** Guardians matching a name, email or phone fragment. */
  @AuraEnabled
  public static List<Map<String, Object>> searchGuardians(String term) {
    if (String.isBlank(term) || term.trim().length() < 2) {
      return new List<Map<String, Object>>();
    }
    String pattern = '%' + term.trim() + '%';
    String query =
      'SELECT Id, Name, PersonEmail, Phone, PersonMobilePhone' +
      ' FROM Account' +
      ' WHERE IsPersonAccount = true' +
      ' AND RecordType.DeveloperName = :recordType' +
      ' AND (Name LIKE :pattern OR PersonEmail LIKE :pattern' +
      ' OR Phone LIKE :pattern OR PersonMobilePhone LIKE :pattern)' +
      ' ORDER BY LastModifiedDate DESC' +
      ' LIMIT 25';
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'recordType' => GUARDIAN_RECORD_TYPE, 'pattern' => pattern }
    );
    List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (Account a : accounts) {
      results.add(
        new Map<String, Object>{
          'id' => a.Id,
          'name' => a.Name,
          'email' => a.PersonEmail,
          'phone' => String.isNotBlank(a.Phone) ? a.Phone : a.PersonMobilePhone
        }
      );
    }
    return results;
  }

  /**
   * Guardians already holding this email or phone. Staff are warned, not
   * blocked — the same posture as the org's duplicate rules.
   */
  @AuraEnabled
  public static List<Map<String, Object>> findPossibleDuplicates(String email, String phone) {
    if (String.isBlank(email) && String.isBlank(phone)) {
      return new List<Map<String, Object>>();
    }
    // Only bind the identifiers we actually have. A null bind on `Phone = :phone`
    // matches every guardian whose phone is blank, which reads as "10 duplicates"
    // for a family nobody has seen before.
    Map<String, Object> binds = new Map<String, Object>{ 'recordType' => GUARDIAN_RECORD_TYPE };
    List<String> matchClauses = new List<String>();
    if (String.isNotBlank(email)) {
      matchClauses.add('PersonEmail = :email');
      binds.put('email', email);
    }
    if (String.isNotBlank(phone)) {
      matchClauses.add('(Phone = :phone OR PersonMobilePhone = :phone)');
      binds.put('phone', phone);
    }

    String query =
      'SELECT Id, Name, PersonEmail, Phone' +
      ' FROM Account' +
      ' WHERE IsPersonAccount = true' +
      ' AND RecordType.DeveloperName = :recordType' +
      ' AND (' +
      String.join(matchClauses, ' OR ') +
      ')' +
      ' LIMIT 10';
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(query, binds);
    List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (Account a : accounts) {
      results.add(
        new Map<String, Object>{ 'id' => a.Id, 'name' => a.Name, 'email' => a.PersonEmail }
      );
    }
    return results;
  }

  /** Creates the guardian person account and returns it with its Contact. */
  @AuraEnabled
  public static Map<String, Object> createGuardian(String guardianJson) {
    Preconditions.checkNotBlank(guardianJson, 'Guardian JSON is required');
    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(guardianJson);
    Preconditions.checkNotBlank(
      ObjectUtil.safeValueOfString(input.get('lastName')),
      'Last name is required'
    );

    Map<String, Object> fields = new Map<String, Object>{
      'RecordTypeId' => recordTypeId(GUARDIAN_RECORD_TYPE),
      'FirstName' => input.get('firstName'),
      'LastName' => input.get('lastName')
    };
    putIfPresent(fields, input, 'email', 'PersonEmail');
    putIfPresent(fields, input, 'phone', 'PersonMobilePhone');
    putIfPresent(fields, input, 'languagePreference', 'Language_Preference__pc');
    putIfPresent(fields, input, 'street', 'PersonMailingStreet');
    putIfPresent(fields, input, 'city', 'PersonMailingCity');
    putIfPresent(fields, input, 'state', 'PersonMailingState');
    putIfPresent(fields, input, 'zip', 'PersonMailingPostalCode');
    if (input.containsKey('street') || input.containsKey('city')) {
      fields.put('PersonMailingCountry', 'US');
    }

    Account guardian = (Account) JSON.deserialize(JSON.serialize(fields), Account.class);
    databaseRepo.insertSObjects(new List<Account>{ guardian });

    return new Map<String, Object>{
      'accountId' => guardian.Id,
      'contactId' => ApplicationContext.personContactIdFor(databaseRepo, guardian.Id)
    };
  }

  /** Students already related to this guardian, so staff can reuse a sibling. */
  @AuraEnabled
  public static List<Map<String, Object>> getGuardianStudents(Id guardianAccountId) {
    Preconditions.checkNotNull(guardianAccountId, 'Guardian Account Id is required');
    Id guardianContactId = ApplicationContext.personContactIdFor(databaseRepo, guardianAccountId);
    if (guardianContactId == null) {
      return new List<Map<String, Object>>();
    }
    String query =
      'SELECT AccountId, Account.FirstName, Account.LastName, Account.PersonBirthdate' +
      ' FROM AccountContactRelation' +
      ' WHERE ContactId = :guardianContactId' +
      ' AND IsActive = true' +
      ' AND Account.RecordType.DeveloperName = :recordType';
    List<AccountContactRelation> relations = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'guardianContactId' => guardianContactId,
        'recordType' => STUDENT_RECORD_TYPE
      }
    );
    List<Map<String, Object>> students = new List<Map<String, Object>>();
    for (AccountContactRelation acr : relations) {
      students.add(
        new Map<String, Object>{
          'id' => acr.AccountId,
          'firstName' => acr.Account.FirstName,
          'lastName' => acr.Account.LastName,
          'birthdate' => acr.Account.PersonBirthdate
        }
      );
    }
    return students;
  }

  /** Creates a student under the named guardian and relates the two. */
  @AuraEnabled
  public static Id createStudentForGuardian(Id guardianAccountId, String studentJson) {
    Preconditions.checkNotNull(guardianAccountId, 'Guardian Account Id is required');
    Preconditions.checkNotBlank(studentJson, 'Student JSON is required');

    Id guardianContactId = ApplicationContext.personContactIdFor(databaseRepo, guardianAccountId);
    Preconditions.checkNotNull(guardianContactId, 'Guardian must have a Contact');

    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(studentJson);
    dupGuard.assertNoDuplicate(
      ObjectUtil.safeValueOfString(input.get('firstName')),
      ObjectUtil.safeValueOfString(input.get('lastName')),
      ObjectUtil.safeValueOfString(input.get('birthdate')),
      guardianContactId
    );

    // Stamp the guardian on the student up front. Left blank, Zeta's "Sync
    // Guardians to Student" flow fills it on the first application save, and that
    // update re-fires "Auto-Create Guardian/Student CCR" against a relationship
    // that already exists, rolling the application back.
    Map<String, Object> fields = new Map<String, Object>{
      'RecordTypeId' => recordTypeId(STUDENT_RECORD_TYPE),
      'FirstName' => input.get('firstName'),
      'LastName' => input.get('lastName'),
      'Primary_Guardian__c' => guardianAccountId
    };
    String birthdate = ObjectUtil.safeValueOfString(input.get('birthdate'));
    if (String.isNotBlank(birthdate)) {
      fields.put('PersonBirthdate', birthdate);
    }
    putIfPresent(fields, input, 'gender', 'PersonGenderIdentity');

    Account student = (Account) JSON.deserialize(JSON.serialize(fields), Account.class);
    databaseRepo.insertSObjects(new List<Account>{ student });

    relateGuardianToStudent(student.Id, guardianContactId);
    return student.Id;
  }

  /**
   * Creates the draft application for a student, stamping the guardian and the
   * lead-tracking fields the internal path is responsible for.
   */
  @AuraEnabled
  public static Map<String, Object> startApplication(String requestJson) {
    Preconditions.checkNotBlank(requestJson, 'Request JSON is required');
    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(requestJson);

    Id guardianAccountId = (Id) ObjectUtil.safeValueOfString(input.get('guardianAccountId'));
    Id studentAccountId = (Id) ObjectUtil.safeValueOfString(input.get('studentAccountId'));
    Id timelineId = (Id) ObjectUtil.safeValueOfString(input.get('timelineId'));
    Preconditions.checkNotNull(guardianAccountId, 'Guardian Account Id is required');
    Preconditions.checkNotNull(studentAccountId, 'Student Account Id is required');
    Preconditions.checkNotNull(timelineId, 'Application Timeline is required');

    Id existingId = findExistingDraft(studentAccountId, timelineId);
    if (existingId != null) {
      return new Map<String, Object>{ 'applicationId' => existingId, 'reused' => true };
    }

    copyGuardianAddressToStudent(guardianAccountId, studentAccountId);

    Map<String, Object> fields = new Map<String, Object>{
      'AccountId' => studentAccountId,
      'ContactId' => ApplicationContext.personContactIdFor(databaseRepo, studentAccountId),
      'SubmittedByContactId' => ApplicationContext.personContactIdFor(
        databaseRepo,
        guardianAccountId
      ),
      'Primary_Guardian__c' => guardianAccountId,
      'Application_Timeline__c' => timelineId,
      'Category' => 'Education',
      'Status' => 'Draft',
      'Converting_Team_Member__c' => UserInfo.getUserId(),
      'Conversion_Type__c' => TEAM_ASSISTED
    };
    putIfPresent(fields, input, 'grade', 'Grade_Applying_To__c');
    putIfPresent(fields, input, 'currentGrade', 'Current_Grade__c');
    putIfPresent(fields, input, 'leadSource', 'Lead_Source__c');
    putIfPresent(fields, input, 'appInfoSource', 'App_Info_Source_Staff_Internal__c');

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(fields),
      IndividualApplication.class
    );
    databaseRepo.insertSObjects(new List<IndividualApplication>{ app });

    return new Map<String, Object>{ 'applicationId' => app.Id, 'reused' => false };
  }

  /**
   * Gives the student the guardian's mailing address before the wizard opens.
   *
   * The wizard reads Guardian 1's address straight off the guardian record, so
   * the intake screen already fills that side. The student side reads the
   * student record, which a staff-created student has nothing on — so the
   * address typed on the intake screen would stop at Guardian 1. In the portal
   * the guardian answers both from inside the wizard and a companion writeback
   * keeps them together; here there is no such edit to hang it off.
   *
   * Only ever fills a blank: a student who already has an address keeps it.
   */
  private static void copyGuardianAddressToStudent(Id guardianAccountId, Id studentAccountId) {
    List<Id> accountIds = new List<Id>{ guardianAccountId, studentAccountId };
    List<Account> accounts = (List<Account>) databaseRepo.queryWithBinds(
      'SELECT Id, PersonMailingStreet, PersonMailingCity, PersonMailingState,' +
        ' PersonMailingPostalCode, PersonMailingCountry, Apartment_Number__c' +
        ' FROM Account WHERE Id IN :accountIds',
      new Map<String, Object>{ 'accountIds' => accountIds }
    );
    Account guardian;
    Account student;
    for (Account a : accounts) {
      if (a.Id == guardianAccountId) {
        guardian = a;
      } else if (a.Id == studentAccountId) {
        student = a;
      }
    }
    if (guardian == null || student == null) {
      return;
    }
    if (
      String.isBlank(guardian.PersonMailingStreet) || String.isNotBlank(student.PersonMailingStreet)
    ) {
      return;
    }

    databaseRepo.updateSObjects(
      new List<Account>{
        new Account(
          Id = studentAccountId,
          PersonMailingStreet = guardian.PersonMailingStreet,
          PersonMailingCity = guardian.PersonMailingCity,
          PersonMailingState = guardian.PersonMailingState,
          PersonMailingPostalCode = guardian.PersonMailingPostalCode,
          PersonMailingCountry = guardian.PersonMailingCountry,
          Apartment_Number__c = guardian.Apartment_Number__c
        )
      }
    );
  }

  /**
   * Zeta's "Auto-Create Guardian/Student CCR" flow already relates a new student
   * to its guardian. Creating a second relationship here makes every later save
   * of that student fail on DUPLICATE_VALUE, so only step in if the flow did not.
   */
  private static void relateGuardianToStudent(Id studentAccountId, Id guardianContactId) {
    List<AccountContactRelation> existing = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      'SELECT Id FROM AccountContactRelation' +
      ' WHERE AccountId = :studentAccountId AND ContactId = :guardianContactId LIMIT 1',
      new Map<String, Object>{
        'studentAccountId' => studentAccountId,
        'guardianContactId' => guardianContactId
      }
    );
    if (!existing.isEmpty()) {
      return;
    }
    databaseRepo.insertSObjects(
      new List<AccountContactRelation>{
        new AccountContactRelation(
          AccountId = studentAccountId,
          ContactId = guardianContactId,
          IsActive = true
        )
      }
    );
  }

  private static Id findExistingDraft(Id studentAccountId, Id timelineId) {
    List<String> excludedStatuses = new List<String>{ 'Cancelled', 'Withdrawn/Declined' };
    String query =
      'SELECT Id FROM IndividualApplication' +
      ' WHERE AccountId = :studentAccountId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND Status NOT IN :excludedStatuses' +
      ' AND AppliedDate = NULL' +
      ' ORDER BY CreatedDate DESC' +
      ' LIMIT 1';
    List<IndividualApplication> existing = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'studentAccountId' => studentAccountId,
        'timelineId' => timelineId,
        'excludedStatuses' => excludedStatuses
      }
    );
    return existing.isEmpty() ? null : existing[0].Id;
  }

  private static Id recordTypeId(String developerName) {
    return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get(developerName)
      .getRecordTypeId();
  }

  private static void putIfPresent(
    Map<String, Object> fields,
    Map<String, Object> input,
    String inputKey,
    String fieldName
  ) {
    String value = ObjectUtil.safeValueOfString(input.get(inputKey));
    if (String.isNotBlank(value)) {
      fields.put(fieldName, value);
    }
  }
}