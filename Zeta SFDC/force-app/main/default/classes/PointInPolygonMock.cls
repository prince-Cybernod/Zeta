/**
 * {@link Mock} implementation of {@link PointInPolygon}.
 */
@IsTest
public class PointInPolygonMock extends Mock implements PointInPolygon {
  public final Method method = new Method();

  public Boolean isInside(Decimal lat, Decimal lng, List<List<Decimal>> ring) {
    return (Boolean) mockedCall(
      method.isInside(),
      new Map<String, Object>{ 'lat' => lat, 'lng' => lng, 'ring' => ring }
    );
  }

  public class Method {
    public String isInside() {
      return new ExecutionInfo().getFullName();
    }
  }
}