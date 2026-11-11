/**
 * {@link Mock} implementation of {@link ActiveEnrollmentsRollupService}.
 */
@IsTest
public class ActiveEnrollmentsRollupServiceMock extends Mock implements ActiveEnrollmentsRollupService {
  public final Method method = new Method();

  public void recalculate(Set<Id> accountIds) {
    mockedCall(method.recalculate(), new Map<String, Object>{ 'accountIds' => accountIds });
  }

  public class Method {
    public String recalculate() {
      return new ExecutionInfo().getFullName();
    }
  }
}