/**
 * Recalculates the Charter-level rollup (Account.Count_Lottery_Employee_Priority__c,
 * Account.Total_Available_Seats_for_School_Year__c) across every Charter Account.
 *
 * Run nightly by {@link CharterRollupSchedulable} to pick up a window opening
 * or closing with no field edit (Active__c is a date formula, so it fires no
 * trigger of its own) and to self-heal from any missed or failed run.
 *
 * Scheduled once, along with the initial backfill, by
 * scripts/data/migrations/schedule-charter-rollup.apex.
 */
public without sharing class CharterRollupBatch implements Database.Batchable<SObject> {
  private static final String CHARTER_RECORD_TYPE_DEVELOPER_NAME = 'Charter';

  private final DatabaseRepo databaseRepo;
  private final CharterRollupService rollupService;

  public CharterRollupBatch() {
    this(new SystemModeDatabaseRepo(), new CharterRollupServiceImpl());
  }

  @TestVisible
  private CharterRollupBatch(DatabaseRepo databaseRepo, CharterRollupService rollupService) {
    this.databaseRepo = databaseRepo;
    this.rollupService = rollupService;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Id charterRecordTypeId = getCharterRecordTypeId();
    return databaseRepo.getQueryLocatorWithBinds(
      'SELECT Id FROM Account WHERE RecordTypeId = :charterRecordTypeId',
      new Map<String, Object>{ 'charterRecordTypeId' => charterRecordTypeId }
    );
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    rollupService.recalculate(new Map<Id, SObject>(scope).keySet());
  }

  /**
   * Each chunk commits its own counts, so there is nothing left to do once the
   * last one finishes. Check the job's error count under Setup > Apex Jobs.
   */
  @SuppressWarnings('PMD.EmptyStatementBlock')
  public void finish(Database.BatchableContext context) {
  }

  @TestVisible
  private static Id getCharterRecordTypeId() {
    return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get(CHARTER_RECORD_TYPE_DEVELOPER_NAME)
      .getRecordTypeId();
  }
}