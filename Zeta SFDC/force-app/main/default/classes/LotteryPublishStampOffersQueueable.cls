/**
 * Queueable job that stamps offer-related fields on IndividualApplication records
 * after a lottery run is published.
 *
 * For each student with a Pre-Offer:
 * - Current_School_Offer__c: Highest-ranked school offer (lowest School_Rank__c)
 * - Date_of_First_Offer__c: Only if not already set (preserves original offer date)
 * - Offer_Expiration_Date__c: Configured days from publish
 *
 * After stamping, chains to {@link LotteryPublishTransitionQueueable} to transition
 * Pre-Offer AcademicInterests to Seat Offered.
 */
public with sharing class LotteryPublishStampOffersQueueable implements Queueable {
  private final Id runLogId;
  private final Datetime publishTime;
  private final Date expirationDate;
  private final DatabaseRepo databaseRepo;

  @TestVisible
  private static Boolean chainToTransition = true;

  public LotteryPublishStampOffersQueueable(
    Id runLogId,
    Datetime publishTime,
    Date expirationDate
  ) {
    this(runLogId, publishTime, expirationDate, new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryPublishStampOffersQueueable(
    Id runLogId,
    Datetime publishTime,
    Date expirationDate,
    DatabaseRepo databaseRepo
  ) {
    this.runLogId = runLogId;
    this.publishTime = publishTime;
    this.expirationDate = expirationDate;
    this.databaseRepo = databaseRepo;
  }

  public void execute(QueueableContext context) {
    stampIndividualApplicationOffers();
    if (chainToTransition) {
      System.enqueueJob(new LotteryPublishTransitionQueueable(runLogId));
    }
  }

  private void stampIndividualApplicationOffers() {
    String aiQuery =
      'SELECT Id, IndividualApplicationId, School_Rank__c ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__r.Lottery_Run_Log__c = :runLogId ' +
      'AND Status = :preOfferStatus ' +
      'ORDER BY School_Rank__c ASC';

    List<AcademicInterest> preOffers = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      aiQuery,
      new Map<String, Object>{
        'runLogId' => runLogId,
        'preOfferStatus' => LotteryConstants.STATUS_PRE_OFFER
      }
    );

    if (preOffers.isEmpty()) {
      return;
    }

    // Group by IndividualApplication, keeping only highest-ranked offer per student
    // (first one in sorted order = lowest School_Rank__c = best rank)
    Map<Id, Id> bestOfferByApplication = new Map<Id, Id>();
    for (AcademicInterest ai : preOffers) {
      if (
        ai.IndividualApplicationId != null &&
        !bestOfferByApplication.containsKey(ai.IndividualApplicationId)
      ) {
        bestOfferByApplication.put(ai.IndividualApplicationId, ai.Id);
      }
    }

    Set<Id> applicationIds = bestOfferByApplication.keySet();
    String appQuery =
      'SELECT Id, Date_of_First_Offer__c ' +
      'FROM IndividualApplication ' +
      'WHERE Id IN :applicationIds';

    List<IndividualApplication> applications = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      appQuery,
      new Map<String, Object>{ 'applicationIds' => applicationIds }
    );

    for (IndividualApplication app : applications) {
      app.Current_School_Offer__c = bestOfferByApplication.get(app.Id);
      app.Offer_Expiration_Date__c = expirationDate;
      // Only stamp first offer date if not already set
      if (app.Date_of_First_Offer__c == null) {
        app.Date_of_First_Offer__c = publishTime;
      }
    }

    if (!applications.isEmpty()) {
      databaseRepo.updateSObjects(applications);
    }
  }
}