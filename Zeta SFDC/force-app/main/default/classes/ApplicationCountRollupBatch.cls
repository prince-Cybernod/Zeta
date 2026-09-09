/**
 * Recalculates {@link Account.Application_Count__c} across every applicant
 * Account, for the initial backfill and for repairing drift after a bulk load.
 *
 * Run with scripts/data/migrations/backfill-application-count.apex.
 */
public without sharing class ApplicationCountRollupBatch implements Database.Batchable<SObject> {
  /**
   * The record types an application can be attached to: the student and both
   * guardian lookups are filtered to these.
   */
  private static final Set<String> APPLICANT_RECORD_TYPES = new Set<String>{
    'Guardian',
    'Student'
  };

  private final DatabaseRepo databaseRepo;
  private final ApplicationCountRollupService rollupService;

  public ApplicationCountRollupBatch() {
    this(new SystemModeDatabaseRepo(), new ApplicationCountRollupServiceImpl());
  }

  @TestVisible
  private ApplicationCountRollupBatch(
    DatabaseRepo databaseRepo,
    ApplicationCountRollupService rollupService
  ) {
    this.databaseRepo = databaseRepo;
    this.rollupService = rollupService;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Set<Id> recordTypeIds = getApplicantRecordTypeIds();
    return databaseRepo.getQueryLocatorWithBinds(
      'SELECT Id FROM Account WHERE RecordTypeId IN :recordTypeIds',
      new Map<String, Object>{ 'recordTypeIds' => recordTypeIds }
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
  private static Set<Id> getApplicantRecordTypeIds() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

    Set<Id> recordTypeIds = new Set<Id>();
    for (String developerName : APPLICANT_RECORD_TYPES) {
      Schema.RecordTypeInfo recordTypeInfo = recordTypeInfos.get(developerName);
      if (recordTypeInfo != null) {
        recordTypeIds.add(recordTypeInfo.getRecordTypeId());
      }
    }
    return recordTypeIds;
  }
}