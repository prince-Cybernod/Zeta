/**
 * Implementation of {@link SeatOfferWithdrawalService}.
 *
 * Withdraws lower-ranked school applications when a student receives a seat offer.
 * Queries cross-capacity records via SOQL to find all of a student's applications
 * regardless of which capacities are in the current run.
 */
public with sharing class SeatOfferWithdrawalServiceImpl implements SeatOfferWithdrawalService {
  private final DatabaseRepo databaseRepo;

  public SeatOfferWithdrawalServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private SeatOfferWithdrawalServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public List<AcademicInterest> withdrawLowerRankedApplications(
    List<AcademicInterest> offeredRecords,
    Set<Id> excludeRecordIds,
    List<LotteryStatusChange> transitions
  ) {
    if (offeredRecords == null || offeredRecords.isEmpty()) {
      return new List<AcademicInterest>();
    }

    Map<Id, Decimal> bestRankByApplication = findBestRankByApplication(offeredRecords);
    if (bestRankByApplication.isEmpty()) {
      return new List<AcademicInterest>();
    }

    Set<Id> appIds = bestRankByApplication.keySet();
    Set<Id> excludeIds = excludeRecordIds != null ? excludeRecordIds : new Set<Id>();

    String query =
      'SELECT Id, Status, IndividualApplicationId, School_Rank__c, Current_Priority_Group__c ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :appIds ' +
      'AND Status IN :statuses ' +
      'AND Id NOT IN :excludeIds';

    Set<String> statuses = new Set<String>{
      LotteryConstants.STATUS_ELIGIBLE,
      LotteryConstants.STATUS_WAITLISTED
    };

    List<AcademicInterest> candidates = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'appIds' => appIds,
        'statuses' => statuses,
        'excludeIds' => excludeIds
      }
    );

    List<AcademicInterest> withdrawn = new List<AcademicInterest>();
    for (AcademicInterest record : candidates) {
      Decimal bestRank = bestRankByApplication.get(record.IndividualApplicationId);
      if (bestRank == null) {
        continue;
      }
      if (record.School_Rank__c == null || record.School_Rank__c > bestRank) {
        transitions.add(
          new LotteryStatusChange(
            record.Id,
            record.Status,
            LotteryConstants.STATUS_WITHDRAWN_DECLINED,
            LotteryConstants.TRANSITION_REASON_SEAT_OFFER_WITHDRAWAL,
            record.Current_Priority_Group__c
          )
        );
        record.Status = LotteryConstants.STATUS_WITHDRAWN_DECLINED;
        record.Declined_Withdrawn_Reason__c = LotteryConstants.WITHDRAWN_REASON_SEAT_OFFER;
        withdrawn.add(record);
      }
    }

    return withdrawn;
  }

  private Map<Id, Decimal> findBestRankByApplication(List<AcademicInterest> records) {
    Map<Id, Decimal> bestRankByApplication = new Map<Id, Decimal>();
    for (AcademicInterest record : records) {
      if (record.IndividualApplicationId == null) {
        continue;
      }
      if (
        record.Status != LotteryConstants.STATUS_PRE_OFFER &&
        record.Status != LotteryConstants.STATUS_SEAT_OFFERED
      ) {
        continue;
      }
      Decimal currentBest = bestRankByApplication.get(record.IndividualApplicationId);
      if (
        record.School_Rank__c != null &&
        (currentBest == null ||
        record.School_Rank__c < currentBest)
      ) {
        bestRankByApplication.put(record.IndividualApplicationId, record.School_Rank__c);
      }
    }
    return bestRankByApplication;
  }
}