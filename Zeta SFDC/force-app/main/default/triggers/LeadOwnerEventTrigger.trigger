/**
 * {@link ApexTrigger} that is run during {@link Lead_Owner_Event__e} DML operations.
 */
trigger LeadOwnerEventTrigger on Lead_Owner_Event__e(after insert) {
  TriggerHandlerRunner.run(Trigger.new, Trigger.oldMap, Trigger.operationType);
}