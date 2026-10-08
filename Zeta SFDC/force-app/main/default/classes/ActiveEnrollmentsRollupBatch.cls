/**
 * Recalculates {@link Account.Active_Enrollments__c} across every learner and
 * guardian Account, for the initial backfill, for repairing drift after a
 * bulk load, and nightly via {@link ActiveEnrollmentsRollupSchedulable}.
 *
 * Run once with scripts/data/migrations/backfill-active-enrollments.apex;
 * scheduled nightly by scripts/data/migrations/schedule-active-enrollments-rollup.apex.
 */
public without sharing class ActiveEnrollmentsRollupBatch implements Database.Batchable<SObject> {
  /**
   * The Account record types that can appear as a learner or a guardian,
   * matching the population Application Count's batch scopes to.
   */
  private static final Set<String> ENROLLMENT_RECORD_TYPES = new Set<String>{
    'Guardian',
    'Student'
  };

  private final DatabaseRepo databaseRepo;
  private final ActiveEnrollmentsRollupService rollupService;

  public ActiveEnrollmentsRollupBatch() {
    this(new SystemModeDatabaseRepo(), new ActiveEnrollmentsRollupServiceImpl());
  }

  @TestVisible
  private ActiveEnrollmentsRollupBatch(
    DatabaseRepo databaseRepo,
    ActiveEnrollmentsRollupService rollupService
  ) {
    this.databaseRepo = databaseRepo;
    this.rollupService = rollupService;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    Set<Id> recordTypeIds = getEnrollmentRecordTypeIds();
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
  private static Set<Id> getEnrollmentRecordTypeIds() {
    Map<String, Schema.RecordTypeInfo> recordTypeInfos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

    Set<Id> recordTypeIds = new Set<Id>();
    for (String developerName : ENROLLMENT_RECORD_TYPES) {
      Schema.RecordTypeInfo recordTypeInfo = recordTypeInfos.get(developerName);
      if (recordTypeInfo != null) {
        recordTypeIds.add(recordTypeInfo.getRecordTypeId());
      }
    }
    return recordTypeIds;
  }
}