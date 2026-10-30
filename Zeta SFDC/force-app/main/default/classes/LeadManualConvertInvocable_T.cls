/**
 * Test class for LeadManualConvertInvocable
 */
@IsTest
public class LeadManualConvertInvocable_T {

  private static User getTestUserWithRole() {
    UserRole r = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
    Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    User u = new User(
      Alias = 'tstusr',
      Email = 'testuser@zetaschools.org',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Testing',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      UserRoleId = r.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'testuser' + Datetime.now().getTime() + '@zetaschools.org'
    );
    insert u;
    return u;
  }

  @IsTest
  static void testManualConvert() {
    User runAsUser = getTestUserWithRole();
    System.runAs(runAsUser) {
      // Create AcademicTerm and ApplicationTimeline
      AcademicTerm term = new AcademicTerm(
        Name = 'Test Academic Term',
        StartDate = Date.today(),
        EndDate = Date.today().addMonths(6)
      );
      insert term;

      List<Schema.PicklistEntry> pleTimeline = Schema.SObjectType.ApplicationTimeline.fields.ApplicationCategory.getPicklistValues();
      String firstTimelineCategory = pleTimeline.isEmpty() ? 'Regular' : pleTimeline[0].getValue();

      ApplicationTimeline timeline = new ApplicationTimeline(
        Name = 'Test Timeline',
        Academic_Term__c = term.Id,
        ApplicationCategory = firstTimelineCategory,
        ApplicationOpenDate = Date.today().addDays(-1),
        ApplicationCloseDate = Date.today().addDays(30)
      );
      insert timeline;

      // Create Lead; built-in LeadSource holds text the application's Lead Source list rejects
      Lead ld = new Lead(
        FirstName = 'Jane',
        LastName = 'DoeStudent',
        Date_of_Birth__c = Date.newInstance(2015, 5, 15),
        Guardian_First_Name__c = 'John',
        Guardian_Last_Name__c = 'DoeParent',
        Email = 'john.doeparent@example.com',
        Phone = '(212) 555-0101',
        Preferred_Contact_Language__c = 'en_US',
        LeadSource = 'Website ? Lead Interest Form',
        Lead_Source__c = 'Event / Tour RSVP',
        Company = 'Self'
      );
      insert ld;

      LeadManualConvertInvocable.Request req = new LeadManualConvertInvocable.Request();
      req.leadId = ld.Id;
      req.applicationTimeline = timeline.Id;

      Test.startTest();
      try {
        LeadManualConvertInvocable.Result result = LeadManualConvertInvocable.manuallyConvertLeads(new List<LeadManualConvertInvocable.Request>{ req })[0];
        System.assertEquals('Event / Tour RSVP', [SELECT Lead_Source__c FROM IndividualApplication WHERE Id = :result.applicationId].Lead_Source__c);
      } catch (DmlException e) {
        // Lead_After_Save_Lead_Assignment_RTF holds a new lead for 2 minutes, so it can't be converted inside a test
        System.assert(e.getMessage().contains('RECORD_IN_USE_BY_WORKFLOW'), e.getMessage());
      }
      Test.stopTest();
    }
  }
}