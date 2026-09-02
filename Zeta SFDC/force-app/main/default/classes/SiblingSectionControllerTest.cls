@IsTest(IsParallel=true)
private class SiblingSectionControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SiblingSectionController.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void getSiblings_returnsSiblingRecords() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id sibId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Priority_Item__c>{
          new Priority_Item__c(
            Id = sibId,
            Priority_Type__c = 'Sibling Attending',
            First_Name__c = 'Alex',
            Last_Name__c = 'Smith'
          )
        }
      );

    List<Priority_Item__c> result = SiblingSectionController.getSiblings(appId);

    Assert.areEqual(1, result.size());
    Assert.areEqual('Alex', result[0].First_Name__c);
  }

  @IsTest
  private static void getSiblings_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SiblingSectionController.getSiblings(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void saveSiblings_upsertsAndDeletesOrphans() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id existingId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);
    Id orphanId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    String siblingsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'id' => existingId,
          'priorityType' => 'Sibling Attending',
          'firstName' => 'Jane',
          'lastName' => 'Doe',
          'gender' => 'Female',
          'zetaSchool' => null,
          'dateOfBirth' => '2018-05-15'
        }
      }
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Priority_Item__c>{
          new Priority_Item__c(Id = existingId),
          new Priority_Item__c(Id = orphanId)
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.upsertSObjects()).thenReturnVoid();

    SiblingSectionController.saveSiblings(appId, siblingsJson);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.upsertSObjects());
  }

  @IsTest
  private static void saveSiblings_newSiblings_noDelete() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    String siblingsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'priorityType' => 'Sibling Applying',
          'firstName' => 'Sam',
          'lastName' => 'Jones',
          'gender' => 'Male',
          'zetaSchool' => null
        }
      }
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.upsertSObjects()).thenReturnVoid();

    SiblingSectionController.saveSiblings(appId, siblingsJson);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.upsertSObjects());
  }

  @IsTest
  private static void saveSiblings_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SiblingSectionController.saveSiblings(null, '[]');
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void syncEmployeePriority_withPriority_upserts() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Employee_Priority__c = true,
            Employee_First_Name__c = 'Pat',
            Employee_Last_Name__c = 'Garcia',
            Employee_Workplace__c = 'Zeta HQ'
          )
        }
      )
      .thenReturn(new List<Priority_Item__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.upsertSObjects()).thenReturnVoid();

    SiblingSectionController.syncEmployeePriority(appId);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.upsertSObjects());
  }

  @IsTest
  private static void syncEmployeePriority_noPriority_deletesExisting() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Employee_Priority__c = false)
        }
      )
      .thenReturn(new List<Priority_Item__c>{ new Priority_Item__c(Id = piId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();

    SiblingSectionController.syncEmployeePriority(appId);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
  }

  @IsTest
  private static void getPrimaryGuardianAddress_withAddress_returnsFields() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      Primary_Guardian__r = new Account(
        Id = guardianId,
        PersonMailingStreet = '456 Oak Ave',
        PersonMailingCity = 'Brooklyn',
        PersonMailingState = 'NY',
        PersonMailingPostalCode = '11201'
      )
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, String> result = SiblingSectionController.getPrimaryGuardianAddress(appId);

    Assert.areEqual('456 Oak Ave', result.get('Guardian_2_Street'));
    Assert.areEqual('Brooklyn', result.get('Guardian_2_City'));
    Assert.areEqual('NY', result.get('Guardian_2_State'));
    Assert.areEqual('11201', result.get('Guardian_2_Zip'));
    Assert.areEqual(4, result.size());
  }

  @IsTest
  private static void getPrimaryGuardianAddress_noGuardian_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(Id = appId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, String> result = SiblingSectionController.getPrimaryGuardianAddress(appId);

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  private static void getPrimaryGuardianAddress_noApplication_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    Map<String, String> result = SiblingSectionController.getPrimaryGuardianAddress(appId);

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  private static void getPrimaryGuardianAddress_partialAddress_returnsOnlyPopulated() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      Primary_Guardian__r = new Account(
        Id = guardianId,
        PersonMailingStreet = '789 Elm St',
        PersonMailingCity = 'Queens'
      )
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, String> result = SiblingSectionController.getPrimaryGuardianAddress(appId);

    Assert.areEqual('789 Elm St', result.get('Guardian_2_Street'));
    Assert.areEqual('Queens', result.get('Guardian_2_City'));
    Assert.areEqual(2, result.size());
  }

  @IsTest
  private static void getPrimaryGuardianAddress_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SiblingSectionController.getPrimaryGuardianAddress(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void getGuardianDefaults_withContact_returnsDefaults() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<Contact>{
          new Contact(
            Id = contactId,
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane@example.com',
            MobilePhone = '555-1234'
          )
        }
      );

    Map<String, String> result = SiblingSectionController.getGuardianDefaults();

    Assert.areEqual('Jane', result.get('Guardian_1_First_Name'));
    Assert.areEqual('Smith', result.get('Guardian_1_Last_Name'));
    Assert.areEqual('jane@example.com', result.get('Guardian_1_Email'));
    Assert.areEqual('555-1234', result.get('Guardian_1_Phone'));
  }

  @IsTest
  private static void getGuardianDefaults_zetaEmployeeParent_prefillsIndicator() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    // The Account relationship on a Contact is read-only, so build the parent
    // person-account flag via JSON to exercise the cross-object prefill read.
    Contact employeeContact = (Contact) JSON.deserialize(
      '{"attributes":{"type":"Contact"},"Id":"' +
        contactId +
        '","FirstName":"Jane","LastName":"Smith",' +
        '"Account":{"attributes":{"type":"Account"},"Self_Reported_Zeta_Employee__c":true}}',
      Contact.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>{ employeeContact });

    Map<String, String> result = SiblingSectionController.getGuardianDefaults();

    Assert.areEqual(
      'true',
      result.get('Employee_Priority'),
      'A self-reported Zeta-employee parent must pre-check the indicator'
    );
    Assert.areEqual(
      'Primary',
      result.get('Employee_Priority_Guardian'),
      'The running applicant is Guardian 1, so the picker defaults to Primary'
    );
  }

  @IsTest
  private static void getGuardianDefaults_noContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    Map<String, String> result = SiblingSectionController.getGuardianDefaults();

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  private static void getGuardianDefaults_noUser_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>());

    Map<String, String> result = SiblingSectionController.getGuardianDefaults();

    Assert.isTrue(result.isEmpty());
  }

  @IsTest
  private static void getAttendingSiblingCandidates_returnsSiblingsWithActiveEnrollment() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id ateId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      AccountId = thisAccountId
    );

    // ATE: active enrollment for a sibling Person Account under this guardian, carrying the
    // learner's name + grade + school. Active__c/Term_Active__c and the nested LearnerAccount /
    // Learning_Program__r.School__r.Name relationships are read-only, so build via JSON.deserialize.
    AcademicTermEnrollment ate = (AcademicTermEnrollment) JSON.deserialize(
      '{"Id":"' +
        ateId +
        '","LearnerAccountId":"' +
        siblingAccountId +
        '","Active__c":true,"Term_Active__c":true,"Grade_Applied__c":"Grade 3",' +
        '"LearnerAccount":{"FirstName":"Alex","LastName":"Smith"},' +
        '"Learning_Program__r":{"School__r":{"Name":"Zeta Inwood Elementary"}}}',
      AcademicTermEnrollment.class
    );

    // Query order: Pass 1 (this app), Pass 2 (attending-sibling ATEs), Pass 4 (existing PIs).
    // No existing attending priority items — sibling is not pre-selected.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app })
      .thenReturn(new List<AcademicTermEnrollment>{ ate })
      .thenReturn(new List<Priority_Item__c>());

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(1, result.size());
    Assert.areEqual(siblingAccountId, result[0].get('accountId'));
    Assert.areEqual('Alex', result[0].get('firstName'));
    Assert.areEqual('Smith', result[0].get('lastName'));
    Assert.areEqual(false, result[0].get('selected'), 'Not yet selected — no existing PI');
    Assert.areEqual(
      'Grade 3',
      result[0].get('grade'),
      'Detected attending row carries the active-term grade'
    );
    Assert.areEqual(
      'Zeta Inwood Elementary',
      result[0].get('school'),
      'Detected attending row carries the active-term enrollment school name'
    );
    Assert.areEqual(
      ateId,
      result[0].get('ateId'),
      'Detected attending row carries the driving ATE Id so the priority insert can stamp Sibling_Academic_Term_Enrollment__c'
    );
    Assert.isFalse(
      result[0].containsKey('dateOfBirth'),
      'Date of birth must not be returned for the attending list'
    );
  }

  @IsTest
  private static void getAttendingSiblingCandidates_surfacesSiblingWithActiveEnrollmentButNoApplication() {
    // Regression: an attending-only sibling — a Person Account sharing this guardian with an
    // active AcademicTermEnrollment but NO IndividualApplication in the household — must still
    // surface. Discovery is enrollment-based (LearnerAccount.Primary_Guardian__c), so the
    // absence of a sibling application is irrelevant: the ATE query alone returns the row.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id ateId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      AccountId = thisAccountId
    );

    // Active enrollment for a sibling who has no application. Grade_Applied__c is null here
    // (mirrors real data), so the row should carry only the school as its detail.
    AcademicTermEnrollment ate = (AcademicTermEnrollment) JSON.deserialize(
      '{"Id":"' +
        ateId +
        '","LearnerAccountId":"' +
        siblingAccountId +
        '","Active__c":true,"Term_Active__c":true,' +
        '"LearnerAccount":{"FirstName":"Rosie","LastName":"Jetson"},' +
        '"Learning_Program__r":{"School__r":{"Name":"Zeta Bronx Mount Eden Elementary"}}}',
      AcademicTermEnrollment.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app })
      .thenReturn(new List<AcademicTermEnrollment>{ ate })
      .thenReturn(new List<Priority_Item__c>());

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(1, result.size(), 'Attending-only sibling (no application) must surface');
    Assert.areEqual(siblingAccountId, result[0].get('accountId'));
    Assert.areEqual('Rosie', result[0].get('firstName'));
    Assert.areEqual('Jetson', result[0].get('lastName'));
    Assert.areEqual(false, result[0].get('selected'));
    Assert.areEqual(
      null,
      result[0].get('grade'),
      'Grade is null when the enrollment has no Grade_Applied__c'
    );
    Assert.areEqual('Zeta Bronx Mount Eden Elementary', result[0].get('school'));
    Assert.areEqual(
      ateId,
      result[0].get('ateId'),
      'Attending-only sibling carries the driving ATE Id'
    );
  }

  @IsTest
  private static void getAttendingSiblingCandidates_preSelectsRowsWithExistingPriorityItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id ateId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      AccountId = thisAccountId
    );
    // Pass 4 returns an existing priority item keyed by Sibling_Account__c.
    Priority_Item__c existingPi = (Priority_Item__c) JSON.deserialize(
      '{"Id":"' + piId + '","Sibling_Account__c":"' + siblingAccountId + '"}',
      Priority_Item__c.class
    );

    AcademicTermEnrollment ate = (AcademicTermEnrollment) JSON.deserialize(
      '{"Id":"' +
        ateId +
        '","LearnerAccountId":"' +
        siblingAccountId +
        '","Active__c":true,"Term_Active__c":true,"Grade_Applied__c":"Grade 5",' +
        '"LearnerAccount":{"FirstName":"Jordan","LastName":"Lee"}}',
      AcademicTermEnrollment.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app })
      .thenReturn(new List<AcademicTermEnrollment>{ ate })
      .thenReturn(new List<Priority_Item__c>{ existingPi });

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(1, result.size());
    Assert.areEqual(true, result[0].get('selected'), 'Row should be pre-selected when PI exists');
    Assert.areEqual('Grade 5', result[0].get('grade'), 'Detected row carries its grade');
    Assert.areEqual(ateId, result[0].get('ateId'), 'Pre-selected detected row carries the ATE Id');
  }

  @IsTest
  private static void getAttendingSiblingCandidates_surfacesManualOnlyPriorityItemAsSelectedRow() {
    // A manually-added attending sibling has a Person Account + ACR + Pending PI but no
    // active enrollment, so the enrollment-based discovery (Pass 2) never detects it. It must
    // still surface as its own selected row (from the existing-PI query in Pass 4) so it stays
    // visible/deselectable.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id manualAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      AccountId = thisAccountId
    );

    // The manual sibling's PI references manualAccountId via Sibling_Account__c, with
    // First/Last name + Sibling_s_Zeta_School__c carried for display.
    Priority_Item__c manualPi = (Priority_Item__c) JSON.deserialize(
      '{"Id":"' +
        piId +
        '","Sibling_Account__c":"' +
        manualAccountId +
        '","First_Name__c":"Taylor","Last_Name__c":"Morgan",' +
        '"Sibling_s_Zeta_School__c":"Zeta Bronx Mount Eden Elementary"}',
      Priority_Item__c.class
    );

    // Pass 2 (attending-sibling ATE query) returns nothing — no active enrollment for this
    // household; Pass 4 returns the manual PI.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app })
      .thenReturn(new List<AcademicTermEnrollment>())
      .thenReturn(new List<Priority_Item__c>{ manualPi });

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(1, result.size(), 'Manual-only PI should surface as a row');
    Assert.areEqual(manualAccountId, result[0].get('accountId'));
    Assert.areEqual('Taylor', result[0].get('firstName'));
    Assert.areEqual('Morgan', result[0].get('lastName'));
    Assert.areEqual(true, result[0].get('selected'), 'Manual sibling row is selected');
    Assert.areEqual(
      'Zeta Bronx Mount Eden Elementary',
      result[0].get('school'),
      'Manual row carries the PI Sibling_s_Zeta_School__c as its school'
    );
    Assert.isNull(
      result[0].get('ateId'),
      'Manual-only row has no driving ATE — ateId must be null'
    );
  }

  @IsTest
  private static void getAttendingSiblingCandidates_excludesSiblingsWithoutActiveEnrollment() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Primary_Guardian__c = guardianId,
      AccountId = thisAccountId
    );

    // No active ATEs returned — no attending sibling is detected. Pass 4 (existing-PI query)
    // still runs but returns nothing, so there are no manual rows to surface either.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app })
      .thenReturn(new List<AcademicTermEnrollment>())
      .thenReturn(new List<Priority_Item__c>());

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(0, result.size());
  }

  @IsTest
  private static void getAttendingSiblingCandidates_noPrimaryGuardian_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    IndividualApplication app = new IndividualApplication(Id = appId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    List<Map<String, Object>> result = SiblingSectionController.getAttendingSiblingCandidates(
      appId
    );

    Assert.areEqual(0, result.size());
  }

  @IsTest
  private static void getAttendingSiblingCandidates_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SiblingSectionController.getAttendingSiblingCandidates(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void getApplyingSiblingCandidates_returnsLiveApps_underSameGuardianAndTimeline() {
    // Requirement: the "also applying" candidate set now includes any live (non
    // Withdrawn/Declined) sibling application in the same timeline under the same
    // guardian — Draft AND Applied (and Eligible/Waitlisted) — not Draft only.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id draftAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id draftAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id appliedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appliedAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // The sibling query mock returns the records the new WHERE clause (Status !=
    // 'Withdrawn/Declined', no AppliedDate restriction) would surface: a Draft sibling
    // (Susy, no AppliedDate) and an Applied sibling (Harry, with AppliedDate). Ordered
    // by Account.LastName, Account.FirstName.
    // Pass 3: no existing "Sibling Applying" PI items — both rows unselected.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            AccountId = thisAccountId,
            Application_Timeline__c = timelineId
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appliedAppId,
            AccountId = appliedAccountId,
            Status = 'Applied',
            AppliedDate = Date.today(),
            Grade_Applying_To__c = '5',
            Account = new Account(FirstName = 'Harry', LastName = 'Aaronson')
          ),
          new IndividualApplication(
            Id = draftAppId,
            AccountId = draftAccountId,
            Status = 'Draft',
            Grade_Applying_To__c = '3',
            Account = new Account(FirstName = 'Susy', LastName = 'Simpson')
          )
        }
      )
      .thenReturn(new List<Priority_Item__c>());

    List<Map<String, Object>> result = SiblingSectionController.getApplyingSiblingCandidates(appId);

    // Both the Applied sibling and the Draft sibling are returned and mapped.
    Assert.areEqual(2, result.size());

    Set<Id> returnedAppIds = new Set<Id>();
    for (Map<String, Object> row : result) {
      returnedAppIds.add((Id) row.get('applicationId'));
    }
    Assert.isTrue(
      returnedAppIds.contains(appliedAppId),
      'Applied sibling application should be included as an "also applying" candidate'
    );
    Assert.isTrue(
      returnedAppIds.contains(draftAppId),
      'Draft sibling application should still be included as an "also applying" candidate'
    );

    // Mapping is preserved (order follows the mocked query: Harry then Susy).
    Assert.areEqual(appliedAppId, result[0].get('applicationId'));
    Assert.areEqual(appliedAccountId, result[0].get('accountId'));
    Assert.areEqual('Harry', result[0].get('firstName'));
    Assert.areEqual('5', result[0].get('gradeApplyingTo'));
    Assert.areEqual(false, result[0].get('selected'), 'No existing PI — not pre-selected');
    Assert.areEqual('Susy', result[1].get('firstName'));
    Assert.areEqual('3', result[1].get('gradeApplyingTo'));
  }

  @IsTest
  private static void getApplyingSiblingCandidates_preSelectsRowsWithExistingPriorityItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            AccountId = thisAccountId,
            Application_Timeline__c = timelineId
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = siblingAppId,
            AccountId = siblingAccountId,
            Status = 'Draft',
            Grade_Applying_To__c = '2',
            Account = new Account(FirstName = 'Robin', LastName = 'Doe')
          )
        }
      )
      .thenReturn(
        new List<Priority_Item__c>{
          new Priority_Item__c(
            Id = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType),
            Sibling_Application__c = siblingAppId
          )
        }
      );

    List<Map<String, Object>> result = SiblingSectionController.getApplyingSiblingCandidates(appId);

    Assert.areEqual(1, result.size());
    Assert.areEqual(
      true,
      result[0].get('selected'),
      'Row should be pre-selected when a matching PI exists'
    );
  }

  @IsTest
  private static void getApplyingSiblingCandidates_excludesWithdrawnDeclined() {
    // The candidate query filters out Withdrawn/Declined siblings via its WHERE clause
    // (Status != 'Withdrawn/Declined'), so such an application never reaches the result
    // set. We model the post-filter query result: only the live Draft sibling survives,
    // and the Withdrawn/Declined sibling is absent from the controller output.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id thisAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id draftAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id draftAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id withdrawnAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            AccountId = thisAccountId,
            Application_Timeline__c = timelineId
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = draftAppId,
            AccountId = draftAccountId,
            Status = 'Draft',
            Grade_Applying_To__c = '3',
            Account = new Account(FirstName = 'Susy', LastName = 'Simpson')
          )
        }
      )
      .thenReturn(new List<Priority_Item__c>());

    List<Map<String, Object>> result = SiblingSectionController.getApplyingSiblingCandidates(appId);

    Assert.areEqual(1, result.size());
    Assert.areEqual(draftAppId, result[0].get('applicationId'));
    for (Map<String, Object> row : result) {
      Assert.areNotEqual(
        withdrawnAppId,
        row.get('applicationId'),
        'Withdrawn/Declined sibling application must not appear in the candidate list'
      );
    }
  }

  @IsTest
  private static void getApplyingSiblingCandidates_noPrimaryGuardian_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Assert.isTrue(SiblingSectionController.getApplyingSiblingCandidates(appId).isEmpty());
  }

  @IsTest
  private static void getApplyingSiblingCandidates_noTimeline_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Primary_Guardian__c = guardianId)
        }
      );

    Assert.isTrue(SiblingSectionController.getApplyingSiblingCandidates(appId).isEmpty());
  }

  @IsTest
  private static void getApplyingSiblingCandidates_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.getApplyingSiblingCandidates(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void createSiblingDraftApplication_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.createSiblingDraftApplication(null, '{}');
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void createSiblingDraftApplication_blankJson_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    try {
      SiblingSectionController.createSiblingDraftApplication(appId, '');
      Assert.fail('Should throw for blank JSON');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Student JSON'));
    }
  }

  @IsTest
  private static void createSiblingDraftApplication_setsContactIdToNewStudentContact() {
    // Both controllers must share the same mock so the queryWithBinds /
    // insertSObjects call sequences are unified across the full flow:
    // StudentSelectionController.createStudent runs first (a User query +
    // Account & ACR inserts), then SiblingSectionController resolves the parent
    // app, then the NEW student's PersonContactId, then inserts the shell.
    DATABASE_REPO_MOCK.reset();
    StudentSelectionController.databaseRepo = DATABASE_REPO_MOCK;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id loggedInContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // The current applicant's (parent app's) submitted-by contact — must NOT
    // leak onto the new sibling app's ContactId.
    Id parentSubmittedByContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // The NEW student's own person contact — this is what ContactId must equal.
    Id newStudentContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    // queryWithBinds sequence (call order across BOTH controllers):
    //   1) createStudent -> getLoggedInContactId() -> User
    //   2) createSiblingDraftApplication -> parent IndividualApplication
    //   3) createSiblingDraftApplication -> new student's Account.PersonContactId
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = loggedInContactId) })
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            Application_Timeline__c = timelineId,
            SubmittedByContactId = parentSubmittedByContactId
          )
        }
      )
      .thenReturn(
        new List<Account>{
          // PersonContactId is read-only; set it via JSON deserialization
          // (mirrors ZetaApplicationControllerQueryTest).
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + newStudentContactId + '"}',
            Account.class
          )
        }
      );

    // insertSObjects sequence: Account, ACR (createStudent), the sibling
    // IndividualApplication shell, then the Sibling Applying priority item.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid()
      .thenReturnVoid()
      .thenReturnVoid();

    String studentJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'Susy',
        'lastName' => 'Simpson',
        'birthdate' => '2018-05-15',
        'gender' => 'Female',
        'gradeApplyingTo' => '3'
      }
    );

    SiblingSectionController.createSiblingDraftApplication(appId, studentJson);

    // The third insertSObjects call is the sibling IndividualApplication shell.
    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(
      4,
      inserts.size(),
      'Account, ACR, sibling app, and sibling priority item should each be inserted'
    );
    List<SObject> shellList = (List<SObject>) inserts[2].get('sobjects');
    IndividualApplication shell = (IndividualApplication) shellList[0];

    Assert.areEqual(
      newStudentContactId,
      shell.ContactId,
      'Sibling app ContactId must be the NEW student\'s person contact'
    );
    Assert.areNotEqual(
      parentSubmittedByContactId,
      shell.ContactId,
      'Sibling app ContactId must NOT be the parent applicant\'s contact'
    );
    Assert.areEqual(
      parentSubmittedByContactId,
      shell.SubmittedByContactId,
      'SubmittedByContactId is still copied from the parent app (resolves to the guardian)'
    );

    // The fourth insert is the "Sibling Applying" priority item created for the
    // CURRENT application (newly-added-only; reciprocal handled by automation).
    List<SObject> priorityList = (List<SObject>) inserts[3].get('sobjects');
    Priority_Item__c priority = (Priority_Item__c) priorityList[0];
    Assert.areEqual(
      appId,
      priority.Related_Application__c,
      'Priority item must belong to the current application'
    );
    Assert.areEqual(
      'Sibling Applying',
      priority.Priority_Type__c,
      'Priority type must be Sibling Applying'
    );
    Assert.areEqual(
      'Pending',
      priority.Review_Status__c,
      'New sibling priority items must be Pending review'
    );
    Assert.areEqual(
      'Susy',
      priority.First_Name__c,
      'Priority item carries the new sibling\'s first name'
    );
  }

  @IsTest
  private static void createSiblingDraftApplication_missingGrade_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    try {
      SiblingSectionController.createSiblingDraftApplication(
        appId,
        '{"firstName":"X","lastName":"Y"}'
      );
      Assert.fail('Should throw when gradeApplyingTo is missing');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Grade Applying To'));
    }
  }

  // ─── setApplyingSiblingSelected ───────────────────────────────────────────

  @IsTest
  private static void setApplyingSiblingSelected_select_createsPendingItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // No existing item → select should insert a new one.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'applicationId' => siblingAppId,
        'firstName' => 'Susy',
        'lastName' => 'Simpson'
      }
    );
    SiblingSectionController.setApplyingSiblingSelected(appId, candidateJson, true);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(1, inserts.size(), 'One insert should be made');
    List<SObject> inserted = (List<SObject>) inserts[0].get('sobjects');
    Priority_Item__c pi = (Priority_Item__c) inserted[0];
    Assert.areEqual(appId, pi.Related_Application__c);
    Assert.areEqual(siblingAppId, pi.Sibling_Application__c);
    Assert.areEqual('Sibling Applying', pi.Priority_Type__c);
    Assert.areEqual('Pending', pi.Review_Status__c);
    Assert.areEqual('Susy', pi.First_Name__c);
  }

  @IsTest
  private static void setApplyingSiblingSelected_select_idempotent_noInsertIfAlreadyExists() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    // Existing item present → re-selecting must not insert a duplicate.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>{ new Priority_Item__c(Id = piId) });

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'applicationId' => siblingAppId,
        'firstName' => 'X',
        'lastName' => 'Y'
      }
    );
    SiblingSectionController.setApplyingSiblingSelected(appId, candidateJson, true);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void setApplyingSiblingSelected_deselect_deletesItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>{ new Priority_Item__c(Id = piId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'applicationId' => siblingAppId,
        'firstName' => 'X',
        'lastName' => 'Y'
      }
    );
    SiblingSectionController.setApplyingSiblingSelected(appId, candidateJson, false);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void setApplyingSiblingSelected_deselect_noOpWhenNoneExist() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>());

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'applicationId' => siblingAppId,
        'firstName' => 'X',
        'lastName' => 'Y'
      }
    );
    SiblingSectionController.setApplyingSiblingSelected(appId, candidateJson, false);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void setApplyingSiblingSelected_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.setApplyingSiblingSelected(
        null,
        '{"applicationId":"001000000000001AAA","firstName":"X","lastName":"Y"}',
        true
      );
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  // ─── setAttendingSiblingSelected ─────────────────────────────────────────

  @IsTest
  private static void setAttendingSiblingSelected_select_createsPendingItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id ateId = SObjectIds.generateFakeId(Schema.AcademicTermEnrollment.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'accountId' => siblingAccountId,
        'firstName' => 'Jordan',
        'lastName' => 'Lee',
        'ateId' => ateId
      }
    );
    SiblingSectionController.setAttendingSiblingSelected(appId, candidateJson, true);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(1, inserts.size());
    List<SObject> inserted = (List<SObject>) inserts[0].get('sobjects');
    Priority_Item__c pi = (Priority_Item__c) inserted[0];
    Assert.areEqual(appId, pi.Related_Application__c);
    Assert.areEqual('Sibling Attending', pi.Priority_Type__c);
    Assert.areEqual('Pending', pi.Review_Status__c);
    Assert.areEqual('Jordan', pi.First_Name__c);
    Assert.areEqual(
      ateId,
      pi.Sibling_Academic_Term_Enrollment__c,
      'Detected sibling carries the driving ATE; stamp it on the inserted PI'
    );
  }

  @IsTest
  private static void setAttendingSiblingSelected_select_withoutAteId_leavesEnrollmentFieldNull() {
    // Manual-entry path: addManualAttendingSibling fronts this path with no driving ATE,
    // and the LWC passes ateId: null. The inserted PI must leave Sibling_Academic_Term_Enrollment__c
    // unset rather than refusing to insert.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'accountId' => siblingAccountId,
        'firstName' => 'Jordan',
        'lastName' => 'Lee',
        'ateId' => null
      }
    );
    SiblingSectionController.setAttendingSiblingSelected(appId, candidateJson, true);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(1, inserts.size());
    List<SObject> inserted = (List<SObject>) inserts[0].get('sobjects');
    Priority_Item__c pi = (Priority_Item__c) inserted[0];
    Assert.isNull(
      pi.Sibling_Academic_Term_Enrollment__c,
      'No driving ATE — Sibling_Academic_Term_Enrollment__c must stay null'
    );
  }

  @IsTest
  private static void setAttendingSiblingSelected_select_idempotent_noInsertIfAlreadyExists() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>{ new Priority_Item__c(Id = piId) });

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'accountId' => siblingAccountId,
        'firstName' => 'Jordan',
        'lastName' => 'Lee'
      }
    );
    SiblingSectionController.setAttendingSiblingSelected(appId, candidateJson, true);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void setAttendingSiblingSelected_deselect_deletesItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id siblingAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id piId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Priority_Item__c>{ new Priority_Item__c(Id = piId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();

    String candidateJson = JSON.serialize(
      new Map<String, Object>{
        'accountId' => siblingAccountId,
        'firstName' => 'Jordan',
        'lastName' => 'Lee'
      }
    );
    SiblingSectionController.setAttendingSiblingSelected(appId, candidateJson, false);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void setAttendingSiblingSelected_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.setAttendingSiblingSelected(
        null,
        '{"accountId":"001000000000001AAA","firstName":"X","lastName":"Y"}',
        true
      );
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  // ─── addManualAttendingSibling ────────────────────────────────────────────

  @IsTest
  private static void addManualAttendingSibling_duplicate_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Primary_Guardian__c = guardianAccountId)
        }
      )
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"Id":"' + guardianAccountId + '","PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      );

    DuplicateStudentValidationServiceMock guardMock = new DuplicateStudentValidationServiceMock();
    guardMock.when(guardMock.method.assertNoDuplicate())
      .thenThrow(new AuraHandledException('duplicate'));
    SiblingSectionController.dupGuard = guardMock;

    String addJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'Taylor',
        'lastName' => 'Morgan',
        'birthdate' => '2016-09-01',
        'zetaSchool' => 'Zeta Charter School - Brooklyn'
      }
    );

    AssertThrows.Throwing throwing = AssertThrows.with(AuraHandledException.class);

    try {
      SiblingSectionController.addManualAttendingSibling(appId, addJson);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
    SiblingSectionController.dupGuard = new DuplicateStudentValidationServiceImpl();
  }
  @IsTest
  private static void addManualAttendingSibling_createsPersonAccountAcrAndPriorityItem() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // Pass 1: app query → guardianAccountId
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Primary_Guardian__c = guardianAccountId)
        }
      )
      // Pass 2: guardian Account → PersonContactId
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"Id":"' + guardianAccountId + '","PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid()
      .thenReturnVoid();

    String addJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'Taylor',
        'lastName' => 'Morgan',
        'birthdate' => '2016-09-01',
        'zetaSchool' => 'Zeta Charter School - Brooklyn'
      }
    );
    Id returnedAccountId = SiblingSectionController.addManualAttendingSibling(appId, addJson);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(
      3,
      inserts.size(),
      'Person Account, ACR, and Priority_Item__c should each be inserted'
    );

    // First insert: a Student Person Account (not a plain Contact).
    List<SObject> accountInsert = (List<SObject>) inserts[0].get('sobjects');
    Account newAccount = (Account) accountInsert[0];
    Assert.areEqual('Taylor', newAccount.FirstName);
    Assert.areEqual('Morgan', newAccount.LastName);
    Assert.areEqual(
      Date.newInstance(2016, 9, 1),
      newAccount.PersonBirthdate,
      'PersonBirthdate must be set (Student record type requires it)'
    );
    Id expectedRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Student')
      .getRecordTypeId();
    Assert.areEqual(
      expectedRtId,
      newAccount.RecordTypeId,
      'Manual attending sibling must be created with the Student record type'
    );

    // The method returns the new account Id (mock leaves Id null, but it must be the
    // Account record's Id — verified by reference equality below on ACR/PI).
    Assert.areEqual(
      newAccount.Id,
      returnedAccountId,
      'addManualAttendingSibling must return the new account Id'
    );

    // Second insert: AccountContactRelation (AccountId = new sibling account,
    // ContactId = guardian contact).
    List<SObject> acrInsert = (List<SObject>) inserts[1].get('sobjects');
    AccountContactRelation acr = (AccountContactRelation) acrInsert[0];
    Assert.areEqual(newAccount.Id, acr.AccountId, 'ACR AccountId must be the new sibling account');
    Assert.areEqual(guardianContactId, acr.ContactId, 'ACR ContactId must be the guardian Contact');
    Assert.isTrue(acr.IsActive);

    // Third insert: Priority_Item__c keyed by Sibling_Account__c = new account Id.
    List<SObject> piInsert = (List<SObject>) inserts[2].get('sobjects');
    Priority_Item__c pi = (Priority_Item__c) piInsert[0];
    Assert.areEqual(appId, pi.Related_Application__c);
    Assert.areEqual(
      newAccount.Id,
      pi.Sibling_Account__c,
      'PI must be keyed by the new sibling account Id (same dedup key as detected siblings)'
    );
    Assert.areEqual('Sibling Attending', pi.Priority_Type__c);
    Assert.areEqual('Pending', pi.Review_Status__c);
    Assert.areEqual('Taylor', pi.First_Name__c);
    Assert.areEqual('Morgan', pi.Last_Name__c);
    Assert.areEqual('Zeta Charter School - Brooklyn', pi.Sibling_s_Zeta_School__c);
    Assert.areEqual(
      'Zeta Charter School - Brooklyn',
      pi.Zeta_School__c,
      'Zeta_School__c must mirror Sibling_s_Zeta_School__c on save'
    );
  }

  @IsTest
  private static void addManualAttendingSibling_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.addManualAttendingSibling(null, '{"firstName":"A","lastName":"B"}');
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void addManualAttendingSibling_missingFirstName_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = SObjectIds.generateFakeId(Schema.Account.SObjectType)
          )
        }
      )
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + SObjectIds.generateFakeId(Schema.Contact.SObjectType) + '"}',
            Account.class
          )
        }
      );
    try {
      SiblingSectionController.addManualAttendingSibling(appId, '{"lastName":"B"}');
      Assert.fail('Should throw when firstName is missing');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('First name is required'));
    }
  }

  @IsTest
  private static void addManualAttendingSibling_missingBirthdate_throws() {
    // The Student record type requires PersonBirthdate, so a blank DOB must be rejected
    // before any DML. firstName/lastName are present so validation reaches the DOB check.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    try {
      SiblingSectionController.addManualAttendingSibling(appId, '{"firstName":"A","lastName":"B"}');
      Assert.fail('Should throw when birthdate is missing');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Date of birth is required'));
    }
  }

  // ---- getHouseholdSiblingCandidates ----

  @IsTest
  private static void getHouseholdSiblingCandidates_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.getHouseholdSiblingCandidates(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void getHouseholdSiblingCandidates_noLoggedInContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    // q1: getLoggedInContactId -> User query returns no rows -> contactId null -> empty.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>());
    Assert.isTrue(
      SiblingSectionController.getHouseholdSiblingCandidates(appId).isEmpty(),
      'No logged-in contact -> empty roster'
    );
  }

  @IsTest
  private static void getHouseholdSiblingCandidates_nullTimeline_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    // q1: User; q2: source IA with null Application_Timeline__c -> bail empty.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });
    Assert.isTrue(
      SiblingSectionController.getHouseholdSiblingCandidates(appId).isEmpty(),
      'Null Application Timeline -> empty roster'
    );
  }

  @IsTest
  private static void getHouseholdSiblingCandidates_noACRs_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    // q1: User; q2: IA timeline; q3: ACR empty -> bail before passes 2/3.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Application_Timeline__c = timelineId)
        }
      )
      .thenReturn(new List<AccountContactRelation>());
    Assert.isTrue(
      SiblingSectionController.getHouseholdSiblingCandidates(appId).isEmpty(),
      'No household students -> empty roster'
    );
  }

  @IsTest
  private static void getHouseholdSiblingCandidates_excludesApplyingAndEnrolled() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id accA = SObjectIds.generateFakeId(Schema.Account.SObjectType); // survives
    Id accB = SObjectIds.generateFakeId(Schema.Account.SObjectType); // already applying
    Id accC = SObjectIds.generateFakeId(Schema.Account.SObjectType); // already enrolled

    // q1 User; q2 source IA timeline; q3 ACR (3 students, Account nested/read-only via JSON);
    // q4 existing IA in timeline (accB applying); q5 ATE (accC enrolled).
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Application_Timeline__c = timelineId)
        }
      )
      .thenReturn(
        new List<AccountContactRelation>{
          (AccountContactRelation) JSON.deserialize(
            '{"Account":{"Id":"' + accA + '","FirstName":"Anna","LastName":"Aaron"}}',
            AccountContactRelation.class
          ),
          (AccountContactRelation) JSON.deserialize(
            '{"Account":{"Id":"' + accB + '","FirstName":"Bob","LastName":"Bell"}}',
            AccountContactRelation.class
          ),
          (AccountContactRelation) JSON.deserialize(
            '{"Account":{"Id":"' + accC + '","FirstName":"Cara","LastName":"Cole"}}',
            AccountContactRelation.class
          )
        }
      )
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(AccountId = accB) })
      .thenReturn(
        new List<AcademicTermEnrollment>{
          (AcademicTermEnrollment) JSON.deserialize(
            '{"LearnerAccountId":"' + accC + '"}',
            AcademicTermEnrollment.class
          )
        }
      );

    List<Map<String, Object>> result = SiblingSectionController.getHouseholdSiblingCandidates(
      appId
    );

    Assert.areEqual(
      1,
      result.size(),
      'Only the non-applying, non-enrolled household student survives'
    );
    Assert.areEqual(accA, result[0].get('accountId'));
    Assert.areEqual('Anna', result[0].get('firstName'));
    Assert.areEqual('Aaron', result[0].get('lastName'));
  }

  // ---- createPlaceholderApplications ----

  @IsTest
  private static void createPlaceholderApplications_nullId_throws() {
    DATABASE_REPO_MOCK.reset();
    try {
      SiblingSectionController.createPlaceholderApplications(null, '[]');
      Assert.fail('Should throw for null sourceApplicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void createPlaceholderApplications_blankJson_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    try {
      SiblingSectionController.createPlaceholderApplications(appId, '');
      Assert.fail('Should throw for blank selections JSON');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Selections JSON'));
    }
  }

  @IsTest
  private static void createPlaceholderApplications_emptySelections_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    try {
      SiblingSectionController.createPlaceholderApplications(appId, '[]');
      Assert.fail('Should throw for empty selections');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('At least one selection'));
    }
  }

  @IsTest
  private static void createPlaceholderApplications_missingGrade_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id accX = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    String json = JSON.serialize(
      new List<Object>{ new Map<String, Object>{ 'accountId' => accX } }
    );
    try {
      SiblingSectionController.createPlaceholderApplications(appId, json);
      Assert.fail('Should throw when a selection has no grade');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Grade Applying To is required'));
    }
  }

  @IsTest
  private static void createPlaceholderApplications_createsAppsWithOwnContactAndPriorityItems() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id submitterId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accX = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id accY = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id ctX = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id ctY = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    // q1 parent IA; q2 existing IA dup-check (none); q3 Account list (own PersonContactId).
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            Application_Timeline__c = timelineId,
            SubmittedByContactId = submitterId
          )
        }
      )
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"Id":"' +
              accX +
              '","PersonContactId":"' +
              ctX +
              '","FirstName":"Xavier","LastName":"Xi"}',
            Account.class
          ),
          (Account) JSON.deserialize(
            '{"Id":"' +
              accY +
              '","PersonContactId":"' +
              ctY +
              '","FirstName":"Yara","LastName":"Yu"}',
            Account.class
          )
        }
      );
    // insertSObjects: shells, then priority items.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid();

    String json = JSON.serialize(
      new List<Object>{
        new Map<String, Object>{ 'accountId' => accX, 'gradeApplyingTo' => '1' },
        new Map<String, Object>{ 'accountId' => accY, 'gradeApplyingTo' => 'K' }
      }
    );

    Map<String, Object> result = SiblingSectionController.createPlaceholderApplications(
      appId,
      json
    );

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(2, inserts.size(), 'One insert for shells, one for priority items');

    // Insert #1: the Draft IndividualApplication shells (one per selection).
    Map<Id, IndividualApplication> shellByAccount = new Map<Id, IndividualApplication>();
    for (SObject so : (List<SObject>) inserts[0].get('sobjects')) {
      IndividualApplication shell = (IndividualApplication) so;
      shellByAccount.put(shell.AccountId, shell);
    }
    Assert.areEqual(2, shellByAccount.size(), 'Two sibling shells inserted');

    IndividualApplication shellX = shellByAccount.get(accX);
    Assert.areEqual('Draft', shellX.Status);
    Assert.areEqual('Education', shellX.Category);
    Assert.areEqual(timelineId, shellX.Application_Timeline__c);
    Assert.areEqual(guardianId, shellX.Primary_Guardian__c);
    Assert.areEqual('1', shellX.Grade_Applying_To__c);
    Assert.areEqual(submitterId, shellX.SubmittedByContactId);
    Assert.areEqual(
      ctX,
      shellX.ContactId,
      'ContactId must be the STUDENT\'s own PersonContactId, not the source app contact'
    );
    Assert.areEqual('K', shellByAccount.get(accY).Grade_Applying_To__c);
    Assert.areEqual(ctY, shellByAccount.get(accY).ContactId);

    // Insert #2: a Pending "Sibling Applying" Priority_Item__c per shell, on the CURRENT app.
    List<SObject> pis = (List<SObject>) inserts[1].get('sobjects');
    Assert.areEqual(2, pis.size(), 'One current-app priority item per new sibling');
    for (SObject so : pis) {
      Priority_Item__c pi = (Priority_Item__c) so;
      Assert.areEqual(appId, pi.Related_Application__c, 'PI belongs to the current app');
      Assert.areEqual('Sibling Applying', pi.Priority_Type__c);
      Assert.areEqual('Pending', pi.Review_Status__c);
      Assert.isTrue(pi.First_Name__c == 'Xavier' || pi.First_Name__c == 'Yara');
    }

    Assert.areEqual(
      2,
      ((List<Id>) result.get('createdApplicationIds')).size(),
      'Two applications reported created'
    );
    Assert.isTrue(
      ((List<Id>) result.get('skippedAccountIds')).isEmpty(),
      'Nothing skipped when no duplicates exist'
    );
  }

  @IsTest
  private static void createPlaceholderApplications_duplicateGuardSkipsExisting() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id accX = SObjectIds.generateFakeId(Schema.Account.SObjectType); // already applying -> skipped
    Id accY = SObjectIds.generateFakeId(Schema.Account.SObjectType); // survives -> created
    Id ctY = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    // q1 parent IA; q2 existing IA dup-check returns accX; q3 Account list (only accY survives).
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardianId,
            Application_Timeline__c = timelineId
          )
        }
      )
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(AccountId = accX) })
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"Id":"' +
              accY +
              '","PersonContactId":"' +
              ctY +
              '","FirstName":"Yara","LastName":"Yu"}',
            Account.class
          )
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid();

    String json = JSON.serialize(
      new List<Object>{
        new Map<String, Object>{ 'accountId' => accX, 'gradeApplyingTo' => '1' },
        new Map<String, Object>{ 'accountId' => accY, 'gradeApplyingTo' => 'K' }
      }
    );

    Map<String, Object> result = SiblingSectionController.createPlaceholderApplications(
      appId,
      json
    );

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> shells = (List<SObject>) inserts[0].get('sobjects');
    Assert.areEqual(1, shells.size(), 'Only the non-duplicate selection is inserted');
    Assert.areEqual(accY, ((IndividualApplication) shells[0]).AccountId);

    List<Id> skipped = (List<Id>) result.get('skippedAccountIds');
    Assert.areEqual(1, skipped.size());
    Assert.areEqual(accX, skipped[0], 'The already-applying selection is reported skipped');
  }
}