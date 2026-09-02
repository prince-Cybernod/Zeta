@IsTest(IsParallel=true)
private class SchoolSelectionControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SchoolSelectionController.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void getEligibleSchools_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SchoolSelectionController.getEligibleSchools(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void getEligibleSchools_blankGrade_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = null)
        }
      );

    try {
      SchoolSelectionController.getEligibleSchools(appId);
      Assert.fail('Should throw when application has no grade');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('grade'));
    }
  }

  @IsTest
  private static void getEligibleSchools_noTimeline_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Grade_Applying_To__c = 'K',
            Application_Timeline__c = null
          )
        }
      );

    try {
      SchoolSelectionController.getEligibleSchools(appId);
      Assert.fail('Should throw when application has no timeline link');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('timeline'));
    }
  }

  @IsTest
  private static void getEligibleSchools_studentHasAddress_homeUsesStudent() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    Map<String, Object> appShape = new Map<String, Object>{
      'attributes' => new Map<String, String>{ 'type' => 'IndividualApplication' },
      'Id' => appId,
      'Grade_Applying_To__c' => 'K',
      'Application_Timeline__c' => timelineId,
      'AccountId' => studentId,
      'Account' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'Account' },
        'Id' => studentId,
        'PersonMailingStreet' => '99 Student Blvd',
        'PersonMailingCity' => 'Queens',
        'PersonMailingState' => 'NY',
        'PersonMailingPostalCode' => '11375'
      },
      'Primary_Guardian__r' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'Account' },
        'Id' => guardianId,
        'PersonMailingStreet' => '5 Guardian Way',
        'PersonMailingCity' => 'Brooklyn',
        'PersonMailingState' => 'NY',
        'PersonMailingPostalCode' => '11201'
      }
    };
    IndividualApplication hydratedApp = (IndividualApplication) JSON.deserialize(
      JSON.serialize(appShape),
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ hydratedApp })
      .thenReturn(new List<Lottery_Capacity__c>());

    Map<String, Object> result = SchoolSelectionController.getEligibleSchools(appId);

    Map<String, Object> home = (Map<String, Object>) result.get('homeAddress');
    Assert.areEqual(
      '99 Student Blvd',
      home.get('street'),
      'home pin should follow student address'
    );
    Assert.areEqual('11375', home.get('postalCode'));
  }

  @IsTest
  private static void getEligibleSchools_studentBlank_fallsBackToGuardian() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    // Student account present but no mailing address -> must fall back to guardian.
    Map<String, Object> appShape = new Map<String, Object>{
      'attributes' => new Map<String, String>{ 'type' => 'IndividualApplication' },
      'Id' => appId,
      'Grade_Applying_To__c' => 'K',
      'Application_Timeline__c' => timelineId,
      'AccountId' => studentId,
      'Account' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'Account' },
        'Id' => studentId
      },
      'Primary_Guardian__r' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'Account' },
        'Id' => guardianId,
        'PersonMailingStreet' => '5 Guardian Way',
        'PersonMailingCity' => 'Brooklyn',
        'PersonMailingState' => 'NY',
        'PersonMailingPostalCode' => '11201'
      }
    };
    IndividualApplication hydratedApp = (IndividualApplication) JSON.deserialize(
      JSON.serialize(appShape),
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ hydratedApp })
      .thenReturn(new List<Lottery_Capacity__c>());

    Map<String, Object> result = SchoolSelectionController.getEligibleSchools(appId);

    Map<String, Object> home = (Map<String, Object>) result.get('homeAddress');
    Assert.areEqual(
      '5 Guardian Way',
      home.get('street'),
      'home pin should fall back to guardian when student address is blank'
    );
  }

  @IsTest
  private static void getEligibleSchools_happyPath_returnsSchoolsAndHomeAddress() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id schoolAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id capId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id learningProgramId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id academicTermId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    Map<String, Object> capacityShape = new Map<String, Object>{
      'attributes' => new Map<String, String>{ 'type' => 'Lottery_Capacity__c' },
      'Id' => capId,
      'Grade__c' => 'K',
      'Program_Term_Application_Timeline__r' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'ProgramTermApplicationTimeline' },
        'LearningProgramId' => learningProgramId,
        'AcademicTermId' => academicTermId,
        'LearningProgram' => new Map<String, Object>{
          'attributes' => new Map<String, String>{ 'type' => 'LearningProgram' },
          'School__c' => schoolAcctId,
          'School__r' => new Map<String, Object>{
            'attributes' => new Map<String, String>{ 'type' => 'Account' },
            'Id' => schoolAcctId,
            'Name' => 'Test School Account',
            'Zeta_School_Name__c' => 'Zeta Test School',
            'BillingStreet' => '123 Main St',
            'BillingCity' => 'Brooklyn',
            'BillingState' => 'NY',
            'BillingPostalCode' => '11201'
          }
        }
      }
    };
    Lottery_Capacity__c hydratedCap = (Lottery_Capacity__c) JSON.deserialize(
      JSON.serialize(capacityShape),
      Lottery_Capacity__c.class
    );

    Map<String, Object> appShape = new Map<String, Object>{
      'attributes' => new Map<String, String>{ 'type' => 'IndividualApplication' },
      'Id' => appId,
      'Grade_Applying_To__c' => 'K',
      'Application_Timeline__c' => timelineId,
      'AccountId' => guardianId,
      'Primary_Guardian__r' => new Map<String, Object>{
        'attributes' => new Map<String, String>{ 'type' => 'Account' },
        'Id' => guardianId,
        'PersonMailingStreet' => '5 Guardian Way',
        'PersonMailingCity' => 'Brooklyn',
        'PersonMailingState' => 'NY',
        'PersonMailingPostalCode' => '11201'
      }
    };
    IndividualApplication hydratedApp = (IndividualApplication) JSON.deserialize(
      JSON.serialize(appShape),
      IndividualApplication.class
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ hydratedApp })
      .thenReturn(new List<Lottery_Capacity__c>{ hydratedCap });

    Map<String, Object> result = SchoolSelectionController.getEligibleSchools(appId);

    List<Object> schools = (List<Object>) result.get('schools');
    Assert.areEqual(1, schools.size());
    Map<String, Object> school = (Map<String, Object>) schools[0];
    Assert.areEqual(schoolAcctId, school.get('schoolAccountId'));
    Assert.areEqual('Zeta Test School', school.get('name'));
    Assert.areEqual(capId, school.get('lotteryCapacityId'));
    Assert.areEqual('K', result.get('grade'));

    Map<String, Object> home = (Map<String, Object>) result.get('homeAddress');
    Assert.areEqual('5 Guardian Way', home.get('street'));
  }

  @IsTest
  private static void getSelectedSchools_returnsDraftMapping() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<AcademicInterest>{
          new AcademicInterest(Id = interestId, Lottery_Capacity__c = capId, School_Rank__c = 1)
        }
      );

    List<Map<String, Object>> result = SchoolSelectionController.getSelectedSchools(appId);

    Assert.areEqual(1, result.size());
    Assert.areEqual(interestId, result[0].get('academicInterestId'));
    Assert.areEqual(capId, result[0].get('lotteryCapacityId'));
    Assert.areEqual(1, result[0].get('rank'));
  }

  @IsTest
  private static void getSelectedSchools_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SchoolSelectionController.getSelectedSchools(null);
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }

  @IsTest
  private static void saveSchoolSelections_replacesDrafts() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id learningProgramId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id capId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicTermId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);
    Id existingDraftId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    String selectionsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'schoolAccountId' => schoolId,
          'learningProgramId' => learningProgramId,
          'lotteryCapacityId' => capId,
          'academicTermId' => academicTermId
        }
      }
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = 'K')
        }
      )
      .thenReturn(
        new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capId, Grade__c = 'K') }
      )
      .thenReturn(new List<AcademicInterest>{ new AcademicInterest(Id = existingDraftId) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.deleteSObjects()).thenReturnVoid();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SchoolSelectionController.saveSchoolSelections(appId, selectionsJson);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void saveSchoolSelections_noPriorDrafts_skipsDelete() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id learningProgramId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id capId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicTermId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    String selectionsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'schoolAccountId' => schoolId,
          'learningProgramId' => learningProgramId,
          'lotteryCapacityId' => capId,
          'academicTermId' => academicTermId
        }
      }
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = '1')
        }
      )
      .thenReturn(
        new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capId, Grade__c = '1') }
      )
      .thenReturn(new List<AcademicInterest>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SchoolSelectionController.saveSchoolSelections(appId, selectionsJson);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void saveSchoolSelections_rejectsGradeMismatch() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id learningProgramId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id capId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicTermId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    String selectionsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'schoolAccountId' => schoolId,
          'learningProgramId' => learningProgramId,
          'lotteryCapacityId' => capId,
          'academicTermId' => academicTermId
        }
      }
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Grade_Applying_To__c = 'K')
        }
      )
      .thenReturn(
        new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capId, Grade__c = '1') }
      );

    try {
      SchoolSelectionController.saveSchoolSelections(appId, selectionsJson);
      Assert.fail('Should throw when capacity grade does not match application grade');
    } catch (AuraHandledException e) {
      // AuraHandledException message is opaque ('Script-thrown exception') outside Aura context;
      // existence of the throw is what we verify
    }

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.deleteSObjects());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.insertSObjects());
  }

  @IsTest
  private static void saveSchoolSelections_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SchoolSelectionController.saveSchoolSelections(null, '[]');
      Assert.fail('Should throw for null applicationId');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Application Id is required'));
    }
  }
}