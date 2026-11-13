@IsTest(IsParallel=true)
private class SchoolSelectionControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
    SchoolSelectionController.databaseRepo = DATABASE_REPO_MOCK;
    SchoolSelectionController.eventBusRepo = EVENT_BUS_REPO_MOCK;
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
  private static void saveSchoolSelections_singleSchool_ranksFirst() {
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
        new List<Lottery_Capacity__c>{ new Lottery_Capacity__c(Id = capId, Grade__c = 'K') }
      )
      .thenReturn(new List<AcademicInterest>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SchoolSelectionController.saveSchoolSelections(appId, selectionsJson);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> inserted = (List<SObject>) inserts[0].get('sobjects');
    Assert.areEqual(1, inserted.size(), 'One selection should insert one AcademicInterest');
    Assert.areEqual(
      1,
      ((AcademicInterest) inserted[0]).School_Rank__c,
      'A lone chosen school must be ranked first'
    );
  }

  @IsTest
  private static void saveSchoolSelections_twoSchools_leavesRanksNull() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id firstSchoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id secondSchoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id learningProgramId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id firstCapId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id secondCapId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id academicTermId = SObjectIds.generateFakeId(Schema.AcademicTerm.SObjectType);

    String selectionsJson = JSON.serialize(
      new List<Map<String, Object>>{
        new Map<String, Object>{
          'schoolAccountId' => firstSchoolId,
          'learningProgramId' => learningProgramId,
          'lotteryCapacityId' => firstCapId,
          'academicTermId' => academicTermId
        },
        new Map<String, Object>{
          'schoolAccountId' => secondSchoolId,
          'learningProgramId' => learningProgramId,
          'lotteryCapacityId' => secondCapId,
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
        new List<Lottery_Capacity__c>{
          new Lottery_Capacity__c(Id = firstCapId, Grade__c = 'K'),
          new Lottery_Capacity__c(Id = secondCapId, Grade__c = 'K')
        }
      )
      .thenReturn(new List<AcademicInterest>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();

    SchoolSelectionController.saveSchoolSelections(appId, selectionsJson);

    List<Map<String, Object>> inserts = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.insertSObjects()
    );
    List<SObject> inserted = (List<SObject>) inserts[0].get('sobjects');
    Assert.areEqual(2, inserted.size(), 'Two selections should insert two AcademicInterests');
    Assert.isNull(
      ((AcademicInterest) inserted[0]).School_Rank__c,
      'The ranking step owns ranks when more than one school is chosen'
    );
    Assert.isNull(
      ((AcademicInterest) inserted[1]).School_Rank__c,
      'The ranking step owns ranks when more than one school is chosen'
    );
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

  // ---- SFR-216: addSchools ----

  // Queues addSchools' application, getEligibleSchools' application + offered capacity, and the
  // school choices already on the application.
  private static void queueAddSchools(Id appId, Id capacityId, Id schoolId, AcademicInterest onApp) {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Status = 'Applied', AppliedDate = Datetime.now())
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Grade_Applying_To__c = 'K',
            Application_Timeline__c = SObjectIds.generateFakeId(
              Schema.ApplicationTimeline.SObjectType
            )
          )
        }
      )
      .thenReturn(
        new List<Lottery_Capacity__c>{
          (Lottery_Capacity__c) JSON.deserialize(
            JSON.serialize(
              new Map<String, Object>{
                'attributes' => new Map<String, String>{ 'type' => 'Lottery_Capacity__c' },
                'Id' => capacityId,
                'Program_Term_Application_Timeline__r' => new Map<String, Object>{
                  'attributes' => new Map<String, String>{
                    'type' => 'ProgramTermApplicationTimeline'
                  },
                  'LearningProgram' => new Map<String, Object>{
                    'attributes' => new Map<String, String>{ 'type' => 'LearningProgram' },
                    'School__c' => schoolId,
                    'School__r' => new Map<String, Object>{
                      'attributes' => new Map<String, String>{ 'type' => 'Account' },
                      'Name' => 'Zeta Bronx'
                    }
                  }
                }
              }
            ),
            Lottery_Capacity__c.class
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ onApp });
  }

  @IsTest
  private static void addSchools_addsAsAppliedAfterTheLastRank() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    queueAddSchools(appId, capacityId, schoolId, new AcademicInterest(School_Rank__c = 2));
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    SchoolSelectionController.addSchools(appId, new List<Id>{ capacityId });

    AcademicInterest added = (AcademicInterest) ((List<SObject>) DATABASE_REPO_MOCK.getCalls(
        DATABASE_REPO_MOCK.method.insertSObjects()
      )[0]
      .get('sobjects'))[0];
    Assert.areEqual(schoolId, added.AccountId);
    Assert.areEqual('Applied', added.Status);
    Assert.areEqual(3, added.School_Rank__c.intValue(), 'Added after the existing choices');
    EVENT_BUS_REPO_MOCK.verify(EVENT_BUS_REPO_MOCK.method.publishSingle());
  }

  @IsTest
  private static void addSchools_windowClosed_throws() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            AppliedDate = Datetime.now(),
            Application_Timeline__r = new ApplicationTimeline(ApplicationCloseDate = Date.today() - 1)
          )
        }
      );

    try {
      SchoolSelectionController.addSchools(
        SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType),
        new List<Id>()
      );
      Assert.fail('Schools must not be added after the application window closes');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('window is open'), e.getMessage());
    }
  }

  @IsTest
  private static void addSchools_schoolAlreadyOnApplication_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    // A choice's AccountId holds the student; the school is on its learning program.
    queueAddSchools(
      appId,
      capacityId,
      schoolId,
      new AcademicInterest(
        AccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType),
        LearningProgram = new LearningProgram(School__c = schoolId)
      )
    );

    try {
      SchoolSelectionController.addSchools(appId, new List<Id>{ capacityId });
      Assert.fail('A school already on the application must not be added again');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('can\'t be added'), e.getMessage());
    }
  }
}
