/**
 * {@link ApexTrigger} that is run during {@link AcademicInterest} DML operations.
 */
trigger AcademicInterest on AcademicInterest(
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