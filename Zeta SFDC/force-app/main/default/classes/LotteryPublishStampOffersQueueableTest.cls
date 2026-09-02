/**
 * Tests for {@link LotteryPublishStampOffersQueueable}.
 */
@IsTest(IsParallel=true)
private class LotteryPublishStampOffersQueueableTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    LotteryPublishStampOffersQueueable queueable = new LotteryPublishStampOffersQueueable(
      runLogId,
      Datetime.now(),
      Date.today().addDays(14)
    );

    Assert.isNotNull(queueable, 'Should be instantiable');
  }

  @IsTest
  private static void execute_withPreOffers_stampsCorrectFields() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id aiId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aiId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Datetime publishTime = Datetime.now();
    Date expirationDate = Date.today().addDays(14);

    // ai1 has School_Rank 1, ai2 has School_Rank 2 - same student
    AcademicInterest ai1 = new AcademicInterest(
      Id = aiId1,
      IndividualApplicationId = appId,
      School_Rank__c = 1
    );
    AcademicInterest ai2 = new AcademicInterest(
      Id = aiId2,
      IndividualApplicationId = appId,
      School_Rank__c = 2
    );

    IndividualApplication app = new IndividualApplication(Id = appId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai1, ai2 })
      .thenReturn(new List<IndividualApplication>{ app });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    new LotteryPublishStampOffersQueueable(
        runLogId,
        publishTime,
        expirationDate,
        DATABASE_REPO_MOCK
      )
      .execute(null);

    Assert.areEqual(aiId1, app.Current_School_Offer__c, 'Should set best offer (lowest rank)');
    Assert.areEqual(expirationDate, app.Offer_Expiration_Date__c, 'Should set expiration date');
    Assert.areEqual(publishTime, app.Date_of_First_Offer__c, 'Should set first offer date');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_preservesExistingDateOfFirstOffer() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Id aiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Datetime publishTime = Datetime.now();
    Date expirationDate = Date.today().addDays(14);
    Datetime existingOfferDate = Datetime.now().addDays(-30);

    AcademicInterest ai = new AcademicInterest(
      Id = aiId,
      IndividualApplicationId = appId,
      School_Rank__c = 1
    );

    IndividualApplication app = new IndividualApplication(
      Id = appId,
      Date_of_First_Offer__c = existingOfferDate
    );

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ ai })
      .thenReturn(new List<IndividualApplication>{ app });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    new LotteryPublishStampOffersQueueable(
        runLogId,
        publishTime,
        expirationDate,
        DATABASE_REPO_MOCK
      )
      .execute(null);

    Assert.areEqual(
      existingOfferDate,
      app.Date_of_First_Offer__c,
      'Should preserve existing first offer date'
    );
  }

  @IsTest
  private static void execute_withNoPreOffers_skipsUpdate() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Datetime publishTime = Datetime.now();
    Date expirationDate = Date.today().addDays(14);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    new LotteryPublishStampOffersQueueable(
        runLogId,
        publishTime,
        expirationDate,
        DATABASE_REPO_MOCK
      )
      .execute(null);

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 1);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void execute_chainsToTransitionQueueable() {
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);
    Datetime publishTime = Datetime.now();
    Date expirationDate = Date.today().addDays(14);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    new LotteryPublishStampOffersQueueable(
        runLogId,
        publishTime,
        expirationDate,
        DATABASE_REPO_MOCK
      )
      .execute(null);

    Assert.areEqual(1, Limits.getQueueableJobs(), 'Should enqueue transition queueable');
  }
}