/**
 * Queueable job that transitions Pre-Offer AcademicInterests to Seat Offered status
 * after a lottery run is published.
 *
 * Chained from {@link LotteryPublishStampOffersQueueable} to isolate CPU and DML budgets.
 */
public with sharing class LotteryPublishTransitionQueueable implements Queueable {
  private final Id runLogId;
  private final DatabaseRepo databaseRepo;

  public LotteryPublishTransitionQueueable(Id runLogId) {
    this(runLogId, new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotteryPublishTransitionQueueable(Id runLogId, DatabaseRepo databaseRepo) {
    this.runLogId = runLogId;
    this.databaseRepo = databaseRepo;
  }

  public void execute(QueueableContext context) {
    String query =
      'SELECT Id, Status ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__r.Lottery_Run_Log__c = :runLogId ' +
      'AND Status = :preOfferStatus';

    List<AcademicInterest> preOfferRecords = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'runLogId' => runLogId,
        'preOfferStatus' => LotteryConstants.STATUS_PRE_OFFER
      }
    );

    if (preOfferRecords.isEmpty()) {
      return;
    }

    for (AcademicInterest ai : preOfferRecords) {
      ai.Status = LotteryConstants.STATUS_SEAT_OFFERED;
    }

    databaseRepo.updateSObjects(preOfferRecords);
  }
}