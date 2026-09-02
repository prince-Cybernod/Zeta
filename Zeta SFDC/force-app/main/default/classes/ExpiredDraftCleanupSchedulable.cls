/**
 * Scheduled job that expires draft applications after the enrollment period closes.
 *
 * Queries ApplicationTimeline for closed periods and sets any remaining
 * Draft applications to Expired status.
 *
 * Schedule example (nightly at midnight):
 * System.schedule('Expired Draft Cleanup', '0 0 0 * * ?', new ExpiredDraftCleanupSchedulable());
 */
public without sharing class ExpiredDraftCleanupSchedulable implements Schedulable {
  private final DatabaseRepo databaseRepo;

  public ExpiredDraftCleanupSchedulable() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private ExpiredDraftCleanupSchedulable(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void execute(SchedulableContext sc) {
    String timelineQuery =
      'SELECT Id FROM ApplicationTimeline' +
      ' WHERE Active__c = true' +
      ' AND ApplicationCloseDate < TODAY';
    List<ApplicationTimeline> closedTimelines = (List<ApplicationTimeline>) databaseRepo.queryWithBinds(
      timelineQuery,
      new Map<String, Object>()
    );

    if (closedTimelines.isEmpty()) {
      return;
    }

    String draftStatus = 'Draft';
    String draftQuery =
      'SELECT Id, Status FROM IndividualApplication' + ' WHERE Status = :draftStatus';
    List<IndividualApplication> drafts = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      draftQuery,
      new Map<String, Object>{ 'draftStatus' => draftStatus }
    );

    if (drafts.isEmpty()) {
      return;
    }

    for (IndividualApplication app : drafts) {
      app.Status = 'Expired';
    }

    databaseRepo.updateSObjects(drafts);
  }
}