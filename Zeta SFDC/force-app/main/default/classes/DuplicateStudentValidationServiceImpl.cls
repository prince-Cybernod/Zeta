/**
 * Implementation of {@link DuplicateStudentValidationService}.
 *
 * Blocks creation of a second Student Person Account for the same guardian when the
 * first name, last name, and date of birth all match an existing active student. Scoped
 * to the guardian via AccountContactRelation, so twins (same last name + DOB, different
 * first name) and same-named students in different households are allowed.
 */
public with sharing class DuplicateStudentValidationServiceImpl implements DuplicateStudentValidationService {
  @TestVisible
  private static final String DUPLICATE_STUDENT_MESSAGE = 'A student with this name and date of birth already exists for your account. Contact Zeta if you need help.';

  private final DatabaseRepo databaseRepo;

  public DuplicateStudentValidationServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private DuplicateStudentValidationServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void assertNoDuplicate(
    String firstName,
    String lastName,
    String birthdate,
    Id guardianContactId
  ) {
    if (guardianContactId == null || String.isBlank(firstName) || String.isBlank(lastName)) {
      return;
    }

    String firstNameValue = firstName.trim();
    String lastNameValue = lastName.trim();
    // DOB is optional (e.g. the applying-sibling form may omit it). When present we match
    // on it; when blank we fall back to a name-only match for the same guardian.
    Date birthdateValue = String.isNotBlank(birthdate) ? Date.valueOf(birthdate) : null;

    // SOQL string '=' is case-insensitive, so the name match ignores casing.
    String query =
      'SELECT AccountId FROM AccountContactRelation' +
      ' WHERE ContactId = :guardianContactId' +
      ' AND IsActive = TRUE' +
      ' AND Account.RecordType.DeveloperName = \'Student\'' +
      ' AND Account.FirstName = :firstNameValue' +
      ' AND Account.LastName = :lastNameValue' +
      (birthdateValue != null ? ' AND Account.PersonBirthdate = :birthdateValue' : '') +
      ' LIMIT 1';

    Map<String, Object> binds = new Map<String, Object>{
      'guardianContactId' => guardianContactId,
      'firstNameValue' => firstNameValue,
      'lastNameValue' => lastNameValue
    };
    if (birthdateValue != null) {
      binds.put('birthdateValue', birthdateValue);
    }

    List<AccountContactRelation> duplicates = (List<AccountContactRelation>) databaseRepo.queryWithBinds(
      query,
      binds
    );

    if (!duplicates.isEmpty()) {
      throw new AuraHandledException(DUPLICATE_STUDENT_MESSAGE);
    }
  }
}