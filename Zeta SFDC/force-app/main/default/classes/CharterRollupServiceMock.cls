/**
 * {@link Mock} implementation of {@link CharterRollupService}.
 */
@IsTest
public class CharterRollupServiceMock extends Mock implements CharterRollupService {
  public final Method method = new Method();

  public void recalculate(Set<Id> charterAccountIds) {
    mockedCall(
      method.recalculate(),
      new Map<String, Object>{ 'charterAccountIds' => charterAccountIds }
    );
  }

  public class Method {
    public String recalculate() {
      return new ExecutionInfo().getFullName();
    }
  }
}