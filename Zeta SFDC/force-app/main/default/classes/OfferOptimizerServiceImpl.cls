/**
 * Implementation of {@link OfferOptimizerService}.
 *
 * Optimizes student offers when they have multiple active offers (Pre-Offer or
 * Seat Offered) across schools. For each student, keeps their highest-ranked
 * school offer (lowest School_Rank__c) and marks others for rescission.
 */
public with sharing class OfferOptimizerServiceImpl implements OfferOptimizerService {
  private static final String STATUS_PRE_OFFER = LotteryConstants.STATUS_PRE_OFFER;
  private static final String STATUS_SEAT_OFFERED = LotteryConstants.STATUS_SEAT_OFFERED;

  public OfferOptimizerServiceImpl() {
  }

  public List<AcademicInterest> optimizeOffers(
    List<AcademicInterest> records,
    List<LotteryStatusChange> transitions
  ) {
    if (records == null || records.isEmpty()) {
      return new List<AcademicInterest>();
    }

    List<AcademicInterest> activeOfferRecords = filterActiveOfferRecords(records);
    if (activeOfferRecords.isEmpty()) {
      return new List<AcademicInterest>();
    }

    Map<Id, List<AcademicInterest>> recordsByApplication = groupByApplication(activeOfferRecords);

    List<AcademicInterest> recordsToRescind = new List<AcademicInterest>();
    for (Id applicationId : recordsByApplication.keySet()) {
      List<AcademicInterest> applicationRecords = recordsByApplication.get(applicationId);
      if (applicationRecords.size() > 1) {
        recordsToRescind.addAll(identifyRecordsToRescind(applicationRecords, transitions));
      }
    }

    return recordsToRescind;
  }

  /**
   * Filters records to only those with an active offer status (Pre-Offer or Seat Offered).
   */
  private List<AcademicInterest> filterActiveOfferRecords(List<AcademicInterest> records) {
    List<AcademicInterest> activeOfferRecords = new List<AcademicInterest>();
    for (AcademicInterest record : records) {
      if (record.Status == STATUS_PRE_OFFER || record.Status == STATUS_SEAT_OFFERED) {
        activeOfferRecords.add(record);
      }
    }

    return activeOfferRecords;
  }

  private Map<Id, List<AcademicInterest>> groupByApplication(List<AcademicInterest> records) {
    Map<Id, List<AcademicInterest>> recordsByApplication = new Map<Id, List<AcademicInterest>>();
    for (AcademicInterest record : records) {
      Id applicationId = record.IndividualApplicationId;
      if (applicationId == null) {
        continue;
      }
      if (!recordsByApplication.containsKey(applicationId)) {
        recordsByApplication.put(applicationId, new List<AcademicInterest>());
      }
      recordsByApplication.get(applicationId).add(record);
    }
    return recordsByApplication;
  }

  /**
   * For a list of active offer records (Pre-Offer or Seat Offered) for the same
   * application, identifies which should be rescinded (all except the best-ranked).
   *
   * Best-ranked = lowest School_Rank__c value.
   * Ties broken by: existing lottery number (lower first), then CreatedDate.
   */
  private List<AcademicInterest> identifyRecordsToRescind(
    List<AcademicInterest> applicationRecords,
    List<LotteryStatusChange> transitions
  ) {
    applicationRecords.sort(new SchoolRankComparator());

    List<AcademicInterest> recordsToRescind = new List<AcademicInterest>();
    for (Integer i = 1; i < applicationRecords.size(); i++) {
      AcademicInterest recordToRescind = applicationRecords[i];
      transitions.add(
        new LotteryStatusChange(
          recordToRescind.Id,
          recordToRescind.Status,
          LotteryConstants.STATUS_RESCINDED_OPTIMIZATION,
          LotteryConstants.TRANSITION_REASON_SEAT_OPTIMIZATION,
          recordToRescind.Current_Priority_Group__c
        )
      );
      recordToRescind.Status = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION;
      recordToRescind.Rescinded_Reason__c = LotteryConstants.STATUS_RESCINDED_OPTIMIZATION;
      recordsToRescind.add(recordToRescind);
    }
    return recordsToRescind;
  }
}