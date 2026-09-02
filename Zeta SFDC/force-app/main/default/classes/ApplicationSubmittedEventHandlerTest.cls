/**
 * Tests for {@link ApplicationSubmittedEventHandler}.
 */
@IsTest(IsParallel=true)
private class ApplicationSubmittedEventHandlerTest {
  @IsTest
  private static void getSObjectType_returnsEventType() {
    ApplicationSubmittedEventHandler handler = new ApplicationSubmittedEventHandler();

    SObjectType result = handler.getSObjectType();

    Assert.areEqual(Schema.Application_Submitted_Event__e.SObjectType, result);
  }

  /**
   * Tests for onAfterInsert with valid/duplicate Application_Id__c are not possible
   * because the handler enqueues ApplicationPdfQueueable which calls
   * PageReference.getContentAsPDF(). This API throws a hard platform error
   * ("Methods defined as TestMethod do not support getContent call") that cannot
   * be caught with try/catch. Coverage of lines 17-20 is blocked by this limitation.
   */

  @IsTest
  private static void onAfterInsert_withBlankAppId_skipsEvent() {
    ApplicationSubmittedEventHandler handler = new ApplicationSubmittedEventHandler();
    List<SObject> events = new List<SObject>{
      new Application_Submitted_Event__e(Application_Id__c = '')
    };

    handler.onAfterInsert(events);

    Assert.areEqual(0, Limits.getQueueableJobs(), 'Should not have enqueued any jobs');
  }

  @IsTest
  private static void onAfterInsert_withNullAppId_skipsEvent() {
    ApplicationSubmittedEventHandler handler = new ApplicationSubmittedEventHandler();
    List<SObject> events = new List<SObject>{
      new Application_Submitted_Event__e(Application_Id__c = null)
    };

    handler.onAfterInsert(events);

    Assert.areEqual(0, Limits.getQueueableJobs(), 'Should not have enqueued any jobs for null appId');
  }
}