/**
 * Tests for {@link LotteryPublishTransitionQueueable}.
 */
@IsTest(IsParallel=true)
private class LotteryPublishTransitionQueueableTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    LotteryPublishTransitionQueueable queueable = new LotteryPublishTransitionQueueable(runLogId);

    Assert.isNotNull(queueable, 'Should be instantiable');
  }

  @IsTest
  private static void execute_transitionsPreOffersToSeatOffered() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest ai1 = new AcademicInterest(
      Id = aiId1,
      Status = LotteryConstants.STATUS_PRE_OFFER
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = aiId2,
      Status = LotteryConstants.STATUS_PRE_OFFER
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai1, ai2 });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    new LotteryPublishTransitionQueueable(runLogId, DATABASE_REPO_MOCK).execute(null);

    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      ai1.Status,
      'First AI should be transitioned to Seat Offered'
    );
    Assert.areEqual(
      LotteryConstants.STATUS_SEAT_OFFERED,
      ai2.Status,
      'Second AI should be transitioned to Seat Offered'
    );
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_withNoPreOffers_skipsUpdate() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    new LotteryPublishTransitionQueueable(runLogId, DATABASE_REPO_MOCK).execute(null);

    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }
}