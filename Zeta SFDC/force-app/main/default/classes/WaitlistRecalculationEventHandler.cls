/**
 * Trigger handler for Waitlist_Recalculation_Event__e platform events.
 * Extracts unique Lottery_Capacity__c IDs and optional seats overrides,
 * then enqueues async recalculation.
 */
public without sharing class WaitlistRecalculationEventHandler extends NoOpTriggerHandler {
  private final DatabaseRepo databaseRepo;

  @TestVisible
  private Boolean hasEnqueuedJob = false;

  public WaitlistRecalculationEventHandler() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private WaitlistRecalculationEventHandler(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public override SObjectType getSObjectType() {
    return Schema.Waitlist_Recalculation_Event__e.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    List<Waitlist_Recalculation_Event__e> events = (List<Waitlist_Recalculation_Event__e>) sobjects;
    Set<Id> capacityIds = new Set<Id>();
    Map<Id, Integer> seatsOverride = new Map<Id, Integer>();
    extractEventData(events, capacityIds, seatsOverride);

    if (!capacityIds.isEmpty()) {
      List<Lottery_Capacity__c> capsToUpdate = new List<Lottery_Capacity__c>();
      for (Id capId : capacityIds) {
        capsToUpdate.add(
          new Lottery_Capacity__c(
            Id = capId,
            Last_Recalculation_Status__c = 'Queued',
            Last_Recalculation_Date__c = Datetime.now(),
            Last_Recalculation_Error__c = null
          )
        );
      }
      databaseRepo.updateSObjects(capsToUpdate);

      hasEnqueuedJob = true;
      System.enqueueJob(new WaitlistRecalcQueueable(capacityIds, seatsOverride));
    }
  }

  private static void extractEventData(
    List<Waitlist_Recalculation_Event__e> events,
    Set<Id> capacityIds,
    Map<Id, Integer> seatsOverride
  ) {
    for (Waitlist_Recalculation_Event__e event : events) {
      if (String.isBlank(event.Lottery_Capacity_Id__c)) {
        continue;
      }
      Id capacityId;
      try {
        capacityId = Id.valueOf(event.Lottery_Capacity_Id__c);
      } catch (StringException e) {
        System.debug(
          LoggingLevel.WARN,
          'Invalid Lottery_Capacity_Id: ' + event.Lottery_Capacity_Id__c
        );
        continue;
      }
      capacityIds.add(capacityId);

      if (event.Seats_Override__c != null) {
        Integer seats = event.Seats_Override__c.intValue();
        if (!seatsOverride.containsKey(capacityId) || seats > seatsOverride.get(capacityId)) {
          seatsOverride.put(capacityId, seats);
        }
      }
    }
  }
}