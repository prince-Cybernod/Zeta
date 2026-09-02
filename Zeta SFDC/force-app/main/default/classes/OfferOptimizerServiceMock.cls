/**
 * {@link Mock} implementation of {@link OfferOptimizerService}.
 */
@IsTest
public class OfferOptimizerServiceMock extends Mock implements OfferOptimizerService {
  public final Method method = new Method();

  public List<AcademicInterest> optimizeOffers(
    List<AcademicInterest> records,
    List<LotteryStatusChange> transitions
  ) {
    return (List<AcademicInterest>) mockedCall(
      method.optimizeOffers(),
      new Map<String, Object>{ 'records' => records, 'transitions' => transitions }
    );
  }

  public class Method {
    public String optimizeOffers() {
      return new ExecutionInfo().getFullName();
    }
  }
}