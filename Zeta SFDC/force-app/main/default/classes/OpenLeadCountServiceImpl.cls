/**
 * Implementation of {@link OpenLeadCountService}.
 *
 * User is a setup object, so it cannot be updated via DML in the same
 * transaction as the triggering Lead DML (MIXED_DML_OPERATION). The
 * recalculation is deferred to {@link OpenLeadCountQueueable}.
 */
public with sharing class OpenLeadCountServiceImpl implements OpenLeadCountService {
  @TestVisible
  private Boolean hasEnqueuedJob = false;

  public void recalculateOpenLeadCount(Set<Id> userIds) {
    if (userIds == null || userIds.isEmpty()) {
      return;
    }

    hasEnqueuedJob = true;

    // Skip the real enqueue under test: the job would actually run at
    // Test.stopTest() and hit real DML against fake test-only ids.
    // OpenLeadCountQueueableTest covers execute() directly with a mock.
    if (Test.isRunningTest()) {
      return;
    }
    System.enqueueJob(new OpenLeadCountQueueable(userIds));
  }
}