/**
 * {@link Mock} implementation of {@link WaitlistRecalcService}.
 */
@IsTest
public class WaitlistRecalcServiceMock extends Mock implements WaitlistRecalcService {
  public final Method method = new Method();

  public List<AcademicInterest> recalculatePositions(List<AcademicInterest> records) {
    return (List<AcademicInterest>) mockedCall(
      method.recalculatePositions(),
      new Map<String, Object>{ 'records' => records }
    );
  }

  public List<AcademicInterest> recalculatePositionsByCapacity(List<AcademicInterest> records) {
    return (List<AcademicInterest>) mockedCall(
      method.recalculatePositionsByCapacity(),
      new Map<String, Object>{ 'records' => records }
    );
  }

  public List<AcademicInterest> getRecordsToPromote(
    List<AcademicInterest> sortedRecords,
    Integer availableSeats
  ) {
    return (List<AcademicInterest>) mockedCall(
      method.getRecordsToPromote(),
      new Map<String, Object>{
        'sortedRecords' => sortedRecords,
        'availableSeats' => availableSeats
      }
    );
  }

  public class Method {
    public String recalculatePositions() {
      return new ExecutionInfo().getFullName();
    }

    public String recalculatePositionsByCapacity() {
      return new ExecutionInfo().getFullName();
    }

    public String getRecordsToPromote() {
      return new ExecutionInfo().getFullName();
    }
  }
}