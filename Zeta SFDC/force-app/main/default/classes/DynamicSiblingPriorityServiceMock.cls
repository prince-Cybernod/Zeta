/**
 * {@link Mock} implementation of {@link DynamicSiblingPriorityService}.
 */
@IsTest
public class DynamicSiblingPriorityServiceMock extends Mock implements DynamicSiblingPriorityService {
  public final Method method = new Method();

  public void handleUpgrade(Set<Id> individualApplicationIds) {
    mockedCall(
      method.handleUpgrade(),
      new Map<String, Object>{ 'individualApplicationIds' => individualApplicationIds }
    );
  }

  public void handleDowngrade(Set<Id> individualApplicationIds) {
    mockedCall(
      method.handleDowngrade(),
      new Map<String, Object>{ 'individualApplicationIds' => individualApplicationIds }
    );
  }

  public class Method {
    public String handleUpgrade() {
      return new ExecutionInfo().getFullName();
    }

    public String handleDowngrade() {
      return new ExecutionInfo().getFullName();
    }
  }
}