@IsTest(IsParallel=true)
private class ApplicationReviewControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    ApplicationReviewController.databaseRepo = DATABASE_REPO_MOCK;
  }

  // Query order inside getReviewBundle:
  // 1. SchoolRanking queryWithBinds   -> List<AcademicInterest>
  // 2. Sibling queryWithBinds         -> List<Priority_Item__c>
  // 3. ApplicationStudent queryWithBinds -> List<IndividualApplication>
  // 4. getStudents: getLoggedInContactId -> List<User>
  // 5. getStudents: AccountContactRelation -> List<AccountContactRelation>
  // 6. SubmissionWarnings queryWithBinds -> List<IndividualApplication>

  @IsTest
  private static void getReviewBundle_happyPath_returnsAllSections() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id academicInterestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id schoolAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id siblingId = SObjectIds.generateFakeId(Schema.Priority_Item__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<AcademicInterest>{
          new AcademicInterest(Id = academicInterestId, School_Rank__c = 1)
        }
      )
      .thenReturn(
        new List<Priority_Item__c>{
          new Priority_Item__c(
            Id = siblingId,
            Priority_Type__c = 'Sibling Attending',
            First_Name__c = 'Sam',
            Last_Name__c = 'Sibling',
            Gender__c = 'Male',
            Sibling_s_Zeta_School__c = 'Zeta Bronx'
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAccountId,
            Grade_Applying_To__c = 'K',
            Current_Grade__c = 'PK'
          )
        }
      )
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
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Map<String, Object> bundle = ApplicationReviewController.getReviewBundle(appId);

    Assert.isNotNull(bundle.get('schools'), 'schools key should exist');
    Assert.isNotNull(bundle.get('siblings'), 'siblings key should exist');
    Assert.isNotNull(bundle.get('applicationStudent'), 'applicationStudent key should exist');
    Assert.isNotNull(bundle.get('students'), 'students key should exist');
    Assert.isNotNull(bundle.get('submissionWarnings'), 'submissionWarnings key should exist');

    List<Map<String, Object>> schools = (List<Map<String, Object>>) bundle.get('schools');
    Assert.areEqual(1, schools.size(), 'Should have one ranked school');
    Assert.areEqual(academicInterestId, schools[0].get('academicInterestId'));
    Assert.areEqual(1, schools[0].get('rank'));

    List<Object> siblings = (List<Object>) bundle.get('siblings');
    Assert.areEqual(1, siblings.size(), 'Should have one sibling');
    Map<String, Object> sibling0 = (Map<String, Object>) siblings[0];
    Assert.areEqual('Sam', sibling0.get('First_Name__c'));
    Assert.areEqual('Sibling Attending', sibling0.get('Priority_Type__c'));

    Map<String, Object> appStudent = (Map<String, Object>) bundle.get('applicationStudent');
    Assert.areEqual(studentAccountId, appStudent.get('studentAccountId'));
    Assert.areEqual('K', appStudent.get('grade'));
    Assert.areEqual('PK', appStudent.get('currentGrade'));
    Assert.isNotNull(appStudent.get('gradeLabel'), 'gradeLabel should be populated');
    Assert.isNotNull(appStudent.get('currentGradeLabel'), 'currentGradeLabel should be populated');
    Assert.isTrue(
      appStudent.containsKey('schoolStartDate'),
      'response should include schoolStartDate (sourced from School_Start_Date_Setting.Default CMT)'
    );

    List<Map<String, Object>> students = (List<Map<String, Object>>) bundle.get('students');
    Assert.areEqual(1, students.size(), 'Should return one linked student');
    Assert.areEqual('Jane', students[0].get('firstName'));
    Assert.areEqual('123 Main St, New York, NY, 10001', students[0].get('address'));

    Map<String, Object> warnings = (Map<String, Object>) bundle.get('submissionWarnings');
    Assert.areEqual(false, warnings.get('hasAgeWarning'));
    Assert.areEqual(false, warnings.get('hasResidencyWarning'));
  }

  @IsTest
  private static void getReviewBundle_emptySiblings_returnsEmptyListNotNull() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<Priority_Item__c>())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAccountId)
        }
      )
      .thenReturn(new List<User>{ new User(ContactId = contactId) })
      .thenReturn(new List<AccountContactRelation>())
      .thenReturn(
        new List<IndividualApplication>{
          (IndividualApplication) JSON.deserialize(
            '{"Id":"' + appId + '","Age_Inconsistency_Flag_c__c":true,"Outside_of_NY__c":true}',
            IndividualApplication.class
          )
        }
      );

    Map<String, Object> bundle = ApplicationReviewController.getReviewBundle(appId);

    List<Object> siblings = (List<Object>) bundle.get('siblings');
    Assert.isNotNull(siblings, 'siblings should be an empty list, not null');
    Assert.isTrue(siblings.isEmpty(), 'siblings list should be empty');

    List<Map<String, Object>> schools = (List<Map<String, Object>>) bundle.get('schools');
    Assert.isNotNull(schools, 'schools should be an empty list, not null');
    Assert.isTrue(schools.isEmpty(), 'schools list should be empty');

    List<Map<String, Object>> students = (List<Map<String, Object>>) bundle.get('students');
    Assert.isNotNull(students, 'students should be an empty list, not null');
    Assert.isTrue(students.isEmpty(), 'students list should be empty');

    Map<String, Object> warnings = (Map<String, Object>) bundle.get('submissionWarnings');
    Assert.areEqual(true, warnings.get('hasAgeWarning'));
    Assert.areEqual(true, warnings.get('hasResidencyWarning'));
    // Non-Pre-K (grade absent here) requires NY State residency, not city-only.
    Assert.areEqual(false, warnings.get('residencyRequiresCityOnly'));
  }

  @IsTest
  private static void getReviewBundle_nullApplicationId_throws() {
    DATABASE_REPO_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      ApplicationReviewController.getReviewBundle(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getReviewBundle_userHasNoContact_studentsEmpty() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<Priority_Item__c>())
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(new List<User>{ new User() })
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Map<String, Object> bundle = ApplicationReviewController.getReviewBundle(appId);

    List<Map<String, Object>> students = (List<Map<String, Object>>) bundle.get('students');
    Assert.isNotNull(students, 'students should be an empty list when guardian has no contact');
    Assert.isTrue(students.isEmpty(), 'students list should be empty when guardian has no contact');

    Map<String, Object> appStudent = (Map<String, Object>) bundle.get('applicationStudent');
    Assert.isTrue(appStudent.isEmpty(), 'applicationStudent should be empty when app not found');
  }
}