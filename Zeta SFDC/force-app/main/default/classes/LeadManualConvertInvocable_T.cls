/**
 * Test class for LeadManualConvertInvocable
 */
@isTest
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
      UserName = 'testuser' + DateTime.now().getTime() + '@zetaschools.org'
    );
    insert u;

    try {
      PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Zeta_Enrollment_Education_Cloud_Limited' LIMIT 1];
      insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    } catch (Exception e) {
      System.debug('Could not assign permission set: ' + e.getMessage());
    }

    return u;
  }

  @isTest
  static void testCCRInsertion() {
    User runAsUser = getTestUserWithRole();
    System.runAs(runAsUser) {
      Contact c1 = new Contact(FirstName = 'Test1', LastName = 'Contact1');
      insert c1;
      Contact c2 = new Contact(FirstName = 'Test2', LastName = 'Contact2');
      insert c2;

      PartyRoleRelation prr = [SELECT Id FROM PartyRoleRelation WHERE Name = 'Student-Guardian-CCR' LIMIT 1];

      ContactContactRelation ccr = new ContactContactRelation(
        ContactId = c1.Id,
        RelatedContactId = c2.Id,
        PartyRoleRelationId = prr.Id
      );
      insert ccr;
    }
  }

  @isTest
  static void testManualConvert() {
    User runAsUser = getTestUserWithRole();
    System.runAs(runAsUser) {
      AcademicTerm term = new AcademicTerm(
        Name = 'Test Academic Term 2',
        StartDate = Date.today(),
        EndDate = Date.today().addMonths(6)
      );
      insert term;

      List<Schema.PicklistEntry> pleTimeline = Schema.SObjectType.ApplicationTimeline.fields.ApplicationCategory.getPicklistValues();
      String firstTimelineCategory = pleTimeline.isEmpty() ? 'Regular' : pleTimeline[0].getValue();

      ApplicationTimeline timeline = new ApplicationTimeline(
        Name = 'Test Timeline 2',
        Academic_Term__c = term.Id,
        ApplicationCategory = firstTimelineCategory,
        ApplicationOpenDate = Date.today().addDays(-1),
        ApplicationCloseDate = Date.today().addDays(30)
      );
      insert timeline;

      Campaign camp = new Campaign(Name = 'Manual Campaign', IsActive = true);
      insert camp;

      List<Schema.PicklistEntry> pleLeadSource = Schema.SObjectType.IndividualApplication.fields.Lead_Source__c.getPicklistValues();
      String firstLeadSourceValue = pleLeadSource.isEmpty() ? 'Other' : pleLeadSource[0].getValue();

      Lead ld = new Lead(
        FirstName = 'Robert',
        LastName = 'SmithStudent',
        Date_of_Birth__c = Date.newInstance(2014, 8, 20),
        Guardian_First_Name__c = 'Alice',
        Guardian_Last_Name__c = 'SmithParent',
        Email = 'alice.smith@test.com',
        Phone = '5559876543',
        Preferred_Contact_Language__c = 'English',
        LeadSource = firstLeadSourceValue,
        Company = 'Self'
      );
      insert ld;

      CampaignMember cm = new CampaignMember(LeadId = ld.Id, CampaignId = camp.Id);
      insert cm;

      Test.startTest();
      LeadManualConvertInvocable.Request req = new LeadManualConvertInvocable.Request();
      req.leadId = ld.Id;
      req.applicationTimeline = timeline.Id;
      List<LeadManualConvertInvocable.Result> results = LeadManualConvertInvocable.manuallyConvertLeads(new List<LeadManualConvertInvocable.Request>{ req });
      Test.stopTest();

      System.assertEquals(1, results.size(), 'Should return 1 result');
      System.assertNotEquals(null, results[0].studentAccountId, 'studentAccountId should be returned');
      System.assertNotEquals(null, results[0].guardianAccountId, 'guardianAccountId should be returned');
      System.assertNotEquals(null, results[0].applicationId, 'applicationId should be returned');

      // Verify lead is converted
      Lead updatedLead = [SELECT Id, IsConverted, ConvertedAccountId FROM Lead WHERE Id = :ld.Id];
      System.assertEquals(true, updatedLead.IsConverted, 'Lead should be converted');
      System.assertEquals(results[0].studentAccountId, updatedLead.ConvertedAccountId, 'studentAccountId in result should match converted account');

      // Verify Student and Guardian Accounts exist and are linked
      Account student = [SELECT Id, FirstName, LastName, PersonBirthdate, Primary_Guardian__c FROM Account WHERE Id = :updatedLead.ConvertedAccountId];
      System.assertEquals('Robert', student.FirstName);
      System.assertEquals('SmithStudent', student.LastName);
      System.assertEquals(Date.newInstance(2014, 8, 20), student.PersonBirthdate);

      Account guardian = [SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Language_Preference__pc FROM Account WHERE Id = :student.Primary_Guardian__c];
      System.assertEquals('Alice', guardian.FirstName);
      System.assertEquals('SmithParent', guardian.LastName);
      System.assertEquals('alice.smith@test.com', guardian.PersonEmail);
      System.assertEquals('English', guardian.Language_Preference__pc);

      // Verify Application is created
      IndividualApplication app = [
        SELECT Id, AccountId, Primary_Guardian__c, Status, Lead_Source__c, Campaign__c, Conversion_Type__c, Application_Timeline__c 
        FROM IndividualApplication 
        WHERE AccountId = :student.Id
      ];
      System.assertEquals(guardian.Id, app.Primary_Guardian__c);
      System.assertEquals('Draft', app.Status);
      System.assertEquals(firstLeadSourceValue, app.Lead_Source__c);
      System.assertEquals(camp.Id, app.Campaign__c);
      System.assertEquals('Team-Assisted Conversion', app.Conversion_Type__c);
      System.assertEquals(timeline.Id, app.Application_Timeline__c);
    }
  }

}