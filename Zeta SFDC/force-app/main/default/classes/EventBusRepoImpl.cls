/**
 * Implementation of {@link EventBusRepo}.
 */
public with sharing class EventBusRepoImpl implements EventBusRepo {
  public Database.SaveResult publish(SObject event) {
    return EventBus.publish(event);
  }

  public List<Database.SaveResult> publish(List<SObject> events) {
    return EventBus.publish(events);
  }
}