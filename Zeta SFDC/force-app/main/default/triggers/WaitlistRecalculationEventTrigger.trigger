/**
 * {@link ApexTrigger} that is run during {@link Waitlist_Recalculation_Event__e} DML operations.
 */
trigger WaitlistRecalculationEventTrigger on Waitlist_Recalculation_Event__e(after insert) {
  TriggerHandlerRunner.run(Trigger.new, Trigger.oldMap, Trigger.operationType);
}