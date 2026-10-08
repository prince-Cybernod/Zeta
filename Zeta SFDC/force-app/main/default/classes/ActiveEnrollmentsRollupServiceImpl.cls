/**
 * Implementation of {@link ActiveEnrollmentsRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class ActiveEnrollmentsRollupServiceImpl implements ActiveEnrollmentsRollupService {
  /**
   * The three paths from an Account to an Academic Term Enrollment: the
   * learner directly, or either of the learner's guardians.
   */
  private static final List<String> ENROLLMENT_LOOKUP_FIELDS = new List<String>{
    'LearnerAccountId',
    'LearnerAccount.Primary_Guardian__c',
    'LearnerAccount.Secondary_Guardian__c'
  };

  private final DatabaseRepo databaseRepo;

  public ActiveEnrollmentsRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private ActiveEnrollmentsRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty()) {
      return;
    }

    // An Account's role isn't known in advance, so all three queries run and
    // their results are summed per Account.
    List<ActiveEnrollmentsAggregateResult> wrappedResults = new List<ActiveEnrollmentsAggregateResult>();
    for (String field : ENROLLMENT_LOOKUP_FIELDS) {
      String query =
        'SELECT ' +
        field +
        ' acctId, COUNT(Id) cnt ' +
        'FROM AcademicTermEnrollment ' +
        'WHERE ' +
        field +
        ' IN :accountIds ' +
        'AND Active__c = true ' +
        'GROUP BY ' +
        field;

      List<AggregateResult> results = databaseRepo.queryWithBinds(
        query,
        new Map<String, Object>{ 'accountIds' => accountIds }
      );
      wrappedResults.addAll(ActiveEnrollmentsAggregateResult.fromAggregateResults(results));
    }

    processAggregateResults(accountIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> accountIds,
    List<ActiveEnrollmentsAggregateResult> wrappedResults
  ) {
    Map<Id, Decimal> countsByAccountId = new Map<Id, Decimal>();
    for (Id accountId : accountIds) {
      countsByAccountId.put(accountId, 0);
    }

    // Accumulated, not overwritten: an Account's count can come from any
    // combination of the three queries — e.g. the same guardian is Primary
    // on one child's enrollment and Secondary on another's.
    for (ActiveEnrollmentsAggregateResult result : wrappedResults) {
      if (!countsByAccountId.containsKey(result.accountId)) {
        continue;
      }
      countsByAccountId.put(
        result.accountId,
        countsByAccountId.get(result.accountId) + result.count
      );
    }

    List<Account> accountsToUpdate = new List<Account>();
    for (Id accountId : countsByAccountId.keySet()) {
      accountsToUpdate.add(
        new Account(Id = accountId, Active_Enrollments__c = countsByAccountId.get(accountId))
      );
    }

    if (!accountsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(accountsToUpdate);
    }
  }
}