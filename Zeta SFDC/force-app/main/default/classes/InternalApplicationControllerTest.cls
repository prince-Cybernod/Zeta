@IsTest(IsParallel=true)
private class InternalApplicationControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    InternalApplicationController.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void searchGuardians_shortTerm_skipsTheQuery() {
    DATABASE_REPO_MOCK.reset();

    Assert.isTrue(InternalApplicationController.searchGuardians('a').isEmpty());
    Assert.isTrue(InternalApplicationController.searchGuardians('  ').isEmpty());
    Assert.isTrue(InternalApplicationController.searchGuardians(null).isEmpty());
  }

  @IsTest
  private static void searchGuardians_returnsMatchesWithFallbackPhone() {
    DATABASE_REPO_MOCK.reset();
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          new Account(
            Id = guardianId,
            LastName = 'Rivera',
            PersonEmail = 'rivera@example.com',
            PersonMobilePhone = '555-0100'
          )
        }
      );

    List<Map<String, Object>> results = InternalApplicationController.searchGuardians('Riv');

    Assert.areEqual(1, results.size());
    Assert.areEqual(guardianId, results[0].get('id'));
    Assert.areEqual(
      '555-0100',
      results[0].get('phone'),
      'Should fall back to the mobile when Phone is blank'
    );
  }

  @IsTest
  private static void findPossibleDuplicates_noIdentifiers_skipsTheQuery() {
    DATABASE_REPO_MOCK.reset();

    Assert.isTrue(InternalApplicationController.findPossibleDuplicates(null, null).isEmpty());
    Assert.isTrue(InternalApplicationController.findPossibleDuplicates('', '').isEmpty());
  }

  @IsTest
  private static void findPossibleDuplicates_matchingEmail_warnsWithoutBlocking() {
    DATABASE_REPO_MOCK.reset();
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          new Account(Id = guardianId, LastName = 'Chen', PersonEmail = 'chen@example.com')
        }
      );

    List<Map<String, Object>> dupes = InternalApplicationController.findPossibleDuplicates(
      'chen@example.com',
      null
    );

    Assert.areEqual(1, dupes.size(), 'Should surface the match for the staff warning');
    Assert.areEqual(guardianId, dupes[0].get('id'));
  }

  @IsTest
  private static void createGuardian_setsContactDetailsAndLanguage() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ new Account() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Map<String, Object> result = InternalApplicationController.createGuardian(
      JSON.serialize(
        new Map<String, Object>{
          'firstName' => 'Ada',
          'lastName' => 'Lovelace',
          'email' => 'ada@example.com',
          'phone' => '555-0101',
          'languagePreference' => 'Spanish',
          'street' => '1 Main St',
          'city' => 'New York'
        }
      )
    );

    Assert.isTrue(result.containsKey('accountId'), 'Should return the new guardian');
    List<Map<String, Object>> insertCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Account guardian = (Account) ((List<SObject>) insertCalls[0].get('sobjects'))[0];
    Assert.areEqual('Lovelace', guardian.LastName);
    Assert.areEqual('ada@example.com', guardian.PersonEmail);
    Assert.areEqual('Spanish', guardian.Language_Preference__pc, 'Language should be written back');
    Assert.areEqual('US', guardian.PersonMailingCountry, 'Country is implied by a US address');
  }

  @IsTest
  private static void createGuardian_missingLastName_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      InternalApplicationController.createGuardian(
        JSON.serialize(new Map<String, Object>{ 'firstName' => 'Ada' })
      );
      Assert.fail('Should reject a guardian with no last name');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('Last name is required'),
        'Unexpected message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void startApplication_stampsGuardianAndLeadFields() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // findExistingDraft, the address copy, then the student and guardian
      // person-contact lookups.
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(new List<Account>())
      .thenReturn(new List<Account>{ new Account() })
      .thenReturn(new List<Account>{ new Account() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    Map<String, Object> result = InternalApplicationController.startApplication(
      JSON.serialize(
        new Map<String, Object>{
          'guardianAccountId' => guardianAccountId,
          'studentAccountId' => studentAccountId,
          'timelineId' => timelineId,
          'grade' => 'K',
          'leadSource' => 'CBO Tabling',
          'appInfoSource' => 'In-Person'
        }
      )
    );

    Assert.areEqual(false, result.get('reused'), 'Should create rather than reuse');
    List<Map<String, Object>> insertCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    IndividualApplication app = (IndividualApplication) ((List<SObject>) insertCalls[0]
      .get('sobjects'))[0];
    Assert.areEqual(guardianAccountId, app.Primary_Guardian__c, 'Guardian comes from the intake');
    Assert.areEqual(studentAccountId, app.AccountId);
    Assert.areEqual(UserInfo.getUserId(), app.Converting_Team_Member__c, 'Stamps the staff user');
    Assert.areEqual('Team-Assisted Conversion', app.Conversion_Type__c);
    Assert.areEqual('CBO Tabling', app.Lead_Source__c);
    Assert.areEqual('In-Person', app.App_Info_Source_Staff_Internal__c);
    Assert.areEqual('Draft', app.Status);
  }

  @IsTest
  private static void startApplication_copiesTheGuardianAddressToABlankStudent() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(
        new List<Account>{
          new Account(
            Id = guardianAccountId,
            PersonMailingStreet = '350 5th Avenue\nApt 12B',
            PersonMailingCity = 'New York',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '10118',
            PersonMailingCountry = 'US',
            Apartment_Number__c = '12B'
          ),
          new Account(Id = studentAccountId)
        }
      )
      .thenReturn(new List<Account>{ new Account() })
      .thenReturn(new List<Account>{ new Account() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    InternalApplicationController.startApplication(
      JSON.serialize(
        new Map<String, Object>{
          'guardianAccountId' => guardianAccountId,
          'studentAccountId' => studentAccountId,
          'timelineId' => SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType)
        }
      )
    );

    List<Map<String, Object>> updateCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, updateCalls.size(), 'The blank student should be given the address');
    Account student = (Account) ((List<SObject>) updateCalls[0].get('sobjects'))[0];
    Assert.areEqual(studentAccountId, student.Id);
    Assert.areEqual('350 5th Avenue\nApt 12B', student.PersonMailingStreet);
    Assert.areEqual('New York', student.PersonMailingCity);
    Assert.areEqual('NY', student.PersonMailingState);
    Assert.areEqual('10118', student.PersonMailingPostalCode);
    Assert.areEqual('12B', student.Apartment_Number__c);
  }

  @IsTest
  private static void startApplication_studentWithAnAddress_keepsIt() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(
        new List<Account>{
          new Account(Id = guardianAccountId, PersonMailingStreet = '350 5th Avenue'),
          new Account(Id = studentAccountId, PersonMailingStreet = '1 Student Way')
        }
      )
      .thenReturn(new List<Account>{ new Account() })
      .thenReturn(new List<Account>{ new Account() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    InternalApplicationController.startApplication(
      JSON.serialize(
        new Map<String, Object>{
          'guardianAccountId' => guardianAccountId,
          'studentAccountId' => studentAccountId,
          'timelineId' => SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType)
        }
      )
    );

    Assert.isTrue(
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).isEmpty(),
      'A student who already has an address must not be overwritten'
    );
  }

  @IsTest
  private static void startApplication_existingDraft_isReused() {
    DATABASE_REPO_MOCK.reset();
    Id existingId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = existingId) });

    Map<String, Object> result = InternalApplicationController.startApplication(
      JSON.serialize(
        new Map<String, Object>{
          'guardianAccountId' => SObjectIds.generateFakeId(Schema.Account.SObjectType),
          'studentAccountId' => SObjectIds.generateFakeId(Schema.Account.SObjectType),
          'timelineId' => SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType)
        }
      )
    );

    Assert.areEqual(existingId, result.get('applicationId'), 'Should reuse the open draft');
    Assert.areEqual(true, result.get('reused'));
  }

  @IsTest
  private static void startApplication_missingGuardian_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      InternalApplicationController.startApplication(
        JSON.serialize(
          new Map<String, Object>{
            'studentAccountId' => SObjectIds.generateFakeId(Schema.Account.SObjectType),
            'timelineId' => SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType)
          }
        )
      );
      Assert.fail('Should reject an application with no guardian');
    } catch (Exception e) {
      Assert.isTrue(
        e.getMessage().contains('Guardian Account Id is required'),
        'Unexpected message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void getGuardianStudents_noPersonContact_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ new Account() });

    List<Map<String, Object>> students = InternalApplicationController.getGuardianStudents(
      SObjectIds.generateFakeId(Schema.Account.SObjectType)
    );

    Assert.isTrue(students.isEmpty(), 'No Contact means no household roster');
  }

  @IsTest
  private static void findPossibleDuplicates_phoneOnly_matchesEitherPhoneField() {
    DATABASE_REPO_MOCK.reset();
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{ new Account(Id = guardianId, LastName = 'Okonkwo', Phone = '555-0102') }
      );

    List<Map<String, Object>> dupes = InternalApplicationController.findPossibleDuplicates(
      null,
      '555-0102'
    );

    Assert.areEqual(1, dupes.size(), 'Should surface the match for the staff warning');
    Map<String, Object> call = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.queryWithBinds()
    )[0];
    Map<String, Object> binds = (Map<String, Object>) call.get('bindMap');
    Assert.isTrue(binds.containsKey('phone'), 'The phone should be bound');
    Assert.isFalse(
      binds.containsKey('email'),
      'A blank email must stay unbound, or it matches every guardian without one'
    );
    Assert.isTrue(
      ((String) call.get('query')).contains('PersonMobilePhone = :phone'),
      'The search should cover the mobile as well as the business phone'
    );
  }

  @IsTest
  private static void getGuardianStudents_returnsTheHouseholdRoster() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // queryWithBinds #1: the guardian's PersonContactId, read-only so deserialized
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      )
      // queryWithBinds #2: the roster, whose Account fields are parent reads
      .thenReturn(
        new List<AccountContactRelation>{
          (AccountContactRelation) JSON.deserialize(
            '{"AccountId":"' +
              studentAccountId +
              '","Account":{"FirstName":"Kenji","LastName":"Nakamura",' +
              '"PersonBirthdate":"2018-04-02"}}',
            AccountContactRelation.class
          )
        }
      );

    List<Map<String, Object>> students = InternalApplicationController.getGuardianStudents(
      guardianAccountId
    );

    Assert.areEqual(1, students.size(), 'The guardian has one related student');
    Assert.areEqual(studentAccountId, students[0].get('id'));
    Assert.areEqual('Kenji', students[0].get('firstName'));
    Assert.areEqual('Nakamura', students[0].get('lastName'));
    Assert.areEqual(
      Date.newInstance(2018, 4, 2),
      students[0].get('birthdate'),
      'The birthdate is what lets staff tell siblings apart'
    );
  }

  @IsTest
  private static void createStudentForGuardian_stampsTheGuardianAndRelatesTheContact() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DuplicateStudentValidationServiceMock guardMock = new DuplicateStudentValidationServiceMock();
    guardMock.when(guardMock.method.assertNoDuplicate()).thenReturnVoid();
    InternalApplicationController.dupGuard = guardMock;

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // queryWithBinds #1: the guardian's PersonContactId
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      )
      // queryWithBinds #2: no relationship exists yet
      .thenReturn(new List<AccountContactRelation>());
    // The student, then the relationship.
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects())
      .thenReturnVoid()
      .thenReturnVoid();

    InternalApplicationController.createStudentForGuardian(
      guardianAccountId,
      JSON.serialize(
        new Map<String, Object>{
          'firstName' => 'Kenji',
          'lastName' => 'Nakamura',
          'birthdate' => '2018-04-02',
          'gender' => 'Male'
        }
      )
    );
    InternalApplicationController.dupGuard = new DuplicateStudentValidationServiceImpl();

    List<Map<String, Object>> insertCalls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    Assert.areEqual(2, insertCalls.size(), 'The student and the relationship are both inserted');

    Account student = (Account) ((List<SObject>) insertCalls[0].get('sobjects'))[0];
    Assert.areEqual('Nakamura', student.LastName);
    Assert.areEqual(Date.newInstance(2018, 4, 2), student.PersonBirthdate);
    Assert.areEqual('Male', student.PersonGenderIdentity);
    Assert.areEqual(
      guardianAccountId,
      student.Primary_Guardian__c,
      'The guardian is stamped up front so the org flow does not roll the application back'
    );
    Assert.areEqual(
      Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Student')
        .getRecordTypeId(),
      student.RecordTypeId,
      'Students are created with the Student record type'
    );

    AccountContactRelation relation = (AccountContactRelation) ((List<SObject>) insertCalls[1]
      .get('sobjects'))[0];
    Assert.areEqual(
      guardianContactId,
      relation.ContactId,
      'The guardian is related to the student'
    );
    Assert.areEqual(true, relation.IsActive);
  }

  @IsTest
  private static void createStudentForGuardian_existingRelationship_isNotDuplicated() {
    DATABASE_REPO_MOCK.reset();
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DuplicateStudentValidationServiceMock guardMock = new DuplicateStudentValidationServiceMock();
    guardMock.when(guardMock.method.assertNoDuplicate()).thenReturnVoid();
    InternalApplicationController.dupGuard = guardMock;

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      )
      // The org's own flow already related the pair.
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(
            Id = SObjectIds.generateFakeId(Schema.AccountContactRelation.SObjectType)
          )
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    InternalApplicationController.createStudentForGuardian(
      guardianAccountId,
      JSON.serialize(new Map<String, Object>{ 'firstName' => 'Kenji', 'lastName' => 'Nakamura' })
    );
    InternalApplicationController.dupGuard = new DuplicateStudentValidationServiceImpl();

    Assert.areEqual(
      1,
      DATABASE_REPO_MOCK.getCallCount(DATABASE_REPO_MOCK.method.insertSObjects()),
      'A second relationship would make every later save of the student fail on DUPLICATE_VALUE'
    );
  }
}