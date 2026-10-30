/**
 * {@link Mock} implementation of {@link ContactApplicationRollupService}.
 */
@IsTest
public class ContactApplicationRollupServiceMock extends Mock implements ContactApplicationRollupService {
  public final Method method = new Method();

  public void recalculate(Set<Id> personAccountIds) {
    mockedCall(
      method.recalculate(),
      new Map<String, Object>{ 'personAccountIds' => personAccountIds }
    );
  }

  public class Method {
    public String recalculate() {
      return new ExecutionInfo().getFullName();
    }
  }
}