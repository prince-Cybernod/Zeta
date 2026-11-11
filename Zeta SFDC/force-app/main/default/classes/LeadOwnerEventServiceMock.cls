/**
 * Mock implementation of {@link LeadOwnerEventService} for testing.
 */
@IsTest
public class LeadOwnerEventServiceMock extends Mock implements LeadOwnerEventService {
  public final Method method = new Method();

  public void publishLeadOwnerEvents(
    Set<Id> ownerIdsToRecount,
    Set<Id> newlyAssignedOwnerIds,
    Datetime assignedAt
  ) {
    mockedCall(
      method.publishLeadOwnerEvents(),
      new Map<String, Object>{
        'ownerIdsToRecount' => ownerIdsToRecount,
        'newlyAssignedOwnerIds' => newlyAssignedOwnerIds,
        'assignedAt' => assignedAt
      }
    );
  }

  public class Method {
    public String publishLeadOwnerEvents() {
      return new ExecutionInfo().getFullName();
    }
  }
}