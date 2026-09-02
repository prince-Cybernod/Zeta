/**
 * Service for calculating Current_Priority_Group__c on AcademicInterest records.
 */
public interface CurrentPriorityCalcService {
  /**
   * Calculates and stamps Current_Priority_Group__c on the given AcademicInterest records.
   * Used in BEFORE triggers where records have not yet been inserted/updated.
   * @param academicInterests The AcademicInterest records to calculate priority for
   */
  void calculateForRecords(List<AcademicInterest> academicInterests);

  /**
   * Recalculates Current_Priority_Group__c for all AcademicInterest records
   * related to the given IndividualApplication IDs.
   * Used when parent IndividualApplication.Relationship_Priority_Group__c changes.
   * @param individualApplicationIds The IDs of IndividualApplications whose children need recalculation
   */
  void recalculateForApplications(Set<Id> individualApplicationIds);
}