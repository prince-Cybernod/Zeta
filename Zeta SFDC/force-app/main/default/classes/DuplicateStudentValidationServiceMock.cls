/**
 * Mock implementation of {@link DuplicateStudentValidationService} for testing.
 */
@IsTest
public class DuplicateStudentValidationServiceMock extends Mock implements DuplicateStudentValidationService {
  public final Method method = new Method();

  public void assertNoDuplicate(
    String firstName,
    String lastName,
    String birthdate,
    Id guardianContactId
  ) {
    mockedCall(
      method.assertNoDuplicate(),
      new Map<String, Object>{
        'firstName' => firstName,
        'lastName' => lastName,
        'birthdate' => birthdate,
        'guardianContactId' => guardianContactId
      }
    );
  }

  public class Method {
    public String assertNoDuplicate() {
      return new ExecutionInfo().getFullName();
    }
  }
}