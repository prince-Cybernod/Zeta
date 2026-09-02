/**
 * Runs {@link TriggerHandler}s from an {@link ApexTrigger}.
 */
public without sharing class TriggerHandlerRunner {
  @TestVisible
  private static TriggerHandlerProvider triggerHandlerProvider = new TriggerHandlerProviderImpl();

  /**
   * Runs {@link TriggerHandler}s according to the {@link TriggerOperation}.
   *
   * This is intended to be used directly from the {@link ApexTrigger}. For example:
   *
   * <pre>
   * trigger OpportunityTrigger on Opportunity(
   *   before insert,
   *   before update,
   *   before delete,
   *   after insert,
   *   after update,
   *   after delete,
   *   after undelete
   * ) {
   *   TriggerRunner.run(Trigger.new, Trigger.oldMap, Trigger.operationType);
   * }
   * </pre>
   */
  public static void run(
    List<SObject> sobjects,
    Map<Id, SObject> oldSObjectsByIds,
    TriggerOperation triggerOperation
  ) {
    SObjectType sobjectType = getSObjectType(sobjects, oldSObjectsByIds);
    Preconditions.checkArgument(
      sobjectType != null,
      String.format(
        String.join(
          new List<String>{
            'Expected to get the SObjectType from the records in the trigger, but got {0}.',
            'Trigger.new contained {1} records and Trigger.oldMap contained {2} records.'
          },
          ' '
        ),
        new List<Object>{ sobjectType, sobjects?.size(), oldSObjectsByIds?.size() }
      )
    );

    List<TriggerHandler> triggerHandlers = triggerHandlerProvider.get(sobjectType);
    for (TriggerHandler triggerHandler : triggerHandlers) {
      runTriggerHandler(triggerHandler, sobjects, oldSObjectsByIds, triggerOperation);
    }
  }

  private static SObjectType getSObjectType(
    List<SObject> sobjects,
    Map<Id, SObject> oldSObjectsByIds
  ) {
    if (sobjects != null && sobjects.size() > 0) {
      return sobjects[0].getSObjectType();
    } else if (oldSObjectsByIds != null && oldSObjectsByIds.size() > 0) {
      return oldSObjectsByIds.values()[0].getSObjectType();
    }

    return null;
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private static void runTriggerHandler(
    TriggerHandler triggerHandler,
    List<SObject> sobjects,
    Map<Id, SObject> oldSObjectsByIds,
    TriggerOperation triggerOperation
  ) {
    switch on triggerOperation {
      when BEFORE_INSERT {
        triggerHandler.onBeforeInsert(sobjects);
      }
      when BEFORE_UPDATE {
        triggerHandler.onBeforeUpdate(sobjects, oldSObjectsByIds);
      }
      when BEFORE_DELETE {
        triggerHandler.onBeforeDelete(oldSObjectsByIds.values());
      }
      when AFTER_INSERT {
        triggerHandler.onAfterInsert(sobjects);
      }
      when AFTER_UPDATE {
        triggerHandler.onAfterUpdate(sobjects, oldSObjectsByIds);
      }
      when AFTER_DELETE {
        triggerHandler.onAfterDelete(oldSObjectsByIds.values());
      }
      when AFTER_UNDELETE {
        triggerHandler.onAfterUndelete(sobjects);
      }
      when else {
        throw new IllegalArgumentException(
          String.format(
            'Attempted to run unexpected Trigger Operation: {0}',
            new List<Object>{ triggerOperation }
          )
        );
      }
    }
  }
}