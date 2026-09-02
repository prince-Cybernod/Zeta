/**
 * {@link Mock} implementation of {@link WaitlistSortService}.
 */
@IsTest
public class WaitlistSortServiceMock extends Mock implements WaitlistSortService {
  public final Method method = new Method();

  public List<AcademicInterest> sortAndAssignPositions(List<AcademicInterest> records) {
    return (List<AcademicInterest>) mockedCall(
      method.sortAndAssignPositions(),
      new Map<String, Object>{ 'records' => records }
    );
  }

  public class Method {
    public String sortAndAssignPositions() {
      return new ExecutionInfo().getFullName();
    }
  }
}