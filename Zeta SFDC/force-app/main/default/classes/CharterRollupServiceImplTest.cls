/**
 * Tests for {@link CharterRollupServiceImpl}.
 */
@IsTest(IsParallel=true)
private class CharterRollupServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final CharterRollupServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new CharterRollupServiceImpl(MOCK_REPO);
  }

  private static Account buildCharter(Id charterId, Decimal emp, Decimal seats) {
    return new Account(
      Id = charterId,
      Count_Lottery_Employee_Priority__c = emp,
      Total_Available_Seats_for_School_Year__c = seats
    );
  }

  /**
   * ApplicationTimeline.Active__c and the LearningProgram/School__r
   * relationships are read-only, so the row is built via JSON.deserialize.
   */
  private static ProgramTermApplnTimeline buildLink(
    Id learningProgramId,
    Id charterId,
    Boolean active,
    String closeDateIso
  ) {
    String closeDateJson = closeDateIso == null ? 'null' : '"' + closeDateIso + '"';
    String payload =
      '{"LearningProgramId":"' +
      learningProgramId +
      '","LearningProgram":{"School__r":{"ParentId":"' +
      charterId +
      '"}},"ApplicationTimeline":{"Active__c":' +
      active +
      ',"ApplicationCloseDate":' +
      closeDateJson +
      '}}';
    return (ProgramTermApplnTimeline) JSON.deserialize(payload, ProgramTermApplnTimeline.class);
  }

  @IsTest
  private static void recalculate_withEmptySet_doesNotQuery() {
    SERVICE.recalculate(new Set<Id>());

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withNullSet_doesNotQuery() {
    SERVICE.recalculate(null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_withNoCharterAccounts_doesNotQueryFurther() {
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<Account>());

    SERVICE.recalculate(new Set<Id>{ accountId });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 1);
    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void recalculate_filtersCharterAccountsByRecordType() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildCharter(charterId, 0, 0) })
      .thenReturn(new List<ProgramTermApplnTimeline>());

    SERVICE.recalculate(new Set<Id>{ charterId });

    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())[0];
    String query = (String) call.get('query');
    Assert.isTrue(
      query.contains('RecordType.DeveloperName'),
      'Should filter Accounts by the Charter RecordType'
    );
    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(
      'Charter',
      bindMap.get('charterDeveloperName'),
      'Should bind the Charter developer name'
    );
  }

  @IsTest
  private static void recalculate_queriesOpenedTimelinesScopedToCharterIds() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildCharter(charterId, 0, 0) })
      .thenReturn(new List<ProgramTermApplnTimeline>());

    SERVICE.recalculate(new Set<Id>{ charterId });

    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())[1];
    String query = (String) call.get('query');
    Assert.isTrue(
      query.contains('LearningProgram.School__r.ParentId IN :charterIds'),
      'Should scope the timeline links to the Charter-filtered ids'
    );
    Assert.isTrue(
      query.contains('ApplicationTimeline.ApplicationOpenDate <= TODAY'),
      'Should only pull timelines that have opened'
    );
    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(new Set<Id>{ charterId }, bindMap.get('charterIds'));
  }

  @IsTest
  private static void recalculate_withNoOpenedTimelines_skipsAggregateQueryAndWritesZero() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildCharter(charterId, 5, 10) })
      .thenReturn(new List<ProgramTermApplnTimeline>());
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.recalculate(new Set<Id>{ charterId });

    // A Charter that has never opened a timeline contributes no counted
    // LearningProgram ids, so the aggregate query never runs.
    MOCK_REPO.verify(MOCK_REPO.method.queryWithBinds(), 2);
    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Account updated = (Account) ((List<SObject>) updateCalls[0].get('sobjects'))[0];
    Assert.areEqual(0, updated.Count_Lottery_Employee_Priority__c);
    Assert.areEqual(0, updated.Total_Available_Seats_for_School_Year__c);
  }

  @IsTest
  private static void recalculate_withNoOpenedTimelinesAndAlreadyZero_doesNotUpdate() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<Account>{ buildCharter(charterId, 0, 0) })
      .thenReturn(new List<ProgramTermApplnTimeline>());

    SERVICE.recalculate(new Set<Id>{ charterId });

    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void selectCurrentCycleLearningProgramIds_openBeatsClosed() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id openLpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id closedLpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    Set<Id> result = CharterRollupServiceImpl.selectCurrentCycleLearningProgramIds(
      new List<ProgramTermApplnTimeline>{
        buildLink(openLpId, charterId, true, null),
        buildLink(closedLpId, charterId, false, '2026-01-15')
      }
    );

    Assert.areEqual(
      new Set<Id>{ openLpId },
      result,
      'An open timeline should win over a closed one'
    );
  }

  @IsTest
  private static void selectCurrentCycleLearningProgramIds_noOpenUsesLatestCloseWithTies() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id earlyLpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id lateLpId1 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    Id lateLpId2 = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    Set<Id> result = CharterRollupServiceImpl.selectCurrentCycleLearningProgramIds(
      new List<ProgramTermApplnTimeline>{
        buildLink(earlyLpId, charterId, false, '2025-06-01'),
        buildLink(lateLpId1, charterId, false, '2026-01-15'),
        buildLink(lateLpId2, charterId, false, '2026-01-15')
      }
    );

    Assert.areEqual(
      new Set<Id>{ lateLpId1, lateLpId2 },
      result,
      'Should count both timelines tied for the latest close date, and drop the earlier one'
    );
  }

  @IsTest
  private static void selectCurrentCycleLearningProgramIds_withNoLinks_returnsEmptySet() {
    Set<Id> result = CharterRollupServiceImpl.selectCurrentCycleLearningProgramIds(
      new List<ProgramTermApplnTimeline>()
    );

    Assert.areEqual(
      new Set<Id>(),
      result,
      'A Charter with no opened timeline should count nothing'
    );
  }

  @IsTest
  private static void selectCurrentCycleLearningProgramIds_lpOnTwoOpenTimelines_countedOnce() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);

    Set<Id> result = CharterRollupServiceImpl.selectCurrentCycleLearningProgramIds(
      new List<ProgramTermApplnTimeline>{
        buildLink(lpId, charterId, true, null),
        buildLink(lpId, charterId, true, null)
      }
    );

    Assert.areEqual(1, result.size(), 'An LP linked to two open timelines should count once');
    Assert.isTrue(result.contains(lpId));
  }

  @IsTest
  private static void processCharters_withChangedValues_updatesBothFields() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processCharters(
      new List<Account>{ buildCharter(charterId, 0, 0) },
      new Map<Id, CharterRollupAggregateResult>{
        charterId => new CharterRollupAggregateResult(charterId, 3, 42)
      }
    );

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Account updated = (Account) ((List<SObject>) updateCalls[updateCalls.size() - 1]
      .get('sobjects'))[0];
    Assert.areEqual(charterId, updated.Id);
    Assert.areEqual(3, updated.Count_Lottery_Employee_Priority__c);
    Assert.areEqual(42, updated.Total_Available_Seats_for_School_Year__c);
  }

  @IsTest
  private static void processCharters_withNullSum_writesZero() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processCharters(
      new List<Account>{ buildCharter(charterId, 5, 5) },
      new Map<Id, CharterRollupAggregateResult>{
        charterId => new CharterRollupAggregateResult(charterId, null, null)
      }
    );

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Account updated = (Account) ((List<SObject>) updateCalls[updateCalls.size() - 1]
      .get('sobjects'))[0];
    Assert.areEqual(0, updated.Count_Lottery_Employee_Priority__c, 'Null sum should write 0');
    Assert.areEqual(0, updated.Total_Available_Seats_for_School_Year__c, 'Null sum should write 0');
  }

  @IsTest
  private static void processCharters_withUnchangedValues_doesNotUpdate() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    SERVICE.processCharters(
      new List<Account>{ buildCharter(charterId, 3, 42) },
      new Map<Id, CharterRollupAggregateResult>{
        charterId => new CharterRollupAggregateResult(charterId, 3, 42)
      }
    );

    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void processCharters_withNoResultForCharter_writesZero() {
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.updateSObjects()).thenReturnVoid();

    SERVICE.processCharters(
      new List<Account>{ buildCharter(charterId, 3, 42) },
      new Map<Id, CharterRollupAggregateResult>()
    );

    List<Map<String, Object>> updateCalls = MOCK_REPO.getCalls(MOCK_REPO.method.updateSObjects());
    Account updated = (Account) ((List<SObject>) updateCalls[updateCalls.size() - 1]
      .get('sobjects'))[0];
    Assert.areEqual(0, updated.Count_Lottery_Employee_Priority__c);
    Assert.areEqual(0, updated.Total_Available_Seats_for_School_Year__c);
  }

  @IsTest
  private static void processCharters_withNoCharters_doesNotUpdate() {
    SERVICE.processCharters(new List<Account>(), new Map<Id, CharterRollupAggregateResult>());

    MOCK_REPO.never(MOCK_REPO.method.updateSObjects());
  }

  @IsTest
  private static void getResultsByCharterId_withNoLearningProgramIds_doesNotQuery() {
    Map<Id, CharterRollupAggregateResult> result = SERVICE.getResultsByCharterId(new Set<Id>());

    Assert.isTrue(result.isEmpty());
    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void getResultsByCharterId_queriesAggregateGroupedByCharter() {
    Id lpId = SObjectIds.generateFakeId(Schema.LearningProgram.SObjectType);
    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds()).thenReturn(new List<AggregateResult>());

    SERVICE.getResultsByCharterId(new Set<Id>{ lpId });

    Map<String, Object> call = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds())[0];
    String query = (String) call.get('query');
    Assert.isTrue(query.contains('Id IN :countedLearningProgramIds'));
    Assert.isTrue(query.contains('GROUP BY School__r.ParentId'));
    Map<String, Object> bindMap = (Map<String, Object>) call.get('bindMap');
    Assert.areEqual(new Set<Id>{ lpId }, bindMap.get('countedLearningProgramIds'));
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    Assert.isNotNull(new CharterRollupServiceImpl(), 'Should create with default constructor');
  }
}