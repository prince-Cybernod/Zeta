/**
 * Queueable job that recalculates and stamps User.Open_Lead_Count__c for a
 * set of Users.
 *
 * Runs outside the triggering Lead transaction because User is a setup
 * object (MIXED_DML_OPERATION otherwise). Always re-derives the true count
 * from Lead data rather than incrementing or decrementing a stored value.
 */
public with sharing class OpenLeadCountQueueable implements Queueable {
  private final Set<Id> userIds;
  private final DatabaseRepo databaseRepo;

  public OpenLeadCountQueueable(Set<Id> userIds) {
    this(userIds, new SystemModeDatabaseRepo());
  }

  @TestVisible
  private OpenLeadCountQueueable(Set<Id> userIds, DatabaseRepo databaseRepo) {
    this.userIds = userIds;
    this.databaseRepo = databaseRepo;
  }

  public void execute(QueueableContext context) {
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

    processAggregateResults(OpenLeadCountAggregateResult.fromAggregateResults(aggregateResults));
  }

  @TestVisible
  private void processAggregateResults(List<OpenLeadCountAggregateResult> results) {
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
      usersToUpdate.add(new User(Id = userId, Open_Lead_Count__c = countsByUserId.get(userId)));
    }

    databaseRepo.updateSObjects(usersToUpdate);
  }
}