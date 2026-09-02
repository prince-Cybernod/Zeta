/**
 * Implementation of {@link TriggerHandler} that does nothing.
 *
 * This is useful for creating {@link TriggerHandler}s that only need to act on specific DML
 * operations and otherwise do nothing. It allows the user to only {@code override} the methods it
 * cares about.
 */
public abstract with sharing class NoOpTriggerHandler implements TriggerHandler {
  /**
   * Returns the {@link SObjectType} that this handler is responsible for.
   */
  public abstract SObjectType getSObjectType();

  public virtual void onBeforeInsert(List<SObject> sobjects) {
  }

  public virtual void onBeforeUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
  }

  public virtual void onBeforeDelete(List<SObject> sobjects) {
  }

  public virtual void onAfterInsert(List<SObject> sobjects) {
  }

  public virtual void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
  }

  public virtual void onAfterDelete(List<SObject> oldSObjects) {
  }

  public virtual void onAfterUndelete(List<SObject> sobjects) {
  }
}