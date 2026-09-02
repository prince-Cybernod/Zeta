/**
 * Trigger handler for Application_Submitted_Event__e platform events.
 * Enqueues PDF generation for each submitted application.
 */
public without sharing class ApplicationSubmittedEventHandler extends NoOpTriggerHandler {
  public override SObjectType getSObjectType() {
    return Schema.Application_Submitted_Event__e.SObjectType;
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    List<Application_Submitted_Event__e> events = (List<Application_Submitted_Event__e>) sobjects;
    Set<String> processedIds = new Set<String>();

    for (Application_Submitted_Event__e event : events) {
      String appId = event.Application_Id__c;
      if (String.isBlank(appId) || processedIds.contains(appId)) {
        continue;
      }
      processedIds.add(appId);
      System.enqueueJob(new ApplicationPdfQueueable(Id.valueOf(appId)));
    }
  }
}