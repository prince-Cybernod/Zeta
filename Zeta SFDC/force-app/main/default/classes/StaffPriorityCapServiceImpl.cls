/**
 * Implementation of {@link StaffPriorityCapService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class StaffPriorityCapServiceImpl implements StaffPriorityCapService {
  @TestVisible
  private static final String DEFAULT_CMDT_DEVELOPER_NAME = 'Default';
  @TestVisible
  private static final List<String> PLACED_STATUSES = new List<String>{
    AcademicInterestConstants.STATUS_PRE_OFFER,
    AcademicInterestConstants.STATUS_SEAT_OFFERED
  };

  private final DatabaseRepo databaseRepo;
  private final StaffPriorityCapKeySource keySource;

  public StaffPriorityCapServiceImpl() {
    this(new SystemModeDatabaseRepo(), new StaffPriorityCapKeySourceImpl());
  }

  @TestVisible
  private StaffPriorityCapServiceImpl(
    DatabaseRepo databaseRepo,
    StaffPriorityCapKeySource keySource
  ) {
    this.databaseRepo = databaseRepo;
    this.keySource = keySource;
  }

  public List<StaffPriorityCapCharterStats> getCharterStats(
    List<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    if (capacityIds == null || capacityIds.isEmpty()) {
      return new List<StaffPriorityCapCharterStats>();
    }
    return buildCharterStats(new Set<Id>(capacityIds), startDate, endDate);
  }

  public StaffPriorityCapRemovalResult removeForCharter(
    Id charterId,
    List<Id> capacityIds,
    Id runLogId,
    Date startDate,
    Date endDate
  ) {
    StaffPriorityCapRemovalResult result = new StaffPriorityCapRemovalResult();
    if (charterId == null || capacityIds == null || capacityIds.isEmpty()) {
      return result;
    }

    Set<Id> capacityIdSet = new Set<Id>(capacityIds);
    StaffPriorityCapCharterStats charterStats = findStats(
      buildCharterStats(capacityIdSet, startDate, endDate),
      charterId
    );
    if (charterStats == null || charterStats.status != StaffPriorityCapCharterStats.STATUS_OVER) {
      return result;
    }

    List<AcademicInterest> pool = queryPoolAcademicInterests(
      capacityIdSet,
      charterId,
      startDate,
      endDate
    );
    Map<Id, List<AcademicInterest>> poolGroupedByApplicationId = groupByApplicationId(pool);
    Set<Id> approvedStaffAppIds = queryApprovedStaffApplicationIds(
      poolGroupedByApplicationId.keySet()
    );
    // A student who also has a placed (Pre-Offer/Seat Offered) AcademicInterest at this
    // Charter still counts toward the Charter's total through that placed record, so
    // flagging their pool record would not reduce the count. Exclude them from the draw
    // so removedCount/residual stay accurate.
    Set<Id> placedAppIds = queryPlacedApplicationIdsForCharter(capacityIdSet, charterId);
    Set<Id> reducibleAppIds = new Set<Id>();
    for (Id appId : approvedStaffAppIds) {
      if (!placedAppIds.contains(appId)) {
        reducibleAppIds.add(appId);
      }
    }
    Map<Id, List<AcademicInterest>> poolByApplicationId = retainKeys(
      poolGroupedByApplicationId,
      reducibleAppIds
    );

    List<Id> orderedApplicationIds = drawRemovalOrder(poolByApplicationId.keySet());
    Integer toRemove = charterStats.toRemove == null ? 0 : charterStats.toRemove;
    Integer removeCount = Math.min(toRemove, orderedApplicationIds.size());

    List<AcademicInterest> recordsToUpdate = new List<AcademicInterest>();
    for (Integer i = 0; i < removeCount; i++) {
      for (AcademicInterest academicInterest : poolByApplicationId.get(orderedApplicationIds[i])) {
        academicInterest.Staff_Priority_Removed__c = true;
        academicInterest.Staff_Priority_Removed_Run__c = runLogId;
        academicInterest.Staff_Priority_Removal_Order__c = i + 1;
        recordsToUpdate.add(academicInterest);
      }
    }

    if (!recordsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(recordsToUpdate);
    }

    result.removedCount = removeCount;
    result.residual = toRemove - removeCount;
    return result;
  }

  @TestVisible
  private List<StaffPriorityCapCharterStats> buildCharterStats(
    Set<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    List<StaffPriorityCapCharterStats> results = new List<StaffPriorityCapCharterStats>();

    Decimal capPercent = queryCapPercent();
    Map<Id, CapacityCharterInfo> infoByCapacityId = queryCapacityCharterInfo(capacityIds);
    if (infoByCapacityId.isEmpty()) {
      return results;
    }

    Set<Id> charterIds = new Set<Id>();
    Set<Id> timelineIds = new Set<Id>();
    for (CapacityCharterInfo info : infoByCapacityId.values()) {
      if (info.charterId != null) {
        charterIds.add(info.charterId);
      }
      if (info.timelineId != null) {
        timelineIds.add(info.timelineId);
      }
    }

    Map<Id, Account> chartersById = queryCharterAccounts(charterIds);
    Map<Id, Set<Id>> studentAppIdsByCharterId = collectStudentApplicationIds(
      capacityIds,
      charterIds,
      timelineIds,
      startDate,
      endDate
    );

    Set<Id> allAppIds = new Set<Id>();
    for (Set<Id> appIds : studentAppIdsByCharterId.values()) {
      allAppIds.addAll(appIds);
    }
    Set<Id> approvedStaffAppIds = queryApprovedStaffApplicationIds(allAppIds);

    for (Id charterId : charterIds) {
      Set<Id> appIds = studentAppIdsByCharterId.get(charterId);
      Integer staffApplicantCount = 0;
      if (appIds != null) {
        for (Id appId : appIds) {
          if (approvedStaffAppIds.contains(appId)) {
            staffApplicantCount++;
          }
        }
      }

      Account charter = chartersById.get(charterId);
      String blockedMessage = determineBlockedMessage(
        capPercent,
        charter,
        charterId,
        infoByCapacityId
      );

      // Blank or zero seats and a missing cap setting block the run even when the
      // Charter has no staff applicants; only an otherwise-valid Charter with none is
      // left out of the table.
      if (staffApplicantCount == 0 && blockedMessage == null) {
        continue;
      }

      StaffPriorityCapCharterStats stats = new StaffPriorityCapCharterStats();
      stats.charterId = charterId;
      stats.charterName = charter?.Name;
      stats.staffApplicantCount = staffApplicantCount;
      stats.capPercent = capPercent;

      if (blockedMessage != null) {
        stats.status = StaffPriorityCapCharterStats.STATUS_BLOCKED;
        stats.message = blockedMessage;
        stats.seats = charter?.Total_Available_Seats_for_School_Year__c != null
          ? charter.Total_Available_Seats_for_School_Year__c.intValue()
          : 0;
        stats.maxAllowed = 0;
        stats.currentPercent = 0;
        stats.toRemove = 0;
        results.add(stats);
        continue;
      }

      Integer seats = charter.Total_Available_Seats_for_School_Year__c.intValue();
      Integer maxAllowed = ((Decimal) seats * capPercent / 100).intValue();
      Integer removalCount = Math.max(0, staffApplicantCount - maxAllowed);

      stats.seats = seats;
      stats.maxAllowed = maxAllowed;
      stats.currentPercent = seats == 0 ? 0 : ((Decimal) staffApplicantCount * 100 / seats);
      stats.toRemove = removalCount;
      stats.status = removalCount > 0
        ? StaffPriorityCapCharterStats.STATUS_OVER
        : StaffPriorityCapCharterStats.STATUS_UNDER;
      results.add(stats);
    }

    return results;
  }

  private String determineBlockedMessage(
    Decimal capPercent,
    Account charter,
    Id charterId,
    Map<Id, CapacityCharterInfo> infoByCapacityId
  ) {
    if (capPercent == null) {
      return 'Staff priority cap setting (Staff_Priority_Cap_Setting__mdt.Default) is not configured.';
    }
    if (
      charter == null ||
      charter.Total_Available_Seats_for_School_Year__c == null ||
      charter.Total_Available_Seats_for_School_Year__c == 0
    ) {
      return (charter != null ? charter.Name : 'This Charter') +
        ': Total Available Seats for School Year is blank or zero.';
    }
    for (CapacityCharterInfo info : infoByCapacityId.values()) {
      if (
        info.charterId == charterId &&
        (info.learningProgramSeats == null ||
        info.learningProgramSeats == 0)
      ) {
        return info.schoolName + ': Total Available Seats for School Year is blank or zero.';
      }
    }
    return null;
  }

  @TestVisible
  private Decimal queryCapPercent() {
    List<Staff_Priority_Cap_Setting__mdt> settings = (List<Staff_Priority_Cap_Setting__mdt>) databaseRepo.queryWithBinds(
      'SELECT Cap_Percent__c FROM Staff_Priority_Cap_Setting__mdt WHERE DeveloperName = :developerName LIMIT 1',
      new Map<String, Object>{ 'developerName' => DEFAULT_CMDT_DEVELOPER_NAME }
    );
    return settings.isEmpty() ? null : settings[0].Cap_Percent__c;
  }

  @TestVisible
  private Map<Id, CapacityCharterInfo> queryCapacityCharterInfo(Set<Id> capacityIds) {
    String query =
      'SELECT Id, ' +
      'Program_Term_Application_Timeline__r.ApplicationTimelineId, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.Total_Available_Seats_for_School_Year__c, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.ParentId, ' +
      'Program_Term_Application_Timeline__r.LearningProgram.School__r.Zeta_School_Name__c ' +
      'FROM Lottery_Capacity__c ' +
      'WHERE Id IN :capacityIds';

    List<Lottery_Capacity__c> capacities = (List<Lottery_Capacity__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );

    Map<Id, CapacityCharterInfo> infoByCapacityId = new Map<Id, CapacityCharterInfo>();
    for (Lottery_Capacity__c capacity : capacities) {
      SObject timeline = capacity.getSObject('Program_Term_Application_Timeline__r');
      SObject learningProgram = timeline?.getSObject('LearningProgram');
      SObject school = learningProgram?.getSObject('School__r');

      CapacityCharterInfo info = new CapacityCharterInfo();
      info.timelineId = timeline != null ? (Id) timeline.get('ApplicationTimelineId') : null;
      info.charterId = school != null ? (Id) school.get('ParentId') : null;
      info.learningProgramSeats = learningProgram != null
        ? (Decimal) learningProgram.get('Total_Available_Seats_for_School_Year__c')
        : null;
      info.schoolName = school != null ? (String) school.get('Zeta_School_Name__c') : null;
      infoByCapacityId.put(capacity.Id, info);
    }
    return infoByCapacityId;
  }

  @TestVisible
  private Map<Id, Account> queryCharterAccounts(Set<Id> charterIds) {
    if (charterIds.isEmpty()) {
      return new Map<Id, Account>();
    }
    List<Account> charters = (List<Account>) databaseRepo.queryWithBinds(
      'SELECT Id, Name, Total_Available_Seats_for_School_Year__c FROM Account WHERE Id IN :charterIds',
      new Map<String, Object>{ 'charterIds' => charterIds }
    );
    return new Map<Id, Account>(charters);
  }

  @TestVisible
  private Map<Id, Set<Id>> collectStudentApplicationIds(
    Set<Id> capacityIds,
    Set<Id> charterIds,
    Set<Id> timelineIds,
    Date startDate,
    Date endDate
  ) {
    Map<Id, Set<Id>> appIdsByCharterId = new Map<Id, Set<Id>>();

    for (AcademicInterestCharterRow row : queryEligiblePoolRows(capacityIds, startDate, endDate)) {
      addRow(appIdsByCharterId, row);
    }
    if (!timelineIds.isEmpty() && !charterIds.isEmpty()) {
      for (AcademicInterestCharterRow row : queryPlacedRows(timelineIds, charterIds)) {
        addRow(appIdsByCharterId, row);
      }
    }

    return appIdsByCharterId;
  }

  private void addRow(Map<Id, Set<Id>> appIdsByCharterId, AcademicInterestCharterRow row) {
    if (row.charterId == null || row.applicationId == null) {
      return;
    }
    if (!appIdsByCharterId.containsKey(row.charterId)) {
      appIdsByCharterId.put(row.charterId, new Set<Id>());
    }
    appIdsByCharterId.get(row.charterId).add(row.applicationId);
  }

  @TestVisible
  private List<AcademicInterestCharterRow> queryEligiblePoolRows(
    Set<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    String query =
      'SELECT IndividualApplicationId, ' +
      'Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__r.ParentId ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds ' +
      'AND Status = :eligibleStatus ' +
      'AND Staff_Priority_Removed__c = false';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'eligibleStatus' => LotteryConstants.STATUS_ELIGIBLE
    };
    if (startDate != null) {
      query += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      query += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    return toCharterRows((List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds));
  }

  @TestVisible
  private List<AcademicInterestCharterRow> queryPlacedRows(
    Set<Id> timelineIds,
    Set<Id> charterIds
  ) {
    String query =
      'SELECT IndividualApplicationId, ' +
      'Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__r.ParentId ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__r.Program_Term_Application_Timeline__r.ApplicationTimelineId IN :timelineIds ' +
      'AND Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__r.ParentId IN :charterIds ' +
      'AND Status IN :placedStatuses ' +
      'AND Staff_Priority_Removed__c = false';

    List<AcademicInterest> rows = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'timelineIds' => timelineIds,
        'charterIds' => charterIds,
        'placedStatuses' => PLACED_STATUSES
      }
    );
    return toCharterRows(rows);
  }

  private List<AcademicInterestCharterRow> toCharterRows(List<AcademicInterest> rows) {
    List<AcademicInterestCharterRow> result = new List<AcademicInterestCharterRow>();
    for (AcademicInterest ai : rows) {
      AcademicInterestCharterRow row = new AcademicInterestCharterRow();
      row.charterId = (Id) ai.getSObject('Lottery_Capacity__r')
        ?.getSObject('Program_Term_Application_Timeline__r')
        ?.getSObject('LearningProgram')
        ?.getSObject('School__r')
        ?.get('ParentId');
      row.applicationId = ai.IndividualApplicationId;
      result.add(row);
    }
    return result;
  }

  @TestVisible
  private Set<Id> queryApprovedStaffApplicationIds(Set<Id> applicationIds) {
    Set<Id> approvedIds = new Set<Id>();
    if (applicationIds == null || applicationIds.isEmpty()) {
      return approvedIds;
    }
    List<Priority_Item__c> priorityItems = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      'SELECT Related_Application__c FROM Priority_Item__c ' +
        'WHERE Related_Application__c IN :applicationIds ' +
        'AND Priority_Type__c = :priorityType AND Review_Status__c = :reviewStatus',
      new Map<String, Object>{
        'applicationIds' => applicationIds,
        'priorityType' => PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF,
        'reviewStatus' => PriorityItemConstants.REVIEW_STATUS_APPROVED
      }
    );
    for (Priority_Item__c item : priorityItems) {
      if (item.Related_Application__c != null) {
        approvedIds.add(item.Related_Application__c);
      }
    }
    return approvedIds;
  }

  @TestVisible
  private List<AcademicInterest> queryPoolAcademicInterests(
    Set<Id> capacityIds,
    Id charterId,
    Date startDate,
    Date endDate
  ) {
    String query =
      'SELECT Id, IndividualApplicationId ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__c IN :capacityIds ' +
      'AND Status = :eligibleStatus ' +
      'AND Staff_Priority_Removed__c = false ' +
      'AND Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgram.School__r.ParentId = :charterId';

    Map<String, Object> binds = new Map<String, Object>{
      'capacityIds' => capacityIds,
      'eligibleStatus' => LotteryConstants.STATUS_ELIGIBLE,
      'charterId' => charterId
    };
    if (startDate != null) {
      query += ' AND Application_Submitted_Date__c >= :startDate';
      binds.put('startDate', startDate);
    }
    if (endDate != null) {
      query += ' AND Application_Submitted_Date__c <= :endDate';
      binds.put('endDate', endDate);
    }

    return (List<AcademicInterest>) databaseRepo.queryWithBinds(query, binds);
  }

  @TestVisible
  private Set<Id> queryPlacedApplicationIdsForCharter(Set<Id> capacityIds, Id charterId) {
    Map<Id, CapacityCharterInfo> infoByCapacityId = queryCapacityCharterInfo(capacityIds);
    Set<Id> timelineIds = new Set<Id>();
    for (CapacityCharterInfo info : infoByCapacityId.values()) {
      if (info.timelineId != null) {
        timelineIds.add(info.timelineId);
      }
    }
    if (timelineIds.isEmpty()) {
      return new Set<Id>();
    }

    Set<Id> placedAppIds = new Set<Id>();
    for (AcademicInterestCharterRow row : queryPlacedRows(timelineIds, new Set<Id>{ charterId })) {
      if (row.applicationId != null) {
        placedAppIds.add(row.applicationId);
      }
    }
    return placedAppIds;
  }

  private Map<Id, List<AcademicInterest>> groupByApplicationId(List<AcademicInterest> records) {
    Map<Id, List<AcademicInterest>> grouped = new Map<Id, List<AcademicInterest>>();
    for (AcademicInterest academicInterest : records) {
      if (academicInterest.IndividualApplicationId == null) {
        continue;
      }
      if (!grouped.containsKey(academicInterest.IndividualApplicationId)) {
        grouped.put(academicInterest.IndividualApplicationId, new List<AcademicInterest>());
      }
      grouped.get(academicInterest.IndividualApplicationId).add(academicInterest);
    }
    return grouped;
  }

  private Map<Id, List<AcademicInterest>> retainKeys(
    Map<Id, List<AcademicInterest>> source,
    Set<Id> keysToKeep
  ) {
    Map<Id, List<AcademicInterest>> result = new Map<Id, List<AcademicInterest>>();
    for (Id key : source.keySet()) {
      if (keysToKeep.contains(key)) {
        result.put(key, source.get(key));
      }
    }
    return result;
  }

  @TestVisible
  private List<Id> drawRemovalOrder(Set<Id> applicationIds) {
    List<KeyedApplicationId> keyed = new List<KeyedApplicationId>();
    for (Id applicationId : applicationIds) {
      KeyedApplicationId entry = new KeyedApplicationId();
      entry.applicationId = applicationId;
      entry.key = keySource.nextKey();
      keyed.add(entry);
    }
    keyed.sort();

    List<Id> ordered = new List<Id>();
    for (KeyedApplicationId entry : keyed) {
      ordered.add(entry.applicationId);
    }
    return ordered;
  }

  private StaffPriorityCapCharterStats findStats(
    List<StaffPriorityCapCharterStats> stats,
    Id charterId
  ) {
    for (StaffPriorityCapCharterStats charterStats : stats) {
      if (charterStats.charterId == charterId) {
        return charterStats;
      }
    }
    return null;
  }

  private class CapacityCharterInfo {
    Id charterId;
    Id timelineId;
    Decimal learningProgramSeats;
    String schoolName;
  }

  private class AcademicInterestCharterRow {
    Id charterId;
    Id applicationId;
  }

  private class KeyedApplicationId implements Comparable {
    Id applicationId;
    Decimal key;

    public Integer compareTo(Object other) {
      Decimal otherKey = ((KeyedApplicationId) other).key;
      if (key == otherKey) {
        return 0;
      }
      return key < otherKey ? -1 : 1;
    }
  }
}