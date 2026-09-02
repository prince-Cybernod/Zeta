/**
 * {@link ApexTrigger} that is run during {@link IndividualApplication} DML operations.
 */
trigger IndividualApplication on IndividualApplication(
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