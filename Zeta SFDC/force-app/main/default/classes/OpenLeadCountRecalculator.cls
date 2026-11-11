/**
 * Recalculates User.Open_Lead_Count__c for a set of Users, optionally stamping
 * User.Last_Lead_Assigned__c on the same User update.
 *
 * Runs from the {@link Lead_Owner_Event__e} subscriber, in its own transaction, so it is free of
 * whatever async context created the underlying Lead. Always re-derives the true count from Lead
 * data rather than incrementing or decrementing a stored value.
 */
public with sharing class OpenLeadCountRecalculator {
  private static final Integer MAX_RETRIES = 9;

  private final DatabaseRepo databaseRepo;

  public OpenLeadCountRecalculator() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private OpenLeadCountRecalculator(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> userIds, Map<Id, Datetime> lastLeadAssignedByUserId) {
    if (userIds == null || userIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT OwnerId, COUNT(Id) cnt ' +
      'FROM Lead ' +
      'WHERE Is_Open_Status__c = true AND OwnerId IN :userIds ' +
      'GROUP BY OwnerId';

    List<AggregateResult> aggregateResults = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'userIds' => userIds }
    );

    processAggregateResults(
      userIds,
      OpenLeadCountAggregateResult.fromAggregateResults(aggregateResults),
      lastLeadAssignedByUserId == null ? new Map<Id, Datetime>() : lastLeadAssignedByUserId
    );
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> userIds,
    List<OpenLeadCountAggregateResult> results,
    Map<Id, Datetime> lastLeadAssignedByUserId
  ) {
    // Users with no matching open Leads never appear in the aggregate
    // results, so seed every requested id at 0 before overlaying counts.
    Map<Id, Decimal> countsByUserId = new Map<Id, Decimal>();
    for (Id userId : userIds) {
      countsByUserId.put(userId, 0);
    }
    for (OpenLeadCountAggregateResult result : results) {
      countsByUserId.put(result.ownerId, result.count);
    }

    List<User> usersToUpdate = new List<User>();
    for (Id userId : countsByUserId.keySet()) {
      User userToUpdate = new User(Id = userId, Open_Lead_Count__c = countsByUserId.get(userId));
      if (lastLeadAssignedByUserId.containsKey(userId)) {
        userToUpdate.Last_Lead_Assigned__c = lastLeadAssignedByUserId.get(userId);
      }
      usersToUpdate.add(userToUpdate);
    }

    updateWithRetry(usersToUpdate);
  }

  /**
   * A locked User row (UNABLE_TO_LOCK_ROW) surfaces as a DmlException here; retry the whole
   * event batch through the platform rather than losing the recount, up to the documented retry
   * cap. Any other DML failure is not transient, so it is rethrown unchanged.
   */
  private void updateWithRetry(List<User> usersToUpdate) {
    try {
      databaseRepo.updateSObjects(usersToUpdate);
    } catch (DmlException e) {
      if (isLockException(e) && getRetryCount() < MAX_RETRIES) {
        throw new EventBus.RetryableException(e.getMessage());
      }
      throw e;
    }
  }

  private static Boolean isLockException(DmlException e) {
    return e.getMessage().contains('UNABLE_TO_LOCK_ROW');
  }

  private static Integer getRetryCount() {
    if (retryCountOverride != null) {
      return retryCountOverride;
    }
    EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
    return context == null ? 0 : context.retries;
  }

  @TestVisible
  private static Integer retryCountOverride;
}