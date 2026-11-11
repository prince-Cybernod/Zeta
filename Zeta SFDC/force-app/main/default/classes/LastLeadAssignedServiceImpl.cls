/**
 * Implementation of {@link LastLeadAssignedService}.
 *
 * User is a setup object, so it cannot be updated via DML in the same
 * transaction as the triggering Lead DML (MIXED_DML_OPERATION). The update is
 * deferred to {@link LastLeadAssignedQueueable}.
 */
public with sharing class LastLeadAssignedServiceImpl implements LastLeadAssignedService {
  @TestVisible
  private Boolean hasEnqueuedJob = false;

  public void stampLastLeadAssigned(Set<Id> userIds, Datetime assignedAt) {
    if (userIds == null || userIds.isEmpty()) {
      return;
    }

    hasEnqueuedJob = true;

    // Skip the real enqueue under test: the job would actually run at
    // Test.stopTest() and hit real DML against fake test-only ids.
    // LastLeadAssignedQueueableTest covers execute() directly with a mock.
    if (Test.isRunningTest()) {
      return;
    }
    System.enqueueJob(new LastLeadAssignedQueueable(userIds, assignedAt));
  }
}