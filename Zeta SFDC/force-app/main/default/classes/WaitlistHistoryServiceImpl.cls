/**
 * Implementation of {@link WaitlistHistoryService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public with sharing class WaitlistHistoryServiceImpl implements WaitlistHistoryService {
  private final DatabaseRepo databaseRepo;

  public WaitlistHistoryServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private WaitlistHistoryServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void createHistoryRecords(
    Map<Id, AcademicInterest> oldRecordsById,
    List<AcademicInterest> newRecords
  ) {
    if (newRecords == null || newRecords.isEmpty()) {
      return;
    }

    List<Waitlist_Movement_History__c> historyRecordsToInsert = new List<Waitlist_Movement_History__c>();

    for (AcademicInterest newRecord : newRecords) {
      AcademicInterest oldRecord = oldRecordsById.get(newRecord.Id);
      if (oldRecord == null) {
        continue;
      }

      SObjectFieldDiffResponse diff = SObjectFieldDiffer.getFieldDiff(
        newRecord,
        oldRecord,
        WaitlistConstants.HISTORY_TRACKED_FIELDS
      );

      if (diff.isDifferent()) {
        historyRecordsToInsert.add(buildHistoryRecord(oldRecord, newRecord));
      }
    }

    if (!historyRecordsToInsert.isEmpty()) {
      databaseRepo.insertSObjects(historyRecordsToInsert);
    }
  }

  @TestVisible
  private static Waitlist_Movement_History__c buildHistoryRecord(
    AcademicInterest oldRecord,
    AcademicInterest newRecord
  ) {
    return new Waitlist_Movement_History__c(
      School_Application__c = newRecord.Id,
      Previous_Waitlist_Number__c = oldRecord.Waitlist_Position__c,
      New_Waitlist_Number__c = newRecord.Waitlist_Position__c,
      Previous_Priority_Group__c = oldRecord.Current_Priority_Group__c,
      New_Priority_Group__c = newRecord.Current_Priority_Group__c,
      Lottery_Number__c = newRecord.Randomized_Sort_Key__c,
      Changed_On__c = Datetime.now(),
      Change_Reason__c = buildChangeReason(oldRecord, newRecord)
    );
  }

  private static String buildChangeReason(AcademicInterest oldRecord, AcademicInterest newRecord) {
    List<String> reasons = new List<String>();

    if (oldRecord.Status != newRecord.Status) {
      reasons.add('Status: ' + oldRecord.Status + ' → ' + newRecord.Status);
    }

    if (oldRecord.Current_Priority_Group__c != newRecord.Current_Priority_Group__c) {
      reasons.add(
        'Priority Group: ' +
          oldRecord.Current_Priority_Group__c +
          ' → ' +
          newRecord.Current_Priority_Group__c
      );
    }

    if (oldRecord.Waitlist_Position__c != newRecord.Waitlist_Position__c) {
      reasons.add(
        'Position: ' + oldRecord.Waitlist_Position__c + ' → ' + newRecord.Waitlist_Position__c
      );
    }

    return String.join(reasons, '; ');
  }
}