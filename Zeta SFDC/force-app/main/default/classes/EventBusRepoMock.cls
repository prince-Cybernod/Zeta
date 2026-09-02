/**
 * {@link Mock} implementation of {@link EventBusRepo}.
 */
@IsTest
public with sharing class EventBusRepoMock extends Mock implements EventBusRepo {
  public final Method method = new Method();

  public Database.SaveResult publish(SObject event) {
    return (Database.SaveResult) mockedCall(
      method.publishSingle(),
      new Map<String, Object>{ 'event' => event }
    );
  }

  public List<Database.SaveResult> publish(List<SObject> events) {
    return (List<Database.SaveResult>) mockedCall(
      method.publishList(),
      new Map<String, Object>{ 'events' => events }
    );
  }

  public class Method {
    public String publishSingle() {
      return new ExecutionInfo().getFullName();
    }
    public String publishList() {
      return new ExecutionInfo().getFullName();
    }
  }
}