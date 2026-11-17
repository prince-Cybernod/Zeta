/**
 * {@link Mock} implementation of {@link StaffPriorityCapKeySource}.
 */
@IsTest
public class StaffPriorityCapKeySourceMock extends Mock implements StaffPriorityCapKeySource {
  public final Method method = new Method();

  public Decimal nextKey() {
    return (Decimal) mockedCall(method.nextKey(), new Map<String, Object>());
  }

  public class Method {
    public String nextKey() {
      return new ExecutionInfo().getFullName();
    }
  }
}