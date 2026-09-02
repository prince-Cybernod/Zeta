/**
 * {@link Mock} implementation of {@link GoogleMapsApi}. Used by downstream
 * tests so they don't need a real HTTP mock.
 */
@IsTest
public class GoogleMapsApiMock extends Mock implements GoogleMapsApi {
  public final Method method = new Method();

  public GeocodeResult geocode(String address) {
    return (GeocodeResult) mockedCall(
      method.geocode(),
      new Map<String, Object>{ 'address' => address }
    );
  }

  public class Method {
    public String geocode() {
      return new ExecutionInfo().getFullName();
    }
  }
}