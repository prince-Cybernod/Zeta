/**
 * Repository interface for EventBus operations.
 */
public interface EventBusRepo {
  /**
   * Publishes a single platform event.
   */
  Database.SaveResult publish(SObject event);

  /**
   * Publishes a list of platform events.
   */
  List<Database.SaveResult> publish(List<SObject> events);
}