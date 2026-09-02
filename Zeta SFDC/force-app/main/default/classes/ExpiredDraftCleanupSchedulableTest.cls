@IsTest(IsParallel=true)
private class ExpiredDraftCleanupSchedulableTest {
  private static final ExpiredDraftCleanupSchedulable SCHEDULABLE;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SCHEDULABLE = new ExpiredDraftCleanupSchedulable(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void execute_withNoClosedTimelines_doesNotQueryDrafts() {
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<ApplicationTimeline>());

    SCHEDULABLE.execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void execute_withClosedTimelineAndDrafts_setsStatusToExpired() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    List<ApplicationTimeline> closedTimelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(Id = timelineId)
    };

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<IndividualApplication> drafts = new List<IndividualApplication>{
      new IndividualApplication(Id = appId, Status = 'Draft')
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(closedTimelines)
      .thenReturn(drafts);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturn(null);

    SCHEDULABLE.execute(null);

    Assert.areEqual('Expired', drafts[0].Status, 'Should set status to Expired');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withClosedTimelineAndNoDrafts_doesNotUpdate() {
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    List<ApplicationTimeline> closedTimelines = new List<ApplicationTimeline>{
      new ApplicationTimeline(Id = timelineId)
    };

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(closedTimelines)
      .thenReturn(new List<IndividualApplication>());

    SCHEDULABLE.execute(null);
  }
}