/**
 * {@link ApexTrigger} that is run during {@link AcademicTermEnrollment} DML operations.
 */
trigger AcademicTermEnrollment on AcademicTermEnrollment(
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