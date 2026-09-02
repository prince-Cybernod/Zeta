public without sharing class SiblingSectionController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  @TestVisible
  private static DuplicateStudentValidationService dupGuard = new DuplicateStudentValidationServiceImpl();

  @AuraEnabled
  public static List<Priority_Item__c> getSiblings(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Id, Priority_Type__c, First_Name__c, Last_Name__c,' +
      ' Date_of_Birth__c, Gender__c, Sibling_s_Zeta_School__c' +
      ' FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c IN :siblingTypes' +
      ' ORDER BY Priority_Type__c, CreatedDate';
    return (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'siblingTypes' => new List<String>{ 'Sibling Attending', 'Sibling Applying' }
      }
    );
  }

  @AuraEnabled
  public static void saveSiblings(Id applicationId, String siblingsJson) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(siblingsJson, 'Siblings JSON is required');

    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(siblingsJson);
    Set<Id> incomingIds = new Set<Id>();
    List<Priority_Item__c> toUpsert = new List<Priority_Item__c>();

    for (Object raw : rawList) {
      Map<String, Object> item = (Map<String, Object>) raw;

      Map<String, Object> fields = new Map<String, Object>();
      fields.put('Related_Application__c', applicationId);
      fields.put('Priority_Type__c', item.get('priorityType'));
      fields.put('First_Name__c', item.get('firstName'));
      fields.put('Last_Name__c', item.get('lastName'));
      fields.put('Gender__c', item.get('gender'));
      fields.put('Sibling_s_Zeta_School__c', item.get('zetaSchool'));

      String dob = (String) item.get('dateOfBirth');
      if (String.isNotBlank(dob)) {
        fields.put('Date_of_Birth__c', dob);
      }

      String itemId = (String) item.get('id');
      if (String.isNotBlank(itemId) && itemId.startsWith('a')) {
        fields.put('Id', itemId);
        incomingIds.add((Id) itemId);
      }

      Priority_Item__c pi = (Priority_Item__c) JSON.deserialize(
        JSON.serialize(fields),
        Priority_Item__c.class
      );
      toUpsert.add(pi);
    }

    String existingQuery =
      'SELECT Id FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c IN :siblingTypes';
    List<Priority_Item__c> existing = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'siblingTypes' => new List<String>{ 'Sibling Attending', 'Sibling Applying' }
      }
    );

    List<Priority_Item__c> toDelete = new List<Priority_Item__c>();
    for (Priority_Item__c ex : existing) {
      if (!incomingIds.contains(ex.Id)) {
        toDelete.add(ex);
      }
    }

    if (!toDelete.isEmpty()) {
      databaseRepo.deleteSObjects(toDelete);
    }
    if (!toUpsert.isEmpty()) {
      databaseRepo.upsertSObjects(toUpsert, Priority_Item__c.Id);
    }
  }

  @AuraEnabled
  public static void syncEmployeePriority(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String appQuery =
      'SELECT Employee_Priority__c, Employee_First_Name__c,' +
      ' Employee_Last_Name__c, Employee_Workplace__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    IndividualApplication app = (IndividualApplication) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    )[0];

    String existingQuery =
      'SELECT Id FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c = :staffType LIMIT 1';
    List<Priority_Item__c> existing = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'staffType' => 'Parent is Zeta Staff'
      }
    );

    if (app.Employee_Priority__c == true) {
      Map<String, Object> fields = new Map<String, Object>();
      fields.put('Related_Application__c', applicationId);
      fields.put('Priority_Type__c', 'Parent is Zeta Staff');
      fields.put('First_Name__c', app.Employee_First_Name__c);
      fields.put('Last_Name__c', app.Employee_Last_Name__c);
      fields.put('Workplace__c', app.Employee_Workplace__c);

      if (!existing.isEmpty()) {
        fields.put('Id', existing[0].Id);
      }

      Priority_Item__c pi = (Priority_Item__c) JSON.deserialize(
        JSON.serialize(fields),
        Priority_Item__c.class
      );
      databaseRepo.upsertSObjects(new List<Priority_Item__c>{ pi }, Priority_Item__c.Id);
    } else if (!existing.isEmpty()) {
      databaseRepo.deleteSObjects(existing);
    }
  }

  @AuraEnabled
  public static Map<String, String> getPrimaryGuardianAddress(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Primary_Guardian__r.PersonMailingStreet,' +
      ' Primary_Guardian__r.PersonMailingCity,' +
      ' Primary_Guardian__r.PersonMailingState,' +
      ' Primary_Guardian__r.PersonMailingPostalCode' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    if (apps.isEmpty() || apps[0].Primary_Guardian__c == null) {
      return new Map<String, String>();
    }

    Account guardian = apps[0].Primary_Guardian__r;
    Map<String, String> address = new Map<String, String>();
    if (String.isNotBlank(guardian.PersonMailingStreet)) {
      address.put('Guardian_2_Street', guardian.PersonMailingStreet);
    }
    if (String.isNotBlank(guardian.PersonMailingCity)) {
      address.put('Guardian_2_City', guardian.PersonMailingCity);
    }
    if (String.isNotBlank(guardian.PersonMailingState)) {
      address.put('Guardian_2_State', guardian.PersonMailingState);
    }
    if (String.isNotBlank(guardian.PersonMailingPostalCode)) {
      address.put('Guardian_2_Zip', guardian.PersonMailingPostalCode);
    }
    return address;
  }

  /**
   * Returns candidate siblings for the Attending section — Person Accounts that share
   * this application's Primary Guardian (via Account.Primary_Guardian__c, the canonical
   * household relationship) and have at least one active AcademicTermEnrollment
   * (Active__c = true; false when the enrollment is withdrawn). Discovery is driven by the
   * enrollment + the student account's guardian, NOT by whether the sibling has an
   * IndividualApplication — an attending-only sibling has enrollment but no application in
   * the household and must still surface.
   *
   * Each map row contains: accountId, firstName, lastName, selected (true if a Pending
   * "Sibling Attending" Priority_Item__c already exists for this sibling on the current
   * application, keyed by Sibling_Account__c), grade (the Grade_Applied__c from the
   * active-term enrollment for detected rows; null on manually-added rows), and school
   * (the active-term enrollment's Learning_Program__r.School__r.Name for detected rows,
   * or the PI's Sibling_s_Zeta_School__c for manually-added rows).
   */
  @AuraEnabled
  public static List<Map<String, Object>> getAttendingSiblingCandidates(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    // Pass 1: get this app's Primary_Guardian__c and its own AccountId (to exclude the applicant).
    String appQuery =
      'SELECT Primary_Guardian__c, AccountId' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (apps.isEmpty() || apps[0].Primary_Guardian__c == null) {
      return new List<Map<String, Object>>();
    }
    Id guardianId = apps[0].Primary_Guardian__c;
    Id thisAccountId = apps[0].AccountId;

    // Pass 2: discover attending siblings directly from enrollment data — Person Accounts that
    // share this application's Primary Guardian (Account.Primary_Guardian__c) and have an active
    // AcademicTermEnrollment (Active__c = true; false when withdrawn). This is independent of
    // whether the sibling has an IndividualApplication: an attending-only sibling has an
    // enrollment but no application in the household, and must still surface. The applicant's
    // own account is excluded. Order so the active-term enrollment (Term_Active__c = true) wins,
    // so the displayed grade/school come from the current term.
    Map<Id, Map<String, Object>> byAccountId = new Map<Id, Map<String, Object>>();
    Set<Id> activeIds = new Set<Id>();
    Map<Id, String> gradeByLearner = new Map<Id, String>();
    Map<Id, String> schoolByLearner = new Map<Id, String>();
    Map<Id, Id> ateIdByLearner = new Map<Id, Id>();

    String ateQuery =
      'SELECT Id, LearnerAccountId, LearnerAccount.FirstName, LearnerAccount.LastName,' +
      ' Grade_Applied__c, Term_Active__c, Learning_Program__r.School__r.Name' +
      ' FROM AcademicTermEnrollment' +
      ' WHERE LearnerAccount.Primary_Guardian__c = :guardianId' +
      ' AND LearnerAccountId != :thisAccountId' +
      ' AND Active__c = true' +
      ' ORDER BY Term_Active__c DESC NULLS LAST';
    List<AcademicTermEnrollment> ates = (List<AcademicTermEnrollment>) databaseRepo.queryWithBinds(
      ateQuery,
      new Map<String, Object>{ 'guardianId' => guardianId, 'thisAccountId' => thisAccountId }
    );
    for (AcademicTermEnrollment ate : ates) {
      Id learnerId = ate.LearnerAccountId;
      if (learnerId == null) {
        continue;
      }
      activeIds.add(learnerId);
      // First row per learner wins (active term first via ORDER BY) for name + grade + ateId.
      if (!byAccountId.containsKey(learnerId)) {
        byAccountId.put(
          learnerId,
          new Map<String, Object>{
            'accountId' => learnerId,
            'firstName' => ate.LearnerAccount != null ? ate.LearnerAccount.FirstName : null,
            'lastName' => ate.LearnerAccount != null ? ate.LearnerAccount.LastName : null,
            'selected' => false
          }
        );
        gradeByLearner.put(learnerId, ate.Grade_Applied__c);
        ateIdByLearner.put(learnerId, ate.Id);
      }
      // First non-null school per learner wins.
      if (!schoolByLearner.containsKey(learnerId)) {
        String schoolName = ate.Learning_Program__r != null &&
          ate.Learning_Program__r.School__r != null
          ? ate.Learning_Program__r.School__r.Name
          : null;
        if (String.isNotBlank(schoolName)) {
          schoolByLearner.put(learnerId, schoolName);
        }
      }
    }

    // Pass 4: fetch existing Pending "Sibling Attending" items on this application (keyed by
    // Sibling_Account__c). Used to (a) pre-select detected rows that already have an item, and
    // (b) surface manually-added siblings — which have an item but no application/enrollment —
    // as their own selected rows so they remain visible and deselectable on reload.
    String existingAttendingQuery =
      'SELECT Sibling_Account__c, First_Name__c, Last_Name__c, Sibling_s_Zeta_School__c' +
      ' FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c = :attendingType' +
      ' AND Sibling_Account__c != null';
    List<Priority_Item__c> existingAttending = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      existingAttendingQuery,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'attendingType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      }
    );
    Map<Id, Priority_Item__c> existingByAccountId = new Map<Id, Priority_Item__c>();
    for (Priority_Item__c pi : existingAttending) {
      existingByAccountId.put(pi.Sibling_Account__c, pi);
    }

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    // Detected siblings with an active enrollment (pre-selected if an item exists).
    for (Id accountId : byAccountId.keySet()) {
      if (activeIds.contains(accountId)) {
        Map<String, Object> row = byAccountId.get(accountId);
        row.put('selected', existingByAccountId.containsKey(accountId));
        row.put('grade', gradeByLearner.get(accountId));
        row.put('school', schoolByLearner.get(accountId));
        row.put('ateId', ateIdByLearner.get(accountId));
        results.add(row);
      }
    }
    // Manually-added siblings: items whose account was NOT surfaced as a detected row.
    // Grade stays null (no enrollment); school comes from the PI's Sibling_s_Zeta_School__c.
    // ateId stays null (no enrollment drove this row).
    for (Id accountId : existingByAccountId.keySet()) {
      if (!byAccountId.containsKey(accountId) || !activeIds.contains(accountId)) {
        Priority_Item__c pi = existingByAccountId.get(accountId);
        results.add(
          new Map<String, Object>{
            'accountId' => accountId,
            'firstName' => pi.First_Name__c,
            'lastName' => pi.Last_Name__c,
            'school' => pi.Sibling_s_Zeta_School__c,
            'selected' => true,
            'ateId' => null
          }
        );
      }
    }
    return results;
  }

  /**
   * Returns candidate "Applying" siblings — other live (non-Withdrawn/Declined)
   * IndividualApplications under the same Primary Guardian as this application, in the
   * same Application Timeline, excluding this application and its own student Account.
   * Includes Draft, Applied, Eligible, and Waitlisted siblings.
   *
   * Each map row contains: applicationId, accountId, firstName, lastName,
   * gradeApplyingTo, selected (true if a Pending "Sibling Applying" Priority_Item__c
   * already exists on this application for that sibling's applicationId).
   */
  @AuraEnabled
  public static List<Map<String, Object>> getApplyingSiblingCandidates(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String appQuery =
      'SELECT Primary_Guardian__c, AccountId, Application_Timeline__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (
      apps.isEmpty() ||
      apps[0].Primary_Guardian__c == null ||
      apps[0].Application_Timeline__c == null
    ) {
      return new List<Map<String, Object>>();
    }
    Id guardianId = apps[0].Primary_Guardian__c;
    Id thisAccountId = apps[0].AccountId;
    Id timelineId = apps[0].Application_Timeline__c;

    String siblingQuery =
      'SELECT Id, AccountId, Account.FirstName, Account.LastName,' +
      ' Grade_Applying_To__c' +
      ' FROM IndividualApplication' +
      ' WHERE Primary_Guardian__c = :guardianId' +
      ' AND Application_Timeline__c = :timelineId' +
      ' AND Id != :applicationId' +
      ' AND AccountId != null' +
      ' AND AccountId != :thisAccountId' +
      ' AND Status != \'Withdrawn/Declined\'' +
      ' ORDER BY Account.LastName, Account.FirstName';
    List<IndividualApplication> siblingApps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      siblingQuery,
      new Map<String, Object>{
        'guardianId' => guardianId,
        'timelineId' => timelineId,
        'applicationId' => applicationId,
        'thisAccountId' => thisAccountId
      }
    );

    // Collect sibling application IDs to check for existing priority items.
    Set<Id> siblingAppIds = new Set<Id>();
    for (IndividualApplication sa : siblingApps) {
      siblingAppIds.add(sa.Id);
    }

    // Fetch existing "Sibling Applying" items on this application so we can
    // pre-select rows that already have a priority item.
    Set<Id> selectedSiblingAppIds = new Set<Id>();
    if (!siblingAppIds.isEmpty()) {
      String existingApplyingQuery =
        'SELECT Sibling_Application__c FROM Priority_Item__c' +
        ' WHERE Related_Application__c = :applicationId' +
        ' AND Priority_Type__c = :applyingType' +
        ' AND Sibling_Application__c IN :siblingAppIds';
      List<Priority_Item__c> existingApplying = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
        existingApplyingQuery,
        new Map<String, Object>{
          'applicationId' => applicationId,
          'applyingType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
          'siblingAppIds' => siblingAppIds
        }
      );
      for (Priority_Item__c pi : existingApplying) {
        if (pi.Sibling_Application__c != null) {
          selectedSiblingAppIds.add(pi.Sibling_Application__c);
        }
      }
    }

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    for (IndividualApplication sa : siblingApps) {
      results.add(
        new Map<String, Object>{
          'applicationId' => sa.Id,
          'accountId' => sa.AccountId,
          'firstName' => sa.Account != null ? sa.Account.FirstName : null,
          'lastName' => sa.Account != null ? sa.Account.LastName : null,
          'gradeApplyingTo' => sa.Grade_Applying_To__c,
          'selected' => selectedSiblingAppIds.contains(sa.Id)
        }
      );
    }
    return results;
  }

  /**
   * Returns "household" sibling candidates — Student Person Accounts the logged-in
   * guardian already added (via the Add-a-Student flow on wizard Step 1) that do NOT
   * yet have an IndividualApplication in this application's Application Timeline.
   * These are exactly the students who are invisible to getApplyingSiblingCandidates
   * because they have no application yet.
   *
   * Discovery mirrors StudentSelectionController.getStudents: the parent's students are
   * found via AccountContactRelation on the logged-in user's Contact (RecordType
   * 'Student', IsActive = true). The ACR is the only linkage that exists for a
   * not-yet-applied student — createStudent writes an ACR but never sets
   * Account.Primary_Guardian__c, so neither the Primary_Guardian__c lookup nor any
   * Contact-Contact Relationship has been created for them yet. Using the same ACR
   * query as getStudents guarantees this roster matches the Step 1 student list.
   *
   * Imperative (NOT cacheable=true) — the LWC re-runs it after
   * createPlaceholderApplications inserts new apps; a cacheable result would be stale.
   *
   * Each map row contains: accountId, firstName, lastName.
   */
  @AuraEnabled
  public static List<Map<String, Object>> getHouseholdSiblingCandidates(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    // Resolve the logged-in guardian's Contact — the same source the Step 1 roster
    // (StudentSelectionController.getStudents) uses.
    Id contactId = getLoggedInContactId();
    if (contactId == null) {
      return new List<Map<String, Object>>();
    }

    // The source app supplies only the Application Timeline, used for the anti-join.
    String appQuery =
      'SELECT Application_Timeline__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (apps.isEmpty() || apps[0].Application_Timeline__c == null) {
      return new List<Map<String, Object>>();
    }
    Id timelineId = apps[0].Application_Timeline__c;

    // Pass 1: the parent's Student accounts — identical query shape to getStudents.
    String acrQuery =
      'SELECT Account.Id, Account.FirstName, Account.LastName' +
      ' FROM AccountContactRelation' +
      ' WHERE ContactId = :contactId' +
      ' AND Account.RecordType.DeveloperName = \'Student\'' +
      ' AND IsActive = TRUE' +
      ' ORDER BY Account.LastName, Account.FirstName';
    List<AccountContactRelation> relations = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      acrQuery,
      new Map<String, Object>{ 'contactId' => contactId }
    );
    if (relations.isEmpty()) {
      return new List<Map<String, Object>>();
    }

    // Dedup by account (a student could have more than one active ACR to the same
    // guardian), preserving the LastName, FirstName order from the query.
    Map<Id, Map<String, Object>> byAccountId = new Map<Id, Map<String, Object>>();
    for (AccountContactRelation acr : relations) {
      if (acr.Account == null || acr.Account.Id == null) {
        continue;
      }
      if (!byAccountId.containsKey(acr.Account.Id)) {
        byAccountId.put(
          acr.Account.Id,
          new Map<String, Object>{
            'accountId' => acr.Account.Id,
            'firstName' => acr.Account.FirstName,
            'lastName' => acr.Account.LastName
          }
        );
      }
    }

    // Pass 2: drop students who already have an IndividualApplication in this timeline
    // (the current applicant, and any sibling already in the "Applying" list — both
    // surfaced elsewhere). Bounded by the candidate set, so the query stays selective.
    Set<Id> candidateAccountIds = new Set<Id>(byAccountId.keySet());
    String existingQuery =
      'SELECT AccountId FROM IndividualApplication' +
      ' WHERE Application_Timeline__c = :timelineId' +
      ' AND AccountId IN :candidateAccountIds';
    List<IndividualApplication> existing = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'timelineId' => timelineId,
        'candidateAccountIds' => candidateAccountIds
      }
    );
    for (IndividualApplication ia : existing) {
      byAccountId.remove(ia.AccountId);
    }

    // Pass 3: exclude students already enrolled at a Zeta school (active
    // AcademicTermEnrollment). They surface in the "Siblings Attending" section and the
    // Step 1 student picker blocks applying for an already-enrolled student — so offering
    // them a new placeholder application here would be invalid. Same Active__c signal
    // getAttendingSiblingCandidates uses. Bounded by the surviving candidate set.
    if (!byAccountId.isEmpty()) {
      Set<Id> remainingAccountIds = new Set<Id>(byAccountId.keySet());
      String enrolledQuery =
        'SELECT LearnerAccountId FROM AcademicTermEnrollment' +
        ' WHERE LearnerAccountId IN :remainingAccountIds' +
        ' AND Active__c = true';
      List<AcademicTermEnrollment> enrolled = (List<AcademicTermEnrollment>) databaseRepo.queryWithBinds(
        enrolledQuery,
        new Map<String, Object>{ 'remainingAccountIds' => remainingAccountIds }
      );
      for (AcademicTermEnrollment ate : enrolled) {
        if (ate.LearnerAccountId != null) {
          byAccountId.remove(ate.LearnerAccountId);
        }
      }
    }

    return byAccountId.values();
  }

  /**
   * Logged-in community user's Contact Id (mirrors
   * StudentSelectionController.getLoggedInContactId). Used by the household-roster
   * discovery so it sees the same students the Step 1 roster does.
   */
  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }

  /**
   * Selects or deselects a candidate "Sibling Applying" row. Selecting creates a
   * Pending "Sibling Applying" Priority_Item__c on the current application keyed by
   * Sibling_Application__c. Deselecting deletes the matching item. Idempotent —
   * never creates duplicates.
   *
   * applyingCandidateJson shape:
   *   { applicationId, firstName, lastName, gradeApplyingTo }
   */
  @AuraEnabled
  public static void setApplyingSiblingSelected(
    Id applicationId,
    String applyingCandidateJson,
    Boolean selected
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(applyingCandidateJson, 'Sibling candidate JSON is required');

    Map<String, Object> candidate = (Map<String, Object>) JSON.deserializeUntyped(
      applyingCandidateJson
    );
    Id siblingApplicationId = (Id) candidate.get('applicationId');
    Preconditions.checkNotNull(siblingApplicationId, 'Sibling applicationId is required');

    // Look for an existing item with dedup key (Related_Application__c, Sibling_Application__c).
    String existingQuery =
      'SELECT Id FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c = :applyingType' +
      ' AND Sibling_Application__c = :siblingApplicationId' +
      ' LIMIT 1';
    List<Priority_Item__c> existing = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'applyingType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        'siblingApplicationId' => siblingApplicationId
      }
    );

    if (selected == true) {
      if (!existing.isEmpty()) {
        return; // already selected — idempotent no-op
      }
      Map<String, Object> fields = new Map<String, Object>{
        'Related_Application__c' => applicationId,
        'Sibling_Application__c' => siblingApplicationId,
        'Priority_Type__c' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        'Review_Status__c' => PriorityItemConstants.REVIEW_STATUS_PENDING,
        'First_Name__c' => candidate.get('firstName'),
        'Last_Name__c' => candidate.get('lastName')
      };
      Priority_Item__c pi = (Priority_Item__c) JSON.deserialize(
        JSON.serialize(fields),
        Priority_Item__c.class
      );
      databaseRepo.insertSObjects(new List<Priority_Item__c>{ pi });
    } else {
      if (!existing.isEmpty()) {
        databaseRepo.deleteSObjects(existing);
      }
    }
  }

  /**
   * Selects or deselects a candidate "Sibling Attending" row detected from enrollment
   * data. Selecting creates a Pending "Sibling Attending" Priority_Item__c on the current
   * application keyed by Sibling_Account__c. When the candidate carries an ateId
   * (detected from a real AcademicTermEnrollment) it is stamped on
   * Sibling_Academic_Term_Enrollment__c; manually-added siblings have no enrollment and
   * pass null. Deselecting deletes the matching item. Idempotent — never creates
   * duplicates.
   *
   * attendingCandidateJson shape:
   *   { accountId, firstName, lastName, ateId? }
   */
  @AuraEnabled
  public static void setAttendingSiblingSelected(
    Id applicationId,
    String attendingCandidateJson,
    Boolean selected
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(attendingCandidateJson, 'Sibling candidate JSON is required');

    Map<String, Object> candidate = (Map<String, Object>) JSON.deserializeUntyped(
      attendingCandidateJson
    );
    Id siblingAccountId = (Id) candidate.get('accountId');
    Preconditions.checkNotNull(siblingAccountId, 'Sibling accountId is required');
    Id ateId = ObjectUtil.safeValueOfId(candidate.get('ateId'));

    // Dedup key: (Related_Application__c, Priority_Type__c, Sibling_Account__c).
    String existingQuery =
      'SELECT Id FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c = :attendingType' +
      ' AND Sibling_Account__c = :siblingAccountId' +
      ' LIMIT 1';
    List<Priority_Item__c> existing = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'attendingType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
        'siblingAccountId' => siblingAccountId
      }
    );

    if (selected == true) {
      if (!existing.isEmpty()) {
        return; // already selected — idempotent no-op
      }
      Map<String, Object> fields = new Map<String, Object>{
        'Related_Application__c' => applicationId,
        'Sibling_Account__c' => siblingAccountId,
        'Sibling_Academic_Term_Enrollment__c' => ateId,
        'Priority_Type__c' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
        'Review_Status__c' => PriorityItemConstants.REVIEW_STATUS_PENDING,
        'First_Name__c' => candidate.get('firstName'),
        'Last_Name__c' => candidate.get('lastName')
      };
      Priority_Item__c pi = (Priority_Item__c) JSON.deserialize(
        JSON.serialize(fields),
        Priority_Item__c.class
      );
      databaseRepo.insertSObjects(new List<Priority_Item__c>{ pi });
    } else {
      if (!existing.isEmpty()) {
        databaseRepo.deleteSObjects(existing);
      }
    }
  }

  /**
   * Adds a manually-entered attending sibling who was not detected by the enrollment
   * query. Creates a Student Person Account, an AccountContactRelation linking the new
   * sibling account to the guardian's Contact, and a Pending "Sibling Attending"
   * Priority_Item__c keyed by Sibling_Account__c = the new account Id (the same dedup
   * key detected siblings use). Returns the new account Id.
   *
   * A Person Account (not a plain Contact) is created because the guardian is itself a
   * Person Account, and Salesforce forbids parenting a Contact directly under a Person
   * Account. This mirrors the canonical pattern in
   * {@link StudentSelectionController#createStudent}.
   *
   * addAttendingJson shape:
   *   { firstName, lastName, birthdate, zetaSchool }
   */
  @AuraEnabled
  public static Id addManualAttendingSibling(Id applicationId, String addAttendingJson) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(addAttendingJson, 'Sibling JSON is required');

    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(addAttendingJson);
    String firstName = (String) input.get('firstName');
    String lastName = (String) input.get('lastName');
    String birthdate = (String) input.get('birthdate');
    String zetaSchool = (String) input.get('zetaSchool');
    Preconditions.checkNotBlank(firstName, 'First name is required');
    Preconditions.checkNotBlank(lastName, 'Last name is required');
    // The Student record type requires PersonBirthdate (same validation rule as the
    // applying add-form), so DOB is mandatory here too.
    Preconditions.checkNotBlank(birthdate, 'Date of birth is required');

    // Resolve guardian's accountId from the application.
    String appQuery =
      'SELECT Primary_Guardian__c' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(
      !apps.isEmpty() && apps[0].Primary_Guardian__c != null,
      'Could not resolve Primary Guardian for this application'
    );
    Id guardianAccountId = apps[0].Primary_Guardian__c;

    // Get the guardian's PersonContactId (the ContactId side of the ACR).
    List<Account> guardianAccts = (List<Account>) databaseRepo.queryWithBinds(
      'SELECT PersonContactId FROM Account WHERE Id = :guardianAccountId LIMIT 1',
      new Map<String, Object>{ 'guardianAccountId' => guardianAccountId }
    );
    Preconditions.checkArgument(
      !guardianAccts.isEmpty() && guardianAccts[0].PersonContactId != null,
      'Could not resolve guardian Contact'
    );
    Id guardianContactId = guardianAccts[0].PersonContactId;

    dupGuard.assertNoDuplicate(firstName, lastName, birthdate, guardianContactId);

    // Create the sibling as a Student Person Account (mirrors
    // StudentSelectionController.createStudent). The guardian is a Person Account, so a
    // plain Contact cannot be parented under it — a Person Account is required.
    Id studentRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Student')
      .getRecordTypeId();
    Map<String, Object> accountFields = new Map<String, Object>{
      'RecordTypeId' => studentRtId,
      'FirstName' => firstName,
      'LastName' => lastName
    };
    if (String.isNotBlank(birthdate)) {
      accountFields.put('PersonBirthdate', birthdate);
    }
    Account siblingAccount = (Account) JSON.deserialize(
      JSON.serialize(accountFields),
      Account.class
    );
    databaseRepo.insertSObjects(new List<Account>{ siblingAccount });

    // Link the new sibling account to the guardian's Contact via AccountContactRelation
    // (AccountId = new sibling account, ContactId = guardian contact), matching the
    // household-relationship pattern in StudentSelectionController.createStudent.
    AccountContactRelation acr = new AccountContactRelation(
      AccountId = siblingAccount.Id,
      ContactId = guardianContactId,
      IsActive = true
    );
    databaseRepo.insertSObjects(new List<AccountContactRelation>{ acr });

    // Create the Pending "Sibling Attending" priority item keyed by Sibling_Account__c =
    // the new account Id, so manual entries share the same dedup key as detected ones and
    // toggle/deselect through setAttendingSiblingSelected uniformly.
    Map<String, Object> priorityFields = new Map<String, Object>{
      'Related_Application__c' => applicationId,
      'Sibling_Account__c' => siblingAccount.Id,
      'Priority_Type__c' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING,
      'Review_Status__c' => PriorityItemConstants.REVIEW_STATUS_PENDING,
      'First_Name__c' => firstName,
      'Last_Name__c' => lastName
    };
    if (String.isNotBlank(zetaSchool)) {
      priorityFields.put('Sibling_s_Zeta_School__c', zetaSchool);
      priorityFields.put('Zeta_School__c', zetaSchool);
    }
    Priority_Item__c pi = (Priority_Item__c) JSON.deserialize(
      JSON.serialize(priorityFields),
      Priority_Item__c.class
    );
    databaseRepo.insertSObjects(new List<Priority_Item__c>{ pi });

    return siblingAccount.Id;
  }

  /**
   * Creates a Student Account + AccountContactRelation (via
   * {@link StudentSelectionController#createStudent}), a Draft
   * {@link IndividualApplication} for the new sibling, AND a Pending
   * "Sibling Applying" Priority_Item__c on the CURRENT application referencing
   * the new sibling app. Only the current-app side is created here; the
   * reciprocal item on the sibling's own app is handled by separate automation.
   * Returns the new accountId and applicationId so the LWC can show a
   * confirmation.
   *
   * studentJson shape:
   *   { firstName, lastName, birthdate, gender, currentGrade, gradeApplyingTo }
   *
   * Required for the IndividualApplication insert: gradeApplyingTo. The other
   * IndividualApplication fields are populated from this application's
   * Primary_Guardian__c and Application_Timeline__c.
   *
   * ContactId is set to the NEW student's person Contact (the Contact behind
   * the newly-created student's person Account), matching the canonical
   * pattern in ZetaApplicationController.createApplication. It is NOT the
   * parent application's ContactId (the current applicant). SubmittedByContactId
   * is copied from the parent app (resolves to the guardian; the dashboard
   * depends on it).
   */
  @AuraEnabled
  public static Map<String, Id> createSiblingDraftApplication(
    Id applicationId,
    String studentJson
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(studentJson, 'Student JSON is required');

    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(studentJson);
    String gradeApplyingTo = (String) input.get('gradeApplyingTo');
    Preconditions.checkNotBlank(gradeApplyingTo, 'Grade Applying To is required');

    // 1) Create the Student Account + AccountContactRelation. The student-
    //    create payload only needs the basics — the inline form collects the
    //    grades alongside, which we use below for the application insert.
    Map<String, Object> createStudentInput = new Map<String, Object>{
      'firstName' => input.get('firstName'),
      'lastName' => input.get('lastName'),
      'birthdate' => input.get('birthdate'),
      'gender' => input.get('gender')
    };
    Id newAccountId = StudentSelectionController.createStudent(JSON.serialize(createStudentInput));

    // 2) Look up this application's Primary Guardian + Application Timeline so
    //    the sibling shell ends up in the same household / cycle.
    String parentQuery =
      'SELECT Primary_Guardian__c, Application_Timeline__c, SubmittedByContactId' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> parents = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      parentQuery,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(
      !parents.isEmpty() && parents[0].Application_Timeline__c != null,
      'Could not resolve Application Timeline for sibling shell'
    );
    IndividualApplication parent = parents[0];

    // 2b) Resolve the NEW student's person Contact. IndividualApplication.ContactId
    //     must be the student's own PersonContactId (the Contact behind the
    //     student's person Account) — NOT the current applicant's contact.
    List<Account> newAccts = (List<Account>) databaseRepo.queryWithBinds(
      'SELECT PersonContactId FROM Account WHERE Id = :acctId LIMIT 1',
      new Map<String, Object>{ 'acctId' => newAccountId }
    );
    Id newStudentContactId = newAccts.isEmpty() ? null : newAccts[0].PersonContactId;

    // 3) Insert the Draft IndividualApplication. JSON-deserialize through the
    //    field map so non-Apex-typed picklists like Status are settable
    //    (matches the canonical pattern in ZetaApplicationController).
    Map<String, Object> appFields = new Map<String, Object>();
    appFields.put('AccountId', newAccountId);
    appFields.put('Application_Timeline__c', parent.Application_Timeline__c);
    appFields.put('Primary_Guardian__c', parent.Primary_Guardian__c);
    appFields.put('Grade_Applying_To__c', gradeApplyingTo);
    appFields.put('Status', 'Draft');
    appFields.put('Category', 'Education');
    if (newStudentContactId != null) {
      appFields.put('ContactId', newStudentContactId);
    }
    if (parent.SubmittedByContactId != null) {
      appFields.put('SubmittedByContactId', parent.SubmittedByContactId);
    }
    String currentGrade = (String) input.get('currentGrade');
    if (String.isNotBlank(currentGrade)) {
      appFields.put('Current_Grade__c', currentGrade);
    }
    IndividualApplication shell = (IndividualApplication) JSON.deserialize(
      JSON.serialize(appFields),
      IndividualApplication.class
    );
    databaseRepo.insertSObjects(new List<IndividualApplication>{ shell });

    // 4) Create the "Sibling Applying" priority item on the CURRENT application,
    //    pointing at the just-created sibling application. Review_Status is
    //    Pending so staff review it before it counts toward the lottery. Only
    //    this (current-app) side is created here — the reciprocal item on the
    //    sibling's own application is created by separate automation. The
    //    sibling application is brand-new in this transaction, so the
    //    (Related_Application__c, Sibling_Application__c) pairing is unique by
    //    construction and cannot duplicate an existing item.
    Map<String, Object> priorityFields = new Map<String, Object>{
      'Related_Application__c' => applicationId,
      'Sibling_Application__c' => shell.Id,
      'Priority_Type__c' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
      'Review_Status__c' => PriorityItemConstants.REVIEW_STATUS_PENDING,
      'First_Name__c' => input.get('firstName'),
      'Last_Name__c' => input.get('lastName'),
      'Gender__c' => input.get('gender')
    };
    String siblingDob = (String) input.get('birthdate');
    if (String.isNotBlank(siblingDob)) {
      priorityFields.put('Date_of_Birth__c', siblingDob);
    }
    Priority_Item__c siblingPriority = (Priority_Item__c) JSON.deserialize(
      JSON.serialize(priorityFields),
      Priority_Item__c.class
    );
    databaseRepo.insertSObjects(new List<Priority_Item__c>{ siblingPriority });

    return new Map<String, Id>{ 'accountId' => newAccountId, 'applicationId' => shell.Id };
  }

  /**
   * Bulk-creates placeholder Draft IndividualApplications for household students the
   * guardian selected in the "Siblings in Your Household" roster, plus a Pending
   * "Sibling Applying" Priority_Item__c on the CURRENT application for each — the same
   * records the single-sibling "Add a sibling" path (createSiblingDraftApplication)
   * produces, minus the new-student creation (these Accounts already exist, found via
   * ACR). This makes the household-select path behave identically to "click and add":
   * the new siblings render pre-selected in the "Siblings Also Applying" list on reload.
   *
   * selectionsJson shape: [{ accountId, gradeApplyingTo }, ...] — one per checked row.
   *
   * All-or-nothing: shells insert via the SYSTEM_MODE default (allOrNone = true). If any
   * insert fails, the DmlException surfaces as AuraHandledException to the LWC.
   *
   * Returns { createdApplicationIds: List<Id>, skippedAccountIds: List<Id> } —
   * skipped are selections that already had an IA in this timeline when the server
   * re-checked (defends against a stale roster from a parallel tab).
   */
  @AuraEnabled
  public static Map<String, Object> createPlaceholderApplications(
    Id sourceApplicationId,
    String selectionsJson
  ) {
    Preconditions.checkNotNull(sourceApplicationId, 'Application Id is required');
    Preconditions.checkNotBlank(selectionsJson, 'Selections JSON is required');

    List<Object> rawList = (List<Object>) JSON.deserializeUntyped(selectionsJson);
    Preconditions.checkArgument(!rawList.isEmpty(), 'At least one selection is required');

    // Parse selections → accountId => gradeApplyingTo (last write wins on a dup accountId).
    Map<Id, String> gradeByAccountId = new Map<Id, String>();
    for (Object raw : rawList) {
      Map<String, Object> sel = (Map<String, Object>) raw;
      Id accountId = (Id) sel.get('accountId');
      String gradeApplyingTo = (String) sel.get('gradeApplyingTo');
      Preconditions.checkNotNull(accountId, 'Selection accountId is required');
      Preconditions.checkNotBlank(
        gradeApplyingTo,
        'Grade Applying To is required for each selected sibling'
      );
      gradeByAccountId.put(accountId, gradeApplyingTo);
    }

    // Source-app fields (timeline + guardian + submitter) — same shape as
    // createSiblingDraftApplication step 2.
    String parentQuery =
      'SELECT Primary_Guardian__c, Application_Timeline__c, SubmittedByContactId' +
      ' FROM IndividualApplication WHERE Id = :sourceApplicationId LIMIT 1';
    List<IndividualApplication> parents = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      parentQuery,
      new Map<String, Object>{ 'sourceApplicationId' => sourceApplicationId }
    );
    Preconditions.checkArgument(
      !parents.isEmpty() && parents[0].Application_Timeline__c != null,
      'Could not resolve Application Timeline for the source application'
    );
    IndividualApplication parent = parents[0];

    // Server-side duplicate guard: drop selections that already have an IA in this
    // timeline (stale-roster defense — another tab may have inserted since load).
    Set<Id> selectionAccountIds = new Set<Id>(gradeByAccountId.keySet());
    String existingQuery =
      'SELECT AccountId FROM IndividualApplication' +
      ' WHERE Application_Timeline__c = :timelineId' +
      ' AND AccountId IN :selectionAccountIds';
    List<IndividualApplication> existing = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      existingQuery,
      new Map<String, Object>{
        'timelineId' => parent.Application_Timeline__c,
        'selectionAccountIds' => selectionAccountIds
      }
    );
    List<Id> skippedAccountIds = new List<Id>();
    for (IndividualApplication ia : existing) {
      if (gradeByAccountId.containsKey(ia.AccountId)) {
        gradeByAccountId.remove(ia.AccountId);
        skippedAccountIds.add(ia.AccountId);
      }
    }

    if (gradeByAccountId.isEmpty()) {
      return new Map<String, Object>{
        'createdApplicationIds' => new List<Id>(),
        'skippedAccountIds' => skippedAccountIds
      };
    }

    // Resolve each surviving student's own PersonContactId + name in one query. Each new
    // IA's ContactId must be the STUDENT's own PersonContactId (matches
    // createSiblingDraftApplication step 2b), NOT the source app's ContactId. The name
    // feeds the priority-item First/Last below.
    Set<Id> survivingAccountIds = gradeByAccountId.keySet();
    Map<Id, Account> accountById = new Map<Id, Account>(
      (List<Account>) databaseRepo.queryWithBinds(
        'SELECT Id, PersonContactId, FirstName, LastName FROM Account WHERE Id IN :survivingAccountIds',
        new Map<String, Object>{ 'survivingAccountIds' => survivingAccountIds }
      )
    );

    // Build the Draft shells. orderedAccountIds[i] pairs with shells[i] so we can attach
    // each shell's new Id to the right priority item after the all-or-nothing insert.
    List<Id> orderedAccountIds = new List<Id>();
    List<IndividualApplication> shells = new List<IndividualApplication>();
    for (Id accountId : survivingAccountIds) {
      Account student = accountById.get(accountId);
      Map<String, Object> appFields = new Map<String, Object>();
      appFields.put('AccountId', accountId);
      appFields.put('Application_Timeline__c', parent.Application_Timeline__c);
      appFields.put('Primary_Guardian__c', parent.Primary_Guardian__c);
      appFields.put('Grade_Applying_To__c', gradeByAccountId.get(accountId));
      appFields.put('Status', 'Draft');
      appFields.put('Category', 'Education');
      if (student != null && student.PersonContactId != null) {
        appFields.put('ContactId', student.PersonContactId);
      }
      if (parent.SubmittedByContactId != null) {
        appFields.put('SubmittedByContactId', parent.SubmittedByContactId);
      }
      shells.add(
        (IndividualApplication) JSON.deserialize(
          JSON.serialize(appFields),
          IndividualApplication.class
        )
      );
      orderedAccountIds.add(accountId);
    }
    databaseRepo.insertSObjects(shells);

    // One Pending "Sibling Applying" Priority_Item__c per new shell, on the CURRENT app
    // (mirrors createSiblingDraftApplication step 4). The (Related_Application__c,
    // Sibling_Application__c) pairing is unique by construction — the shells are
    // brand-new this transaction.
    List<Priority_Item__c> priorityItems = new List<Priority_Item__c>();
    List<Id> createdApplicationIds = new List<Id>();
    for (Integer i = 0; i < shells.size(); i++) {
      IndividualApplication shell = shells[i];
      Account student = accountById.get(orderedAccountIds[i]);
      createdApplicationIds.add(shell.Id);
      Map<String, Object> piFields = new Map<String, Object>{
        'Related_Application__c' => sourceApplicationId,
        'Sibling_Application__c' => shell.Id,
        'Priority_Type__c' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        'Review_Status__c' => PriorityItemConstants.REVIEW_STATUS_PENDING,
        'First_Name__c' => student != null ? student.FirstName : null,
        'Last_Name__c' => student != null ? student.LastName : null
      };
      priorityItems.add(
        (Priority_Item__c) JSON.deserialize(JSON.serialize(piFields), Priority_Item__c.class)
      );
    }
    databaseRepo.insertSObjects(priorityItems);

    return new Map<String, Object>{
      'createdApplicationIds' => createdApplicationIds,
      'skippedAccountIds' => skippedAccountIds
    };
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, String> getGuardianDefaults() {
    Id userId = UserInfo.getUserId();

    String userQuery = 'SELECT ContactId FROM User WHERE Id = :userId LIMIT 1';
    List<User> users = (List<User>) databaseRepo.queryWithBinds(
      userQuery,
      new Map<String, Object>{ 'userId' => userId }
    );

    if (users.isEmpty() || users[0].ContactId == null) {
      return new Map<String, String>();
    }

    Id contactId = users[0].ContactId;
    String contactQuery =
      'SELECT FirstName, LastName, Email, MobilePhone,' +
      ' Account.Self_Reported_Zeta_Employee__c' +
      ' FROM Contact WHERE Id = :contactId LIMIT 1';
    List<Contact> contacts = (List<Contact>) databaseRepo.queryWithBinds(
      contactQuery,
      new Map<String, Object>{ 'contactId' => contactId }
    );

    if (contacts.isEmpty()) {
      return new Map<String, String>();
    }

    Contact c = contacts[0];
    Map<String, String> defaults = new Map<String, String>();
    if (String.isNotBlank(c.FirstName)) {
      defaults.put('Guardian_1_First_Name', c.FirstName);
    }
    if (String.isNotBlank(c.LastName)) {
      defaults.put('Guardian_1_Last_Name', c.LastName);
    }
    if (String.isNotBlank(c.Email)) {
      defaults.put('Guardian_1_Email', c.Email);
    }
    if (String.isNotBlank(c.MobilePhone)) {
      defaults.put('Guardian_1_Phone', c.MobilePhone);
    }
    // Pre-check the Zeta-employee indicator (picker defaults to Primary — the
    // running applicant is Guardian 1) when the parent record is flagged as a
    // self-reported Zeta employee. Mirrors ApplicationQuestionController.
    if (c.Account != null && c.Account.Self_Reported_Zeta_Employee__c == true) {
      defaults.put('Employee_Priority', 'true');
      defaults.put('Employee_Priority_Guardian', 'Primary');
    }
    return defaults;
  }
}