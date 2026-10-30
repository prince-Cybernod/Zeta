/**
 * Implementation of {@link ContactApplicationRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class ContactApplicationRollupServiceImpl implements ContactApplicationRollupService {
  @TestVisible
  private static final Set<String> COUNTED_ACADEMIC_INTEREST_STATUSES = new Set<String>();
  private static final String VALUE_SEPARATOR = '; ';

  private final DatabaseRepo databaseRepo;

  public ContactApplicationRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private ContactApplicationRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public static Boolean hasStatusFilter() {
    return !COUNTED_ACADEMIC_INTEREST_STATUSES.isEmpty();
  }

  public void recalculate(Set<Id> personAccountIds) {
    Set<Id> ids = new Set<Id>();
    if (personAccountIds != null) {
      for (Id personAccountId : personAccountIds) {
        if (personAccountId != null) {
          ids.add(personAccountId);
        }
      }
    }
    if (ids.isEmpty()) {
      return;
    }

    List<IndividualApplication> applications = databaseRepo.queryWithBinds(
      'SELECT AccountId, Primary_Guardian__c, Lead_Source__c, ' +
        'Application_Timeline__r.Name, ' +
        'Application_Timeline__r.Academic_Term__r.StartDate, ' +
        'Application_Timeline__r.Academic_Term__r.EndDate, ' +
        '(SELECT fx_SchoolName__c, School_Rank__c, Status FROM AcademicInterests) ' +
        'FROM IndividualApplication ' +
        'WHERE AccountId IN :personAccountIds OR Primary_Guardian__c IN :personAccountIds',
      new Map<String, Object>{ 'personAccountIds' => ids }
    );

    List<Account> accounts = databaseRepo.queryWithBinds(
      'SELECT Id, IsPersonAccount, School_Applications__pc, Application_Lead_Sources__pc ' +
      'FROM Account WHERE Id IN :personAccountIds',
      new Map<String, Object>{ 'personAccountIds' => ids }
    );

    processResults(applications, accounts);
  }

  @TestVisible
  private void processResults(List<IndividualApplication> applications, List<Account> accounts) {
    Map<Id, Account> personAccountsById = new Map<Id, Account>();
    for (Account account : accounts) {
      if (account.IsPersonAccount) {
        personAccountsById.put(account.Id, account);
      }
    }

    Map<Id, List<IndividualApplication>> applicationsByPersonId = new Map<Id, List<IndividualApplication>>();
    for (Id personAccountId : personAccountsById.keySet()) {
      applicationsByPersonId.put(personAccountId, new List<IndividualApplication>());
    }
    for (IndividualApplication application : applications) {
      if (personAccountsById.containsKey(application.AccountId)) {
        applicationsByPersonId.get(application.AccountId).add(application);
      }
      if (
        application.Primary_Guardian__c != null &&
        personAccountsById.containsKey(application.Primary_Guardian__c)
      ) {
        applicationsByPersonId.get(application.Primary_Guardian__c).add(application);
      }
    }

    List<Account> accountsToUpdate = new List<Account>();
    for (Id personAccountId : personAccountsById.keySet()) {
      Account personAccount = personAccountsById.get(personAccountId);
      List<IndividualApplication> personApplications = applicationsByPersonId.get(personAccountId);

      String schoolApplicationsValue = buildSchoolApplicationsValue(personApplications);
      String leadSourcesValue = buildLeadSourcesValue(personApplications);

      if (
        schoolApplicationsValue != personAccount.School_Applications__pc ||
        leadSourcesValue != personAccount.Application_Lead_Sources__pc
      ) {
        accountsToUpdate.add(
          new Account(
            Id = personAccountId,
            School_Applications__pc = schoolApplicationsValue,
            Application_Lead_Sources__pc = leadSourcesValue
          )
        );
      }
    }

    if (!accountsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(accountsToUpdate);
    }
  }

  @TestVisible
  private static String buildSchoolApplicationsValue(List<IndividualApplication> applications) {
    Map<String, YearGroup> groupsByKey = new Map<String, YearGroup>();

    for (IndividualApplication application : applications) {
      List<AcademicInterest> academicInterests = application.AcademicInterests;
      if (academicInterests == null || academicInterests.isEmpty()) {
        continue;
      }

      ApplicationTimeline timeline = application.Application_Timeline__r;
      AcademicTerm term = timeline == null ? null : timeline.Academic_Term__r;
      Boolean hasTerm = term != null && term.StartDate != null && term.EndDate != null;

      String groupKey;
      String groupLabel;
      Integer startYear;
      if (hasTerm) {
        startYear = term.StartDate.year();
        Integer endYear = term.EndDate.year();
        groupKey = 'YEAR:' + startYear + '-' + endYear;
        groupLabel = startYear + ' - ' + endYear;
      } else {
        String timelineName = timeline == null ? null : timeline.Name;
        groupKey = 'NOTERM:' + timelineName;
        groupLabel = timelineName;
      }

      YearGroup yearGroup = groupsByKey.get(groupKey);
      if (yearGroup == null) {
        yearGroup = new YearGroup(groupLabel, hasTerm, startYear);
        groupsByKey.put(groupKey, yearGroup);
      }

      for (AcademicInterest academicInterest : academicInterests) {
        if (isCounted(academicInterest.Status)) {
          yearGroup.addSchool(academicInterest.fx_SchoolName__c, academicInterest.School_Rank__c);
        }
      }
    }

    List<YearGroup> groups = groupsByKey.values();
    groups.sort();

    List<String> yearValues = new List<String>();
    for (YearGroup yearGroup : groups) {
      String yearValue = yearGroup.buildValue();
      if (yearValue != null) {
        yearValues.add(yearValue);
      }
    }

    return yearValues.isEmpty() ? null : String.join(yearValues, VALUE_SEPARATOR);
  }

  @TestVisible
  private static String buildLeadSourcesValue(List<IndividualApplication> applications) {
    Set<String> leadSources = new Set<String>();
    for (IndividualApplication application : applications) {
      if (String.isNotBlank(application.Lead_Source__c)) {
        leadSources.add(application.Lead_Source__c);
      }
    }
    if (leadSources.isEmpty()) {
      return null;
    }
    List<String> sortedLeadSources = new List<String>(leadSources);
    sortedLeadSources.sort();
    return String.join(sortedLeadSources, VALUE_SEPARATOR);
  }

  private static Boolean isCounted(String status) {
    return COUNTED_ACADEMIC_INTEREST_STATUSES.isEmpty() ||
      COUNTED_ACADEMIC_INTEREST_STATUSES.contains(status);
  }

  /**
   * One academic year of the School Applications value: a term-dated group sorts
   * newest first, ahead of every no-term group, which sorts alphabetically
   * by its timeline name.
   */
  private class YearGroup implements Comparable {
    private final String label;
    private final Boolean hasTerm;
    private final Integer startYear;
    private final Map<String, Decimal> rankBySchoolName = new Map<String, Decimal>();

    private YearGroup(String label, Boolean hasTerm, Integer startYear) {
      this.label = label;
      this.hasTerm = hasTerm;
      this.startYear = startYear;
    }

    private void addSchool(String schoolName, Decimal rank) {
      if (String.isBlank(schoolName)) {
        return;
      }
      Decimal existingRank = rankBySchoolName.get(schoolName);
      if (existingRank == null || (rank != null && rank < existingRank)) {
        rankBySchoolName.put(schoolName, rank);
      }
    }

    private String buildValue() {
      if (rankBySchoolName.isEmpty()) {
        return null;
      }
      List<SchoolRank> schools = new List<SchoolRank>();
      for (String schoolName : rankBySchoolName.keySet()) {
        schools.add(new SchoolRank(schoolName, rankBySchoolName.get(schoolName)));
      }
      schools.sort();

      List<String> schoolNames = new List<String>();
      for (SchoolRank school : schools) {
        schoolNames.add(school.name);
      }
      return label + ': ' + String.join(schoolNames, VALUE_SEPARATOR);
    }

    public Integer compareTo(Object other) {
      YearGroup that = (YearGroup) other;
      if (this.hasTerm && !that.hasTerm) {
        return -1;
      }
      if (!this.hasTerm && that.hasTerm) {
        return 1;
      }
      if (this.hasTerm && that.hasTerm) {
        return that.startYear - this.startYear;
      }
      if (this.label == that.label) {
        return 0;
      }
      return this.label < that.label ? -1 : 1;
    }
  }

  /**
   * A school within one YearGroup line, ordered by its lowest observed
   * School_Rank__c (unranked sorts last), then by name.
   */
  private class SchoolRank implements Comparable {
    private final String name;
    private final Decimal rank;

    private SchoolRank(String name, Decimal rank) {
      this.name = name;
      this.rank = rank;
    }

    public Integer compareTo(Object other) {
      SchoolRank that = (SchoolRank) other;
      Decimal thisRank = this.rank == null ? 999999999 : this.rank;
      Decimal thatRank = that.rank == null ? 999999999 : that.rank;
      if (thisRank != thatRank) {
        return thisRank < thatRank ? -1 : 1;
      }
      if (this.name == that.name) {
        return 0;
      }
      return this.name < that.name ? -1 : 1;
    }
  }
}