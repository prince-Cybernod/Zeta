/**
 * Causes an {@link ApexTrigger} to run.
 *
 * This should be used to verify that our {@link TriggerHandler} is run when adding a new
 * {@link ApexTrigger}. Create an inner class in a test class and use it with {@link TriggerTest}.
 */
public abstract class TriggerTestRunner {
  /**
   * Inserts the {@link SObject}, which runs the {@link ApexTrigger}.
   *
   * For example, the following can be used to run the {@link Account} {@link ApexTrigger}.
   *
   * <pre>
   * private class AccountTriggerRunner extends TriggerRunner {
   *   private override void insertSObject() {
   *     insert as user new Account();
   *   }
   * }
   * </pre>
   */
  public abstract void insertSObject();
}