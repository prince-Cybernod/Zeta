/**
 * Implementation of {@link SchoolRankValidationService}.
 * Validates School_Rank__c uniqueness per IndividualApplication using AFTER trigger
 * context with FOR UPDATE locking to prevent race conditions.
 */
public with sharing class SchoolRankValidationServiceImpl implements SchoolRankValidationService {
  @TestVisible
  private static final String ERROR_DUPLICATE_RANK = 'School Rank {0} is already used for another school on this application. Each school must have a unique rank.';
  @TestVisible
  private static final String ERROR_LOCK_TIMEOUT = 'Unable to validate school rankings due to concurrent updates. Please try again.';

  private final DatabaseRepo databaseRepo;

  public SchoolRankValidationServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private SchoolRankValidationServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void validateUniqueRanks(List<AcademicInterest> academicInterests) {
    if (academicInterests == null || academicInterests.isEmpty()) {
      return;
    }

    Set<Id> applicationIds = collectApplicationIdsWithRanks(academicInterests);
    if (applicationIds.isEmpty()) {
      return;
    }

    // Lock all ranked records for these apps so that we can validate.
    List<AcademicInterest> allRecords;
    try {
      allRecords = queryAllRankedRecords(applicationIds);
    } catch (QueryException e) {
      // Most likely a lock timeout due to `FOR UPDATE`.
      // Add user-friendly error to all trigger records.
      for (AcademicInterest record : academicInterests) {
        if (record.School_Rank__c != null) {
          record.School_Rank__c.addError(ERROR_LOCK_TIMEOUT);
        }
      }
      return;
    }

    Map<String, List<Id>> recordIdsByAppAndRank = groupByAppAndRank(allRecords);
    addErrorsForDuplicates(academicInterests, recordIdsByAppAndRank);
  }

  private static Set<Id> collectApplicationIdsWithRanks(List<AcademicInterest> records) {
    Set<Id> applicationIds = new Set<Id>();
    for (AcademicInterest record : records) {
      if (String.isNotBlank(record.IndividualApplicationId) && record.School_Rank__c != null) {
        applicationIds.add(record.IndividualApplicationId);
      }
    }

    return applicationIds;
  }

  @TestVisible
  private List<AcademicInterest> queryAllRankedRecords(Set<Id> applicationIds) {
    String query =
      'SELECT Id, IndividualApplicationId, School_Rank__c ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :applicationIds ' +
      'AND School_Rank__c != null ' +
      'FOR UPDATE';

    Map<String, Object> binds = new Map<String, Object>{ 'applicationIds' => applicationIds };

    return databaseRepo.queryWithBinds(query, binds);
  }

  private static Map<String, List<Id>> groupByAppAndRank(List<AcademicInterest> records) {
    Map<String, List<Id>> result = new Map<String, List<Id>>();

    for (AcademicInterest record : records) {
      String key = record.IndividualApplicationId + '-' + record.School_Rank__c;

      if (!result.containsKey(key)) {
        result.put(key, new List<Id>());
      }
      result.get(key).add(record.Id);
    }

    return result;
  }

  private static void addErrorsForDuplicates(
    List<AcademicInterest> academicInterests,
    Map<String, List<Id>> recordIdsByAppAndRank
  ) {
    Set<Id> recordIds = new Set<Id>();
    for (AcademicInterest record : academicInterests) {
      if (String.isNotBlank(record.Id)) {
        recordIds.add(record.Id);
      }
    }

    // Find duplicate groups (more than 1 record with same app + rank)
    Map<String, Decimal> duplicateRanks = new Map<String, Decimal>();
    for (String key : recordIdsByAppAndRank.keySet()) {
      List<Id> ids = recordIdsByAppAndRank.get(key);
      if (ids.size() > 1) {
        // Extract rank from key (format: "appId-rank")
        List<String> parts = key.split('-');
        if (parts.size() >= 2) {
          Decimal rank = Decimal.valueOf(parts[1]);
          duplicateRanks.put(key, rank);
        }
      }
    }

    // Add errors to trigger records that are in duplicate groups
    for (AcademicInterest record : academicInterests) {
      if (record.School_Rank__c == null || record.IndividualApplicationId == null) {
        continue;
      }

      String key = record.IndividualApplicationId + '-' + record.School_Rank__c;
      if (duplicateRanks.containsKey(key)) {
        Decimal rank = duplicateRanks.get(key);
        record.School_Rank__c.addError(
          String.format(ERROR_DUPLICATE_RANK, new List<Object>{ rank.intValue() })
        );
      }
    }
  }
}