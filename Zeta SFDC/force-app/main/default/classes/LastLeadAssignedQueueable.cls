/**
 * Queueable job that stamps User.Last_Lead_Assigned__c for a set of Users.
 *
 * Runs outside the triggering Lead transaction because User is a setup
 * object (MIXED_DML_OPERATION otherwise). The stamp timestamp is captured by
 * the caller at trigger time and passed in, since this job may run later.
 */
public with sharing class LastLeadAssignedQueueable implements Queueable {
  private final Set<Id> userIds;
  private final Datetime assignedAt;
  private final DatabaseRepo databaseRepo;

  public LastLeadAssignedQueueable(Set<Id> userIds, Datetime assignedAt) {
    this(userIds, assignedAt, new SystemModeDatabaseRepo());
  }

  @TestVisible
  private LastLeadAssignedQueueable(
    Set<Id> userIds,
    Datetime assignedAt,
    DatabaseRepo databaseRepo
  ) {
    this.userIds = userIds;
    this.assignedAt = assignedAt;
    this.databaseRepo = databaseRepo;
  }

  public void execute(QueueableContext context) {
    if (userIds == null || userIds.isEmpty()) {
      return;
    }

    List<User> usersToUpdate = new List<User>();
    for (Id userId : userIds) {
      usersToUpdate.add(new User(Id = userId, Last_Lead_Assigned__c = assignedAt));
    }

    databaseRepo.updateSObjects(usersToUpdate);
  }
}