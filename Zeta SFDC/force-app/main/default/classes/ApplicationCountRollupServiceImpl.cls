/**
 * Implementation of {@link ApplicationCountRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class ApplicationCountRollupServiceImpl implements ApplicationCountRollupService {
  private final DatabaseRepo databaseRepo;

  public ApplicationCountRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private ApplicationCountRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty()) {
      return;
    }

    // A Guardian Account can only ever appear in the two guardian lookups and a
    // Student Account only in AccountId — all three carry active lookup filters
    // pinning the record type. The three tallies are therefore disjoint per
    // Account and can be summed without knowing which record type an Id is.
    List<ApplicationCountAggregateResult> wrappedResults = new List<ApplicationCountAggregateResult>();
    for (
      String field : new List<String>{ 'Primary_Guardian__c', 'Secondary_Guardian__c', 'AccountId' }
    ) {
      String query =
        'SELECT ' +
        field +
        ' acctId, COUNT(Id) cnt ' +
        'FROM IndividualApplication ' +
        'WHERE ' +
        field +
        ' IN :accountIds ' +
        'GROUP BY ' +
        field;

      List<AggregateResult> results = databaseRepo.queryWithBinds(
        query,
        new Map<String, Object>{ 'accountIds' => accountIds }
      );
      wrappedResults.addAll(ApplicationCountAggregateResult.fromAggregateResults(results));
    }

    processAggregateResults(accountIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> accountIds,
    List<ApplicationCountAggregateResult> wrappedResults
  ) {
    Map<Id, Decimal> countsByAccountId = new Map<Id, Decimal>();
    for (Id accountId : accountIds) {
      countsByAccountId.put(accountId, 0);
    }

    // Accumulated, not overwritten: a guardian named on an application as both
    // primary and secondary contributes from two of the three queries.
    for (ApplicationCountAggregateResult result : wrappedResults) {
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
        new Account(Id = accountId, Application_Count__c = countsByAccountId.get(accountId))
      );
    }

    if (!accountsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(accountsToUpdate);
    }
  }
}