@IsTest(IsParallel=true)
private class StudentSelectionControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    StudentSelectionController.databaseRepo = DATABASE_REPO_MOCK;
  }
  @IsTest
  private static void getStudents_withContact_returnsLinkedStudents() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(
            Account = new Account(
              Id = studentAccountId,
              FirstName = 'Jane',
              LastName = 'Doe',
              PersonMailingStreet = '123 Main St',
              PersonMailingCity = 'New York',
              PersonMailingState = 'NY',
              PersonMailingPostalCode = '10001'
            )
          )
        }
      )
      .thenReturn(new List<IndividualApplication>());

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.areEqual(1, result.size(), 'Should return one student');
    Assert.areEqual(studentAccountId, result[0].get('id'));
    Assert.areEqual('Jane', result[0].get('firstName'));
    Assert.areEqual('Doe', result[0].get('lastName'));
    Assert.areEqual('123 Main St, New York, NY, 10001', result[0].get('address'));
  }
  @IsTest
  private static void getStudents_noContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.isTrue(result.isEmpty(), 'Should return empty when user has no ContactId');
  }
  @IsTest
  private static void getStudents_noUser_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>());

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.isTrue(result.isEmpty(), 'Should return empty when user query returns nothing');
  }
  @IsTest
  private static void getStudents_partialAddress_joinsNonBlankParts() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(
            Account = new Account(
              Id = studentAccountId,
              FirstName = 'Partial',
              LastName = 'Address',
              PersonMailingCity = 'Brooklyn',
              PersonMailingState = 'NY'
            )
          )
        }
      )
      .thenReturn(new List<IndividualApplication>());

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.areEqual('Brooklyn, NY', result[0].get('address'));
  }

  @IsTest
  private static void getStudents_withApartment_appendsAptToStreet() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(
            Account = new Account(
              Id = studentAccountId,
              FirstName = 'Apt',
              LastName = 'Resident',
              PersonMailingStreet = '123 Main St',
              PersonMailingCity = 'Queens',
              PersonMailingState = 'NY',
              PersonMailingPostalCode = '11354',
              Apartment_Number__c = '4B'
            )
          )
        }
      )
      .thenReturn(new List<IndividualApplication>());

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.areEqual('123 Main St, Apt 4B, Queens, NY, 11354', result[0].get('address'));
  }
  @IsTest
  private static void getStudents_withSubmittedApp_setsHasSubmittedApplication() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentBId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(
            Account = new Account(Id = studentAId, FirstName = 'A', LastName = 'One')
          ),
          new AccountContactRelation(
            Account = new Account(Id = studentBId, FirstName = 'B', LastName = 'Two')
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(AccountId = studentAId, AppliedDate = Date.today())
        }
      );

    List<Map<String, Object>> result = StudentSelectionController.getStudents();

    Assert.areEqual(2, result.size(), 'Should return both students');
    Assert.areEqual(
      true,
      result[0].get('hasSubmittedApplication'),
      'Student A has a submitted application'
    );
    Assert.areEqual(
      false,
      result[1].get('hasSubmittedApplication'),
      'Student B has no submitted application'
    );
  }
  @IsTest
  private static void createStudent_validJson_createsAccountAndAcr() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid();

    String studentJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'New',
        'lastName' => 'Student',
        'birthdate' => '2020-01-01',
        'gender' => 'Male',
        'street' => '456 Oak Ave',
        'city' => 'Brooklyn',
        'state' => 'NY',
        'zip' => '11201'
      }
    );

    StudentSelectionController.createStudent(studentJson);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects(), 2);

    List<Map<String, Object>> insertCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );

    List<SObject> accountInsert = (List<SObject>) insertCalls[0].get('sobjects');
    Account created = (Account) accountInsert[0];
    Assert.areEqual('New', created.FirstName, 'Should set FirstName');
    Assert.areEqual('Student', created.LastName, 'Should set LastName');
    Assert.areEqual('Male', created.PersonGenderIdentity, 'Should set PersonGenderIdentity');
    Assert.areEqual('US', created.PersonMailingCountry, 'Should default country to US');
    Assert.areEqual(
      Date.newInstance(2020, 1, 1),
      created.PersonBirthdate,
      'Should set PersonBirthdate from input'
    );

    List<SObject> acrInsert = (List<SObject>) insertCalls[1].get('sobjects');
    AccountContactRelation acr = (AccountContactRelation) acrInsert[0];
    Assert.areEqual(contactId, acr.ContactId, 'ACR should link to logged-in contact');
    Assert.isTrue(acr.IsActive, 'ACR should be active');
  }
  @IsTest
  private static void createStudent_duplicate_throws() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });

    DuplicateStudentValidationServiceMock guardMock = new DuplicateStudentValidationServiceMock();
    guardMock.when(guardMock.method.assertNoDuplicate())
      .thenThrow(new AuraHandledException('duplicate'));
    StudentSelectionController.dupGuard = guardMock;

    String studentJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'Dup',
        'lastName' => 'Student',
        'birthdate' => '2020-01-01'
      }
    );

    AssertThrows.Throwing throwing = AssertThrows.with(AuraHandledException.class);

    try {
      StudentSelectionController.createStudent(studentJson);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
    StudentSelectionController.dupGuard = new DuplicateStudentValidationServiceImpl();
  }
  @IsTest
  private static void createStudent_blankBirthdate_omitsPersonBirthdate() {
    // Date of Birth is optional (e.g. the "add a sibling" form). A blank
    // birthdate must not crash JSON deserialization; PersonBirthdate stays null.
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid();

    String studentJson = JSON.serialize(
      new Map<String, Object>{
        'firstName' => 'Ron',
        'lastName' => 'Potter',
        'birthdate' => '',
        'gender' => ''
      }
    );

    StudentSelectionController.createStudent(studentJson);

    List<Map<String, Object>> insertCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Account created = (Account) ((List<SObject>) insertCalls[0].get('sobjects'))[0];
    Assert.areEqual('Ron', created.FirstName, 'Should set FirstName');
    Assert.isNull(
      created.PersonBirthdate,
      'Blank birthdate must be omitted, not deserialized into a Date'
    );
  }
  @IsTest
  private static void createStudent_nullJson_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student JSON is required'
    );

    try {
      StudentSelectionController.createStudent(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void createStudent_blankJson_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student JSON is required'
    );

    try {
      StudentSelectionController.createStudent('  ');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void createStudent_noContact_throws() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    String studentJson = JSON.serialize(
      new Map<String, Object>{ 'firstName' => 'Test', 'lastName' => 'Student' }
    );

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Logged-in user must have a Contact'
    );

    try {
      StudentSelectionController.createStudent(studentJson);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void getGuardianAccountId_withContact_returnsAccountId() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>{ new Contact(Id = contactId, AccountId = accountId) });

    Id result = StudentSelectionController.getGuardianAccountId();

    Assert.areEqual(accountId, result);
  }
  @IsTest
  private static void getGuardianAccountId_noContact_returnsNull() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    Id result = StudentSelectionController.getGuardianAccountId();

    Assert.isNull(result, 'Should return null when user has no ContactId');
  }
  @IsTest
  private static void getGuardianAccountId_contactNotFound_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>());

    Id result = StudentSelectionController.getGuardianAccountId();

    Assert.isNull(result, 'Should return null when contact query returns empty');
  }
  @IsTest
  private static void getGuardianAddress_withAccount_returnsAddress() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // Query 1: getLoggedInContactId -> User
    // Query 2: getGuardianAccountId -> Contact
    // Query 3: getGuardianAddress -> Account
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>{ new Contact(Id = contactId, AccountId = accountId) })
      .thenReturn(
        new List<Account>{
          new Account(
            Id = accountId,
            PersonMailingStreet = '789 Elm St',
            PersonMailingCity = 'Queens',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '11375'
          )
        }
      );

    Map<String, String> result = StudentSelectionController.getGuardianAddress();

    Assert.areEqual('789 Elm St', result.get('street'));
    Assert.areEqual('Queens', result.get('city'));
    Assert.areEqual('NY', result.get('state'));
    Assert.areEqual('11375', result.get('zip'));
  }
  @IsTest
  private static void getGuardianAddress_noContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    Map<String, String> result = StudentSelectionController.getGuardianAddress();

    Assert.isTrue(result.isEmpty(), 'Should return empty when user has no ContactId');
  }
  @IsTest
  private static void getGuardianAddress_accountNotFound_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>{ new Contact(Id = contactId, AccountId = accountId) })
      .thenReturn(new List<Account>());

    Map<String, String> result = StudentSelectionController.getGuardianAddress();

    Assert.isTrue(result.isEmpty(), 'Should return empty when account query returns nothing');
  }
  @IsTest
  private static void getGuardianAddress_nullFields_returnsEmptyStrings() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<Contact>{ new Contact(Id = contactId, AccountId = accountId) })
      .thenReturn(new List<Account>{ new Account(Id = accountId) });

    Map<String, String> result = StudentSelectionController.getGuardianAddress();

    Assert.areEqual('', result.get('street'));
    Assert.areEqual('', result.get('city'));
    Assert.areEqual('', result.get('state'));
    Assert.areEqual('', result.get('zip'));
  }
  @IsTest
  private static void selectStudent_withGrades_updatesAndReturnsResult() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = '1')
        }
      )
      // getPersonContactIdForAccount (empty -> ContactId omitted; not asserted here)
      .thenReturn(new List<Account>())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAccountId,
            Grade_Applying_To__c = '1',
            Current_Grade__c = 'K'
          )
        }
      );

    Map<String, Object> result = StudentSelectionController.selectStudent(
      appId,
      studentAccountId,
      '1',
      'K'
    );

    Assert.areEqual(studentAccountId, result.get('studentAccountId'));
    Assert.areEqual('1', result.get('grade'));
    Assert.areEqual('K', result.get('currentGrade'));
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
  }

  @IsTest
  private static void selectStudent_gradeChanges_wipesDraftInterests() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id draftId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = 'K')
        }
      )
      // getPersonContactIdForAccount (empty -> ContactId omitted; not asserted here)
      .thenReturn(new List<Account>())
      .thenReturn(new List<AcademicInterest>{ new AcademicInterest(Id = draftId) })
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAccountId,
            Grade_Applying_To__c = '1',
            Current_Grade__c = 'K'
          )
        }
      );

    StudentSelectionController.selectStudent(appId, studentAccountId, '1', 'K');

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
  }

  @IsTest
  private static void selectStudent_sameGrade_noWipe() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = '2')
        }
      )
      // getPersonContactIdForAccount (empty -> ContactId omitted; not asserted here)
      .thenReturn(new List<Account>())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAccountId,
            Grade_Applying_To__c = '2'
          )
        }
      );

    StudentSelectionController.selectStudent(appId, studentAccountId, '2', null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
  }
  @IsTest
  private static void selectStudent_nullApplicationId_throws() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      StudentSelectionController.selectStudent(null, studentAccountId, '1', 'K');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void selectStudent_nullStudentAccountId_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student Account Id is required'
    );

    try {
      StudentSelectionController.selectStudent(appId, null, '1', 'K');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void selectStudent_blankGrades_omitsGradeFields() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // grade is blank so priorQuery is skipped; getPersonContactIdForAccount runs first
      .thenReturn(new List<Account>())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAccountId)
        }
      );

    Map<String, Object> result = StudentSelectionController.selectStudent(
      appId,
      studentAccountId,
      null,
      null
    );

    Assert.areEqual(studentAccountId, result.get('studentAccountId'));
    Assert.isNull(result.get('grade'), 'Grade should be null when not provided');
  }

  @IsTest
  private static void selectStudent_switchesStudent_resyncsContactId() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    // PersonContactId is system-writable only, so deserialize it onto the mock.
    Account studentAccount = (Account) JSON.deserialize(
      JSON.serialize(
        new Map<String, Object>{ 'Id' => studentAccountId, 'PersonContactId' => studentContactId }
      ),
      Account.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // grade blank -> priorQuery skipped; #1 getPersonContactIdForAccount, #2 selectQuery
      .thenReturn(new List<Account>{ studentAccount })
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAccountId)
        }
      );

    StudentSelectionController.selectStudent(appId, studentAccountId, null, null);

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    IndividualApplication updated = (IndividualApplication) ((List<SObject>) updateCalls[0]
      .get('sobjects'))[0];
    Assert.areEqual(studentAccountId, updated.AccountId, 'AccountId should move to new student');
    Assert.areEqual(
      studentContactId,
      updated.ContactId,
      'ContactId should resync to the new student PersonContactId'
    );
  }

  @IsTest
  private static void selectStudent_nullPersonContactId_omitsContactId() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // getPersonContactIdForAccount returns nothing -> studentContactId resolves to null
      .thenReturn(new List<Account>())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAccountId)
        }
      );

    StudentSelectionController.selectStudent(appId, studentAccountId, null, null);

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    IndividualApplication updated = (IndividualApplication) ((List<SObject>) updateCalls[0]
      .get('sobjects'))[0];
    Assert.areEqual(studentAccountId, updated.AccountId, 'AccountId should still update');
    Assert.isNull(
      updated.ContactId,
      'ContactId must be omitted (not nulled) when PersonContactId is unavailable'
    );
  }
  @IsTest
  private static void getGradeOptions_returnsActivePicklistValues() {
    DATABASE_REPO_MOCK.reset();

    List<Map<String, String>> result = StudentSelectionController.getGradeOptions();

    Assert.isFalse(result.isEmpty(), 'Should return grade picklist options');
    for (Map<String, String> option : result) {
      Assert.isNotNull(option.get('label'), 'Each option should have a label');
      Assert.isNotNull(option.get('value'), 'Each option should have a value');
    }
  }
  @IsTest
  private static void getGradeBirthYearGuidance_returnsTimelineYears() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // The configured birth years live on the application's Application Timeline.
    // Build the read-only parent relationship via JSON.
    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      '{"Application_Timeline__r":{"Pre_K_Birth_Year__c":"2023","Kindergarten_Birth_Year__c":"2022"}}',
      IndividualApplication.class
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = StudentSelectionController.getGradeBirthYearGuidance(appId);

    Assert.areEqual('2023', result.get('preKBirthYear'), 'Pre-K birth year from timeline');
    Assert.areEqual(
      '2022',
      result.get('kindergartenBirthYear'),
      'Kindergarten birth year from timeline'
    );
  }
  @IsTest
  private static void getGradeBirthYearGuidance_unconfiguredTimeline_returnsNulls() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // Cycle not configured: the timeline birth-year fields are blank, so guidance
    // returns null years and the LWC omits the note.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Map<String, Object> result = StudentSelectionController.getGradeBirthYearGuidance(appId);

    Assert.areEqual(null, result.get('preKBirthYear'), 'Pre-K year null when unconfigured');
    Assert.areEqual(
      null,
      result.get('kindergartenBirthYear'),
      'Kindergarten year null when unconfigured'
    );
  }
  @IsTest
  private static void getGradeBirthYearGuidance_nullId_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    // The component may mount before a draft application exists; a null id short-
    // circuits to an empty map (no query, no note).
    Map<String, Object> result = StudentSelectionController.getGradeBirthYearGuidance(null);

    Assert.isTrue(result.isEmpty(), 'No guidance without an application id');
  }
  @IsTest
  private static void getApplicationStudent_withApp_returnsStudentData() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAccountId,
            Grade_Applying_To__c = 'K',
            Current_Grade__c = 'PK'
          )
        }
      );

    Map<String, Object> result = StudentSelectionController.getApplicationStudent(appId);

    Assert.areEqual(studentAccountId, result.get('studentAccountId'));
    Assert.areEqual('K', result.get('grade'));
    Assert.areEqual('PK', result.get('currentGrade'));
    Assert.isNotNull(result.get('gradeLabel'), 'Should include gradeLabel');
    Assert.isNotNull(result.get('currentGradeLabel'), 'Should include currentGradeLabel');
    Assert.isTrue(
      result.containsKey('schoolStartDate'),
      'Should include schoolStartDate (sourced from School_Start_Date_Setting.Default CMT)'
    );
  }
  @IsTest
  private static void getApplicationStudent_internalUser_returnsStudentDisplayFields() {
    // Internal/record-page mode reads the student's name + birthdate off the
    // application's Account so studentSelection can render a tile without a
    // parent Contact. The Account relationship can't be set via the SObject
    // constructor, so hydrate it through JSON (the pattern this controller uses
    // elsewhere). Birthdate is best-effort across the JSON round-trip; the
    // name fields are the load-bearing assertions.
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    IndividualApplication app = (IndividualApplication) JSON.deserialize(
      JSON.serialize(
        new Map<String, Object>{
          'Id' => appId,
          'AccountId' => studentAccountId,
          'Grade_Applying_To__c' => 'K',
          'Account' => new Map<String, Object>{
            'Id' => studentAccountId,
            'FirstName' => 'Ada',
            'LastName' => 'Lovelace',
            'PersonContact' => new Map<String, Object>{ 'Birthdate' => '2018-05-10' }
          }
        }
      ),
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Map<String, Object> result = StudentSelectionController.getApplicationStudent(appId);

    Assert.areEqual(studentAccountId, result.get('studentAccountId'));
    Assert.areEqual('Ada', result.get('firstName'), 'Should expose student firstName');
    Assert.areEqual('Lovelace', result.get('lastName'), 'Should expose student lastName');
    Assert.isTrue(result.containsKey('birthdate'), 'Should include birthdate key');
  }
  @IsTest
  private static void getApplicationStudent_notFound_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    Map<String, Object> result = StudentSelectionController.getApplicationStudent(appId);

    Assert.isTrue(result.isEmpty(), 'Should return empty map when app not found');
  }
  @IsTest
  private static void getApplicationStudent_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      StudentSelectionController.getApplicationStudent(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void getApplicationStudent_nullGrade_returnsEmptyLabel() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAccountId)
        }
      );

    Map<String, Object> result = StudentSelectionController.getApplicationStudent(appId);

    Assert.areEqual('', result.get('gradeLabel'), 'Null grade should produce empty label');
    Assert.areEqual(
      '',
      result.get('currentGradeLabel'),
      'Null currentGrade should produce empty label'
    );
  }
  @IsTest
  private static void updateStudentBirthdate_unlocked_updatesAccount() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(AccountId = studentAccountId, ContactId = contactId)
        }
      )
      .thenReturn(new List<IndividualApplication>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    Date newBirthdate = Date.newInstance(2019, 3, 15);
    StudentSelectionController.updateStudentBirthdate(studentAccountId, newBirthdate);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    List<SObject> updated = (List<SObject>) updateCalls[0].get('sobjects');
    Account updatedAccount = (Account) updated[0];
    Assert.areEqual(studentAccountId, updatedAccount.Id);
    Assert.areEqual(newBirthdate, updatedAccount.PersonBirthdate);
  }
  @IsTest
  private static void updateStudentBirthdate_submittedApp_throws() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(AccountId = studentAccountId, ContactId = contactId)
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(AccountId = studentAccountId, AppliedDate = Date.today())
        }
      );

    AssertThrows.Throwing throwing = AssertThrows.with(AuraHandledException.class);

    try {
      StudentSelectionController.updateStudentBirthdate(
        studentAccountId,
        Date.newInstance(2019, 3, 15)
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void updateStudentBirthdate_notOwner_throws() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<AccountContactRelation>());

    AssertThrows.Throwing throwing = AssertThrows.with(AuraHandledException.class);

    try {
      StudentSelectionController.updateStudentBirthdate(
        studentAccountId,
        Date.newInstance(2019, 3, 15)
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void updateStudentBirthdate_nullStudentId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Student Account Id is required'
    );

    try {
      StudentSelectionController.updateStudentBirthdate(null, Date.newInstance(2019, 3, 15));
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void updateStudentBirthdate_nullBirthdate_throws() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Birthdate is required'
    );

    try {
      StudentSelectionController.updateStudentBirthdate(studentAccountId, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
  @IsTest
  private static void updateStudentBirthdate_noContact_throws() {
    DATABASE_REPO_MOCK.reset();
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User() });

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Logged-in user must have a Contact'
    );

    try {
      StudentSelectionController.updateStudentBirthdate(
        studentAccountId,
        Date.newInstance(2019, 3, 15)
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }
}