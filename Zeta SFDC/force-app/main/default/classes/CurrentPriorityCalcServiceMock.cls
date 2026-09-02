/**
 * Mock implementation of {@link CurrentPriorityCalcService} for testing.
 */
@IsTest
public class CurrentPriorityCalcServiceMock extends Mock implements CurrentPriorityCalcService {
  public final Method method = new Method();

  public void calculateForRecords(List<AcademicInterest> academicInterests) {
    mockedCall(
      method.calculateForRecords(),
      new Map<String, Object>{ 'academicInterests' => academicInterests }
    );
  }

  public void recalculateForApplications(Set<Id> individualApplicationIds) {
    mockedCall(
      method.recalculateForApplications(),
      new Map<String, Object>{ 'individualApplicationIds' => individualApplicationIds }
    );
  }

  public class Method {
    public String calculateForRecords() {
      return new ExecutionInfo().getFullName();
    }
    public String recalculateForApplications() {
      return new ExecutionInfo().getFullName();
    }
  }
}