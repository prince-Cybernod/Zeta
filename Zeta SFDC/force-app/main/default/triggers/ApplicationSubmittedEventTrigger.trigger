/**
 * {@link ApexTrigger} that is run during {@link Application_Submitted_Event__e} DML operations.
 */
trigger ApplicationSubmittedEventTrigger on Application_Submitted_Event__e(after insert) {
  TriggerHandlerRunner.run(Trigger.new, Trigger.oldMap, Trigger.operationType);
}