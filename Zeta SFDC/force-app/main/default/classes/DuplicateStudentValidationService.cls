/**
 * Service for preventing a guardian from creating a duplicate Student Person Account.
 * A duplicate is another active Student account linked to the same guardian with a
 * matching first name, last name, and (when provided) date of birth.
 */
public interface DuplicateStudentValidationService {
  /**
   * Throws an AuraHandledException when the guardian already has a matching Student
   * account. No-op when there is nothing to match on (missing guardian or name).
   *
   * @param firstName the prospective student's first name
   * @param lastName the prospective student's last name
   * @param birthdate the prospective student's date of birth as 'yyyy-MM-dd', or blank
   * @param guardianContactId the guardian's Contact Id (the AccountContactRelation ContactId)
   */
  void assertNoDuplicate(String firstName, String lastName, String birthdate, Id guardianContactId);
}