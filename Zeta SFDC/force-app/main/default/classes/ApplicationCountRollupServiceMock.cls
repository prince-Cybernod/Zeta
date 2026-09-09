/**
 * {@link Mock} implementation of {@link ApplicationCountRollupService}.
 */
@IsTest
public class ApplicationCountRollupServiceMock extends Mock implements ApplicationCountRollupService {
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