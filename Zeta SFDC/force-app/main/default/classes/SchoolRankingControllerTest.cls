@IsTest(IsParallel=true)
private class SchoolRankingControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SchoolRankingController.databaseRepo = DATABASE_REPO_MOCK;
  }

  @IsTest
  private static void getRankedSchools_returnsAllSchoolsRegardlessOfStatus() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai3 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> interests = new List<AcademicInterest>{
      new AcademicInterest(Id = ai1, School_Rank__c = 1),
      new AcademicInterest(Id = ai2, School_Rank__c = 2),
      new AcademicInterest(Id = ai3, School_Rank__c = 3)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds()).thenReturn(interests);

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.areEqual(
      3,
      result.size(),
      'Should return all schools regardless of AcademicInterest.Status'
    );
    Assert.areEqual(ai1, (Id) result[0].get('academicInterestId'));
    Assert.areEqual(1, (Decimal) result[0].get('rank'));
  }

  @IsTest
  private static void getRankedSchools_singleSchool_returns() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ new AcademicInterest(Id = ai, School_Rank__c = 1) });

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.areEqual(1, result.size(), 'Single school should still be returned');
    Assert.areEqual(ai, (Id) result[0].get('academicInterestId'));
  }

  @IsTest
  private static void getRankedSchools_emptyResult_returnsEmpty() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    List<Map<String, Object>> result = SchoolRankingController.getRankedSchools(applicationId);

    Assert.isTrue(result.isEmpty(), 'No interests should return empty list');
  }

  @IsTest
  private static void getRankedSchools_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SchoolRankingController.getRankedSchools(null);
      Assert.fail('Expected exception for null Id');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }
  }

  @IsTest
  private static void saveRankings_persistsRanks() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id ai2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json =
      '[{"academicInterestId":"' +
      ai1 +
      '","rank":1},' +
      '{"academicInterestId":"' +
      ai2 +
      '","rank":2}]';

    SchoolRankingController.saveRankings(applicationId, json);

    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, calls.size(), 'Should call updateSObjects once');
    List<SObject> updated = (List<SObject>) calls[0].get('sobjects');
    Assert.areEqual(2, updated.size(), 'Should update both records');
    Assert.areEqual(1, (Decimal) updated[0].get('School_Rank__c'));
    Assert.areEqual(2, (Decimal) updated[1].get('School_Rank__c'));
  }

  @IsTest
  private static void saveRankings_emptyList_skipsUpdate() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolRankingController.saveRankings(applicationId, '[]');

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Empty rankings should not trigger an update'
    );
  }

  @IsTest
  private static void saveRankings_nullId_throws() {
    DATABASE_REPO_MOCK.reset();

    try {
      SchoolRankingController.saveRankings(null, '[]');
      Assert.fail('Expected exception for null Id');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  private static void saveRankings_blankJson_throws() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    try {
      SchoolRankingController.saveRankings(applicationId, '');
      Assert.fail('Expected exception for blank JSON');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  private static void saveRankings_draftApp_doesNotEnqueueRegeneration() {
    // Only the draft branch is unit-testable. The submitted branch enqueues
    // ApplicationPdfQueueable, whose getContentAsPDF() throws an uncatchable error
    // in test context; that path is verified in the E2E guide.
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          // AppliedDate null -> draft; no PDF exists yet, so nothing to regenerate
          new IndividualApplication(Id = applicationId, Status = 'Applied')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json = '[{"academicInterestId":"' + ai + '","rank":1}]';

    Integer before = Limits.getQueueableJobs();
    SchoolRankingController.saveRankings(applicationId, json);

    Assert.areEqual(
      before,
      Limits.getQueueableJobs(),
      'Draft app (no AppliedDate) must not enqueue a PDF regeneration'
    );
  }

  @IsTest
  private static void saveRankings_withdrawnApp_throws() {
    DATABASE_REPO_MOCK.reset();

    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id ai = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Status = 'Withdrawn/Declined')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    String json = '[{"academicInterestId":"' + ai + '","rank":1}]';

    try {
      SchoolRankingController.saveRankings(applicationId, json);
      Assert.fail('Expected exception for withdrawn application');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage(), 'Should throw with a message');
    }

    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'Withdrawn application should not trigger a rankings update'
    );
  }
}