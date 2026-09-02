/**
 * {@link ApexTrigger} that is run during {@link Priority_Item__c} DML operations.
 */
trigger PriorityItem on Priority_Item__c(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete,
  after undelete
) {
  TriggerHandlerRunner.run(Trigger.new, Trigger.oldMap, Trigger.operationType);
}