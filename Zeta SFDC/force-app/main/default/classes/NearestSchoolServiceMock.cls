/**
 * {@link Mock} implementation of {@link NearestSchoolService}.
 */
@IsTest
public class NearestSchoolServiceMock extends Mock implements NearestSchoolService {
  public final Method method = new Method();

  public NearestSchoolMatch findNearestSchoolForPoint(Decimal latitude, Decimal longitude) {
    return (NearestSchoolMatch) mockedCall(
      method.findNearestSchoolForPoint(),
      new Map<String, Object>{ 'latitude' => latitude, 'longitude' => longitude }
    );
  }

  public class Method {
    public String findNearestSchoolForPoint() {
      return new ExecutionInfo().getFullName();
    }
  }
}