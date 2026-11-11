/**
 * Tests for {@link ContactApplicationRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class ContactApplicationRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final ContactApplicationRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new ContactApplicationRollupServiceImpl(MOCK_REPO);
  }

  private static Map<String, Object> academicInterest(
    String schoolName,
    Decimal rank,
    String status
  ) {
    return new Map<String, Object>{
      'fx_SchoolName__c' => schoolName,
      'School_Rank__c' => rank,
      'Status' => status
    };
  }

  private static IndividualApplication buildApplication(
    Id accountId,
    Id primaryGuardianId,
    String leadSource,
    Integer startYear,
    Integer endYear,
    String timelineName,
    List<Map<String, Object>> academicInterests
  ) {
    Map<String, Object> timelineMap;
    if (startYear != null) {
      timelineMap = new Map<String, Object>{
        'Name' => timelineName,
        'Academic_Term__r' => new Map<String, Object>{
          'StartDate' => Date.newInstance(startYear, 8, 1),
          'EndDate' => Date.newInstance(endYear, 6, 1)
        }
      };
    } else {
      timelineMap = new Map<String, Object>{ 'Name' => timelineName };
    }

    Map<String, Object> applicationMap = new Map<String, Object>{
      'AccountId' => accountId,
      'Primary_Guardian__c' => primaryGuardianId,
      'Lead_Source__c' => leadSource,
      'Application_Timeline__r' => timelineMap,
      'AcademicInterests' => new Map<String, Object>{
        'totalSize' => academicInterests.size(),
        'done' => true,
        'records' => academicInterests
      }
    };

    return (IndividualApplication) JSON.deserialize(
      JSON.serialize(applicationMap),
      IndividualApplication.class
    );
  }

  /**
   * IsPersonAccount is a read-only system field, so it cannot be set through
   * the Account constructor; JSON.deserialize populates it the same way a
   * query result would.
   */
  private static Account buildPersonAccount(
    Id accountId,
    Boolean isPersonAccount,
    String schoolApplicationsValue,
    String leadSourcesValue
  ) {
    Map<String, Object> accountMap = new Map<String, Object>{
      'Id' => accountId,
      'IsPersonAccount' => isPersonAccount,
      'School_Applications__pc' => schoolApplicationsValue,
      'Application_Lead_Sources__pc' => leadSourcesValue
    };
    return (Account) JSON.deserialize(JSON.serialize(accountMap), Account.class);
  }

  @IsTest
  private static void buildSchoolApplicationsValue_twoYears_newestFirst() {
    IndividualApplication earlierYear = buildApplication(
      null,
      null,
      null,
      2026,
      2027,
      null,
      new List<Map<String, Object>>{ academicInterest('Zeta Inwood', 1, 'Submitted') }
    );
    IndividualApplication laterYear = buildApplication(
      null,
      null,
      null,
      2027,
      2028,
      null,
      new List<Map<String, Object>>{ academicInterest('Zeta Queens', 1, 'Submitted') }
    );

    String result = ContactApplicationRollupServiceImpl.buildSchoolApplicationsValue(
      new List<IndividualApplication>{ earlierYear, laterYear }
    );

    Assert.areEqual(
      '2027 - 2028: Zeta Queens; 2026 - 2027: Zeta Inwood',
      result,
      'Should list the newer year first'
    );
  }

  @IsTest
  private static void buildSchoolApplicationsValue_dedupesAcrossTwoApplicationsInOneYear() {
    IndividualApplication application1 = buildApplication(
      null,
      null,
      null,
      2027,
      2028,
      null,
      new List<Map<String, Object>>{ academicInterest('Zeta Inwood', 2, 'Submitted') }
    );
    IndividualApplication application2 = buildApplication(
      null,
      null,
      null,
      2027,
      2028,
      null,
      new List<Map<String, Object>>{ academicInterest('Zeta Inwood', 1, 'Submitted') }
    );

    String result = ContactApplicationRollupServiceImpl.buildSchoolApplicationsValue(
      new List<IndividualApplication>{ application1, application2 }
    );

    Assert.areEqual('2027 - 2028: Zeta Inwood', result, 'Should merge into a single entry');
  }

  @IsTest
  private static void buildSchoolApplicationsValue_ordersByRankWithinYear() {
    IndividualApplication application = buildApplication(
      null,
      null,
      null,
      2027,
      2028,
      null,
      new List<Map<String, Object>>{
        academicInterest('Zeta Queens', 2, 'Submitted'),
        academicInterest('Zeta Inwood', 1, 'Submitted')
      }
    );

    String result = ContactApplicationRollupServiceImpl.buildSchoolApplicationsValue(
      new List<IndividualApplication>{ application }
    );

    Assert.areEqual(
      '2027 - 2028: Zeta Inwood; Zeta Queens',
      result,
      'Should order schools by rank within the year'
    );
  }

  @IsTest
  private static void buildSchoolApplicationsValue_noTermTimeline_usesTimelineNameAsLabel() {
    IndividualApplication application = buildApplication(
      null,
      null,
      null,
      null,
      null,
      'Rolling Admissions',
      new List<Map<String, Object>>{ academicInterest('Zeta Inwood', 1, 'Submitted') }
    );

    String result = ContactApplicationRollupServiceImpl.buildSchoolApplicationsValue(
      new List<IndividualApplication>{ application }
    );

    Assert.areEqual(
      'Rolling Admissions: Zeta Inwood',
      result,
      'Should label a no-term timeline with its own Name'
    );
  }

  @IsTest
  private static void buildLeadSourcesValue_dedupesValues() {
    IndividualApplication application1 = buildApplication(
      null,
      null,
      'Website',
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );
    IndividualApplication application2 = buildApplication(
      null,
      null,
      'Website',
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );

    String result = ContactApplicationRollupServiceImpl.buildLeadSourcesValue(
      new List<IndividualApplication>{ application1, application2 }
    );

    Assert.areEqual('Website', result, 'Should dedupe identical lead sources');
  }

  @IsTest
  private static void buildLeadSourcesValue_sortsAlphabetically() {
    IndividualApplication application1 = buildApplication(
      null,
      null,
      'Website',
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );
    IndividualApplication application2 = buildApplication(
      null,
      null,
      'Open House',
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );

    String result = ContactApplicationRollupServiceImpl.buildLeadSourcesValue(
      new List<IndividualApplication>{ application1, application2 }
    );

    Assert.areEqual('Open House; Website', result, 'Should sort alphabetically');
  }

  @IsTest
  private static void buildLeadSourcesValue_dropsBlankValues() {
    IndividualApplication application1 = buildApplication(
      null,
      null,
      'Website',
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );
    IndividualApplication application2 = buildApplication(
      null,
      null,
      null,
      null,
      null,
      null,
      new List<Map<String, Object>>()
    );

    String result = ContactApplicationRollupServiceImpl.buildLeadSourcesValue(
      new List<IndividualApplication>{ application1, application2 }
    );

    Assert.areEqual('Website', result, 'Should drop the blank value');
  }

  @IsTest
  private static void processResults_personWithNoRemainingApplications_clearsBothFields() {
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    Id personId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    SERVICE.processResults(
      new List<IndividualApplication>(),
      new List<Account>{ buildPersonAccount(personId, true, '2026 - 2027: Zeta Inwood', 'Website') }
    );

    List<Map<String, Object>> calls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, calls.size(), 'Should update once');
    Account updated = (Account) ((List<SObject>) calls[0].get('sobjects'))[0];
    Assert.isNull(updated.School_Applications__pc, 'Should clear School Applications');
    Assert.isNull(updated.Application_Lead_Sources__pc, 'Should clear Application Lead Sources');
  }

  @IsTest
  private static void recalculate_withUnchangedValues_doesNotUpdate() {
    Id personId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>())
      .thenReturn(new List<Account>{ buildPersonAccount(personId, true, null, null) });

    SERVICE.recalculate(new Set<Id>{ personId });

    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void processResults_nonPersonAccount_isSkipped() {
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    SERVICE.processResults(
      new List<IndividualApplication>(),
      new List<Account>{ buildPersonAccount(accountId, false, null, null) }
    );

    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void processResults_oneApplication_stampsBothStudentAndGuardian() {
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();
    Id studentId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    IndividualApplication application = buildApplication(
      studentId,
      guardianId,
      'Website',
      2027,
      2028,
      null,
      new List<Map<String, Object>>{ academicInterest('Zeta Inwood', 1, 'Submitted') }
    );

    SERVICE.processResults(
      new List<IndividualApplication>{ application },
      new List<Account>{
        buildPersonAccount(studentId, true, null, null),
        buildPersonAccount(guardianId, true, null, null)
      }
    );

    List<Map<String, Object>> calls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Assert.areEqual(1, calls.size(), 'Should update once');
    Map<Id, Account> updatedById = new Map<Id, Account>();
    for (SObject record : (List<SObject>) calls[0].get('sobjects')) {
      updatedById.put(record.Id, (Account) record);
    }
    Assert.areEqual(2, updatedById.size(), 'Should stamp both the student and the guardian');
    Assert.areEqual(
      '2027 - 2028: Zeta Inwood',
      updatedById.get(studentId).School_Applications__pc,
      'Should stamp the student'
    );
    Assert.areEqual(
      '2027 - 2028: Zeta Inwood',
      updatedById.get(guardianId).School_Applications__pc,
      'Should stamp the guardian'
    );
  }

  @IsTest
  private static void recalculate_withEmptyOrNullSet_doesNotQuery() {
    SERVICE.recalculate(new Set<Id>());
    SERVICE.recalculate(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }
}