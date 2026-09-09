/**
 * {@link ApexTrigger} that is run during {@link Lead} DML operations.
 */
trigger Lead on Lead(
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