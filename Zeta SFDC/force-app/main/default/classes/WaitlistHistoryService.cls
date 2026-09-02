/**
 * Service for creating waitlist movement history records.
 */
public interface WaitlistHistoryService {
  /**
   * Creates Waitlist_Movement_History__c records for AcademicInterest records
   * where waitlist-relevant fields have changed (Status, Waitlist_Position__c,
   * Current_Priority_Group__c).
   * @param oldRecordsById Map of old AcademicInterest records by ID
   * @param newRecords List of new AcademicInterest records
   */
  void createHistoryRecords(
    Map<Id, AcademicInterest> oldRecordsById,
    List<AcademicInterest> newRecords
  );
}