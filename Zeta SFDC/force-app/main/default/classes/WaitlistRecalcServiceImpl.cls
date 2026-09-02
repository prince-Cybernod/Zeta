/**
 * Implementation of {@link WaitlistRecalcService}.
 *
 * Orchestrates waitlist recalculation by:
 * 1. Sorting records using WaitlistSortService
 * 2. Comparing old vs new positions
 * 3. Returning only records that need updating
 *
 * The caller is responsible for:
 * - Querying the records with required fields
 * - Performing DML on returned records (triggers history creation)
 * - Calling OfferOptimizerService after status changes
 */
public with sharing class WaitlistRecalcServiceImpl implements WaitlistRecalcService {
  private final WaitlistSortService sortService;

  public WaitlistRecalcServiceImpl() {
    this(new WaitlistSortServiceImpl());
  }

  @TestVisible
  private WaitlistRecalcServiceImpl(WaitlistSortService sortService) {
    this.sortService = sortService;
  }

  public List<AcademicInterest> recalculatePositions(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return new List<AcademicInterest>();
    }

    Map<Id, Decimal> oldPositionsById = new Map<Id, Decimal>();
    for (AcademicInterest record : records) {
      if (record.Id != null) {
        oldPositionsById.put(record.Id, record.Waitlist_Position__c);
      }
    }

    List<AcademicInterest> sortedRecords = sortService.sortAndAssignPositions(records);
    List<AcademicInterest> changedRecords = new List<AcademicInterest>();
    for (AcademicInterest record : sortedRecords) {
      Decimal oldPosition = oldPositionsById.get(record.Id);
      if (record.Waitlist_Position__c != oldPosition) {
        changedRecords.add(record);
      }
    }

    return changedRecords;
  }

  public List<AcademicInterest> recalculatePositionsByCapacity(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return new List<AcademicInterest>();
    }

    Map<Id, List<AcademicInterest>> recordsByCapacity = new Map<Id, List<AcademicInterest>>();
    for (AcademicInterest record : records) {
      Id capacityId = record.Lottery_Capacity__c;
      if (capacityId == null) {
        continue;
      }
      if (!recordsByCapacity.containsKey(capacityId)) {
        recordsByCapacity.put(capacityId, new List<AcademicInterest>());
      }
      recordsByCapacity.get(capacityId).add(record);
    }

    List<AcademicInterest> allChangedRecords = new List<AcademicInterest>();
    for (List<AcademicInterest> capacityRecords : recordsByCapacity.values()) {
      List<AcademicInterest> changedRecords = recalculatePositions(capacityRecords);
      allChangedRecords.addAll(changedRecords);
    }

    return allChangedRecords;
  }

  public List<AcademicInterest> getRecordsToPromote(
    List<AcademicInterest> sortedRecords,
    Integer availableSeats
  ) {
    if (
      sortedRecords == null ||
      sortedRecords.isEmpty() ||
      availableSeats == null ||
      availableSeats <= 0
    ) {
      return new List<AcademicInterest>();
    }

    List<AcademicInterest> recordsToPromote = new List<AcademicInterest>();
    for (AcademicInterest record : sortedRecords) {
      if (recordsToPromote.size() >= availableSeats) {
        break;
      }
      recordsToPromote.add(record);
    }

    return recordsToPromote;
  }
}