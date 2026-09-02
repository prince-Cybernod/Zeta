/**
 * Implementation of {@link LotterySortService}.
 *
 * Security model: Uses `with sharing` for row-level access control with
 * `SystemModeDatabaseRepo` for field-level writes. This is intentional because
 * lottery sorting is admin-only and requires updating AcademicInterest fields
 * that may have restrictive FLS for regular users.
 *
 * Handles randomized sort key assignment and lottery ordering
 * for school admissions lottery processing.
 */
public with sharing class LotterySortServiceImpl implements LotterySortService {
  private final DatabaseRepo databaseRepo;

  public LotterySortServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LotterySortServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void assignRandomizedSortKeys(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return;
    }

    Set<Decimal> usedKeys = new Set<Decimal>();
    for (AcademicInterest record : records) {
      if (record.Randomized_Sort_Key__c != null) {
        usedKeys.add(record.Randomized_Sort_Key__c);
      }
    }

    for (AcademicInterest record : records) {
      if (record.Randomized_Sort_Key__c == null) {
        Decimal key;
        do {
          key = generateRandomSortKey();
        } while (usedKeys.contains(key));
        usedKeys.add(key);
        record.Randomized_Sort_Key__c = key;
      }
    }
  }

  public List<AcademicInterest> sortByLotteryOrder(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return records;
    }

    List<AcademicInterest> sortedRecords = new List<AcademicInterest>(records);
    sortedRecords.sort(new LotteryEligibilityComparator());

    return sortedRecords;
  }

  public List<AcademicInterest> getTopCandidatesForCapacity(
    Id lotteryCapacityId,
    Integer availableSeats
  ) {
    if (lotteryCapacityId == null || availableSeats == null || availableSeats <= 0) {
      return new List<AcademicInterest>();
    }

    String query =
      'SELECT Id, Status, Current_Priority_Group__c, Date_of_Current_Priority_Change__c, ' +
      'Randomized_Sort_Key__c, CreatedDate, IndividualApplicationId, School_Rank__c ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c = :lotteryCapacityId AND Status = :status';
    List<AcademicInterest> eligibleStudents = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'lotteryCapacityId' => lotteryCapacityId,
        'status' => LotteryConstants.STATUS_ELIGIBLE
      }
    );

    if (eligibleStudents.isEmpty()) {
      return new List<AcademicInterest>();
    }

    List<AcademicInterest> sorted = sortByLotteryOrder(eligibleStudents);
    Integer count = Math.min(availableSeats, sorted.size());
    List<AcademicInterest> topCandidates = new List<AcademicInterest>();
    for (Integer i = 0; i < count; i++) {
      topCandidates.add(sorted[i]);
    }

    return topCandidates;
  }

  /**
   * Generates a random sort key for lottery ordering.
   * Uses a 12-digit range (1 to 999,999,999,999) to make collisions
   * astronomically unlikely. Field supports up to 18 digits.
   */
  @TestVisible
  private Decimal generateRandomSortKey() {
    return Math.floor(Math.random() * 999999999999.0) + 1;
  }
}