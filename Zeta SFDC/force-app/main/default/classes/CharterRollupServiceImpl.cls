/**
 * Implementation of {@link CharterRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class CharterRollupServiceImpl implements CharterRollupService {
  private static final String CHARTER_RECORD_TYPE_DEVELOPER_NAME = 'Charter';

  private final DatabaseRepo databaseRepo;

  public CharterRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private CharterRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> charterAccountIds) {
    if (charterAccountIds == null || charterAccountIds.isEmpty()) {
      return;
    }

    List<Account> charters = getCharterAccounts(charterAccountIds);
    if (charters.isEmpty()) {
      return;
    }

    Set<Id> charterIds = new Map<Id, Account>(charters).keySet();
    Set<Id> countedLearningProgramIds = selectCurrentCycleLearningProgramIds(
      getOpenedTimelineLinks(charterIds)
    );

    processCharters(charters, getResultsByCharterId(countedLearningProgramIds));
  }

  /**
   * Only Charters whose sum actually changed are written, which keeps
   * Account automation quiet on a night with no boundary crossing.
   */
  @TestVisible
  private void processCharters(
    List<Account> charters,
    Map<Id, CharterRollupAggregateResult> resultsByCharterId
  ) {
    List<Account> chartersToUpdate = new List<Account>();
    for (Account charter : charters) {
      CharterRollupAggregateResult result = resultsByCharterId.get(charter.Id);
      Decimal emp = result == null ||
        result.employeePriorityCount == null
        ? 0
        : result.employeePriorityCount;
      Decimal seats = result == null || result.availableSeats == null ? 0 : result.availableSeats;

      if (
        charter.Count_Lottery_Employee_Priority__c == emp &&
        charter.Total_Available_Seats_for_School_Year__c == seats
      ) {
        continue;
      }

      chartersToUpdate.add(
        new Account(
          Id = charter.Id,
          Count_Lottery_Employee_Priority__c = emp,
          Total_Available_Seats_for_School_Year__c = seats
        )
      );
    }

    if (!chartersToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(chartersToUpdate);
    }
  }

  /**
   * The cycle is picked per Charter: the linked timelines open today, or,
   * if none is open, the linked timelines that have opened with the
   * latest close date (ties all count). A Charter with no linked timeline
   * in {@code openedTimelineLinks} has never opened one, so it contributes
   * no ids here and resolves to 0/0.
   */
  @TestVisible
  private static Set<Id> selectCurrentCycleLearningProgramIds(
    List<ProgramTermApplnTimeline> openedTimelineLinks
  ) {
    Map<Id, List<ProgramTermApplnTimeline>> linksByCharterId = new Map<Id, List<ProgramTermApplnTimeline>>();
    for (ProgramTermApplnTimeline link : openedTimelineLinks) {
      Id charterId = link.LearningProgram.School__r.ParentId;
      if (charterId == null) {
        continue;
      }
      if (!linksByCharterId.containsKey(charterId)) {
        linksByCharterId.put(charterId, new List<ProgramTermApplnTimeline>());
      }
      linksByCharterId.get(charterId).add(link);
    }

    Set<Id> countedLearningProgramIds = new Set<Id>();
    for (List<ProgramTermApplnTimeline> links : linksByCharterId.values()) {
      Set<Id> openLearningProgramIds = new Set<Id>();
      Map<Date, Set<Id>> closedLearningProgramIdsByCloseDate = new Map<Date, Set<Id>>();
      Date latestCloseDate = null;

      for (ProgramTermApplnTimeline link : links) {
        if (link.ApplicationTimeline.Active__c) {
          openLearningProgramIds.add(link.LearningProgramId);
          continue;
        }

        Date closeDate = link.ApplicationTimeline.ApplicationCloseDate;
        if (!closedLearningProgramIdsByCloseDate.containsKey(closeDate)) {
          closedLearningProgramIdsByCloseDate.put(closeDate, new Set<Id>());
        }
        closedLearningProgramIdsByCloseDate.get(closeDate).add(link.LearningProgramId);
        if (latestCloseDate == null || closeDate > latestCloseDate) {
          latestCloseDate = closeDate;
        }
      }

      if (!openLearningProgramIds.isEmpty()) {
        countedLearningProgramIds.addAll(openLearningProgramIds);
      } else if (latestCloseDate != null) {
        countedLearningProgramIds.addAll(closedLearningProgramIdsByCloseDate.get(latestCloseDate));
      }
    }

    return countedLearningProgramIds;
  }

  @TestVisible
  private List<Account> getCharterAccounts(Set<Id> accountIds) {
    return databaseRepo.queryWithBinds(
      'SELECT Id, Count_Lottery_Employee_Priority__c, Total_Available_Seats_for_School_Year__c ' +
        'FROM Account ' +
        'WHERE Id IN :accountIds AND RecordType.DeveloperName = :charterDeveloperName',
      new Map<String, Object>{
        'accountIds' => accountIds,
        'charterDeveloperName' => CHARTER_RECORD_TYPE_DEVELOPER_NAME
      }
    );
  }

  @TestVisible
  private List<ProgramTermApplnTimeline> getOpenedTimelineLinks(Set<Id> charterIds) {
    return databaseRepo.queryWithBinds(
      'SELECT LearningProgramId, LearningProgram.School__r.ParentId, ' +
        'ApplicationTimeline.Active__c, ApplicationTimeline.ApplicationCloseDate ' +
        'FROM ProgramTermApplnTimeline ' +
        'WHERE LearningProgram.School__r.ParentId IN :charterIds ' +
        'AND ApplicationTimeline.ApplicationOpenDate <= TODAY',
      new Map<String, Object>{ 'charterIds' => charterIds }
    );
  }

  @TestVisible
  private Map<Id, CharterRollupAggregateResult> getResultsByCharterId(
    Set<Id> countedLearningProgramIds
  ) {
    Map<Id, CharterRollupAggregateResult> resultsByCharterId = new Map<Id, CharterRollupAggregateResult>();
    if (countedLearningProgramIds.isEmpty()) {
      return resultsByCharterId;
    }

    String query =
      'SELECT School__r.ParentId charterId, ' +
      'SUM(Count_Lottery_Employee_Priority__c) emp, ' +
      'SUM(Total_Available_Seats_for_School_Year__c) seats ' +
      'FROM LearningProgram ' +
      'WHERE Id IN :countedLearningProgramIds ' +
      'GROUP BY School__r.ParentId';

    List<AggregateResult> results = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'countedLearningProgramIds' => countedLearningProgramIds }
    );

    for (
      CharterRollupAggregateResult result : CharterRollupAggregateResult.fromAggregateResults(
        results
      )
    ) {
      resultsByCharterId.put(result.charterId, result);
    }
    return resultsByCharterId;
  }
}