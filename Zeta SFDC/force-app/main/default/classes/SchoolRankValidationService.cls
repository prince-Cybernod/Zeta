/**
 * Service for validating School_Rank__c uniqueness per IndividualApplication.
 */
public interface SchoolRankValidationService {
  /**
   * Validates that School_Rank__c is unique per IndividualApplicationId.
   * Adds field-level errors to trigger records that violate the uniqueness constraint.
   * Must be called from AFTER INSERT/UPDATE context.
   *
   * @param academicInterests The AcademicInterest records from Trigger.new
   */
  void validateUniqueRanks(List<AcademicInterest> academicInterests);
}