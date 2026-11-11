/**
 * Mock implementation of {@link LastLeadAssignedService} for testing.
 */
@IsTest
public class LastLeadAssignedServiceMock extends Mock implements LastLeadAssignedService {
  public final Method method = new Method();

  public void stampLastLeadAssigned(Set<Id> userIds, Datetime assignedAt) {
    mockedCall(
      method.stampLastLeadAssigned(),
      new Map<String, Object>{ 'userIds' => userIds, 'assignedAt' => assignedAt }
    );
  }

  public class Method {
    public String stampLastLeadAssigned() {
      return new ExecutionInfo().getFullName();
    }
  }
}