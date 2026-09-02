/**
 * {@link Mock} implementation of {@link LotterySortService}.
 */
@IsTest
public class LotterySortServiceMock extends Mock implements LotterySortService {
  public final Method method = new Method();

  public void assignRandomizedSortKeys(List<AcademicInterest> records) {
    mockedCall(method.assignRandomizedSortKeys(), new Map<String, Object>{ 'records' => records });
  }

  public List<AcademicInterest> sortByLotteryOrder(List<AcademicInterest> records) {
    return (List<AcademicInterest>) mockedCall(
      method.sortByLotteryOrder(),
      new Map<String, Object>{ 'records' => records }
    );
  }

  public List<AcademicInterest> getTopCandidatesForCapacity(
    Id lotteryCapacityId,
    Integer availableSeats
  ) {
    return (List<AcademicInterest>) mockedCall(
      method.getTopCandidatesForCapacity(),
      new Map<String, Object>{
        'lotteryCapacityId' => lotteryCapacityId,
        'availableSeats' => availableSeats
      }
    );
  }

  public class Method {
    public String assignRandomizedSortKeys() {
      return new ExecutionInfo().getFullName();
    }

    public String sortByLotteryOrder() {
      return new ExecutionInfo().getFullName();
    }

    public String getTopCandidatesForCapacity() {
      return new ExecutionInfo().getFullName();
    }
  }
}