/**
 * {@link Mock} implementation of {@link SiblingApplyingRollupService}.
 */
@IsTest
public class SiblingApplyingRollupServiceMock extends Mock implements SiblingApplyingRollupService {
  public final Method method = new Method();

  public void recalculate(Set<Id> individualApplicationIds) {
    mockedCall(
      method.recalculate(),
      new Map<String, Object>{ 'individualApplicationIds' => individualApplicationIds }
    );
  }

  public class Method {
    public String recalculate() {
      return new ExecutionInfo().getFullName();
    }
  }
}