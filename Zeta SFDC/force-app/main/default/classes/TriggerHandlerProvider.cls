/**
 * Provides implementations of {@link TriggerHandler}.
 */
public interface TriggerHandlerProvider {
  /**
   * Returns the {@link TriggerHandler}s for the given {@link SObjectType}.
   *
   * While it is a best practice to only have 1 {@link ApexTrigger} per object, it is possible to
   * have multiple so this class supports that.
   */
  List<TriggerHandler> get(SObjectType sobjectType);
}