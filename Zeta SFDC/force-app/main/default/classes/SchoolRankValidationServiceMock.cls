/**
 * Mock implementation of {@link SchoolRankValidationService} for testing.
 */
@IsTest
public class SchoolRankValidationServiceMock extends Mock implements SchoolRankValidationService {
  public final Method method = new Method();

  public void validateUniqueRanks(List<AcademicInterest> triggerRecords) {
    mockedCall(
      method.validateUniqueRanks(),
      new Map<String, Object>{ 'triggerRecords' => triggerRecords }
    );
  }

  public class Method {
    public String validateUniqueRanks() {
      return new ExecutionInfo().getFullName();
    }
  }
}