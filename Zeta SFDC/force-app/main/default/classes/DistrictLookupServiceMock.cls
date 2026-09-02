/**
 * {@link Mock} implementation of {@link DistrictLookupService}.
 */
@IsTest
public class DistrictLookupServiceMock extends Mock implements DistrictLookupService {
  public final Method method = new Method();

  public String findDistrictForPoint(Decimal latitude, Decimal longitude) {
    return (String) mockedCall(
      method.findDistrictForPoint(),
      new Map<String, Object>{ 'latitude' => latitude, 'longitude' => longitude }
    );
  }

  public class Method {
    public String findDistrictForPoint() {
      return new ExecutionInfo().getFullName();
    }
  }
}