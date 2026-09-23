/**
 * Mock implementation of {@link OpenLeadCountService} for testing.
 */
@IsTest
public class OpenLeadCountServiceMock extends Mock implements OpenLeadCountService {
  public final Method method = new Method();

  public void recalculateOpenLeadCount(Set<Id> userIds) {
    mockedCall(method.recalculateOpenLeadCount(), new Map<String, Object>{ 'userIds' => userIds });
  }

  public class Method {
    public String recalculateOpenLeadCount() {
      return new ExecutionInfo().getFullName();
    }
  }
}