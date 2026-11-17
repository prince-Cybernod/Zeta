/**
 * {@link ApexTrigger} that is run during {@link LearningProgram} DML operations.
 */
trigger LearningProgram on LearningProgram(
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