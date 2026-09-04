/**
 * Test class for LeadApplicationMatchInvocable
 */
@isTest
public class LeadApplicationMatchInvocable_T {

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
    return u;
  }

  @isTest
  static void testAutomatedMatchOnSubmit() {
    User runAsUser = getTestUserWithRole();
    System.runAs(runAsUser) {
      List<PartyRoleRelation> prrs = new List<PartyRoleRelation>();
      prrs.add(new PartyRoleRelation(
        Name = 'Student-Guardian-CCR',
        RoleName = 'Student',
        RelatedRoleName = 'Guardian',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = true
      ));
      prrs.add(new PartyRoleRelation(
        Name = 'Guardian-Student-CCR',
        RoleName = 'Guardian',
        RelatedRoleName = 'Student',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = true
      ));
      prrs.add(new PartyRoleRelation(
        Name = 'Student-Primary Guardian-CCR',
        RoleName = 'Student',
        RelatedRoleName = 'Primary Guardian',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = true
      ));
      prrs.add(new PartyRoleRelation(
        Name = 'Primary Guardian-Student-CCR',
        RoleName = 'Primary Guardian',
        RelatedRoleName = 'Student',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = true
      ));
      insert prrs;

      Id guardianRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Guardian' LIMIT 1].Id;
      Id studentRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Student' LIMIT 1].Id;

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

      // Create Guardian Person Account
      Account guardian = new Account(
        FirstName = 'John',
        LastName = 'DoeParent',
        RecordTypeId = guardianRT,
        PersonEmail = 'john.doe@test.com',
        PersonMobilePhone = '5551234567',
        Phone = '5551234567'
      );
      insert guardian;

      // Create Student Person Account
      Account student = new Account(
        FirstName = 'Jane',
        LastName = 'DoeStudent',
        RecordTypeId = studentRT,
        PersonBirthdate = Date.newInstance(2015, 5, 15)
      );
      insert student;

      List<Schema.PicklistEntry> pleLeadSource = Schema.SObjectType.IndividualApplication.fields.Lead_Source__c.getPicklistValues();
      String firstLeadSourceValue = pleLeadSource.isEmpty() ? 'Other' : pleLeadSource[0].getValue();

      // Create Lead matching the student and guardian details
      Lead ld = new Lead(
        FirstName = 'Jane',
        LastName = 'DoeStudent',
        Date_of_Birth__c = Date.newInstance(2015, 5, 15),
        Guardian_First_Name__c = 'John',
        Guardian_Last_Name__c = 'DoeParent',
        Email = 'john.doe@test.com',
        Phone = '5551234567',
        Preferred_Contact_Language__c = 'Spanish',
        LeadSource = firstLeadSourceValue,
        Company = 'Self'
      );
      insert ld;

      Campaign camp = new Campaign(Name = 'Test Campaign', IsActive = true);
      insert camp;

      CampaignMember cm = new CampaignMember(LeadId = ld.Id, CampaignId = camp.Id);
      insert cm;

      List<Schema.PicklistEntry> pleApp = Schema.SObjectType.IndividualApplication.fields.Category.getPicklistValues();
      String firstAppCategory = pleApp.isEmpty() ? 'Admissions' : pleApp[0].getValue();

      // Retrieve PersonContactId for Guardian Account
      Account queriedGuardian = [SELECT PersonContactId FROM Account WHERE Id = :guardian.Id];

      // Create Individual Application
      IndividualApplication app = new IndividualApplication(
        AccountId = student.Id,
        Application_Timeline__c = timeline.Id,
        Category = firstAppCategory,
        Primary_Guardian__c = guardian.Id,
        SubmittedByContactId = queriedGuardian.PersonContactId
      );
      insert app;

      Test.startTest();
      LeadApplicationMatchInvocable.Request req = new LeadApplicationMatchInvocable.Request();
      req.applicationId = app.Id;
      List<LeadApplicationMatchInvocable.Result> results = LeadApplicationMatchInvocable.matchAndConvertLeads(new List<LeadApplicationMatchInvocable.Request>{ req });
      Test.stopTest();

      System.assertEquals(1, results.size(), 'Should return 1 result');
      System.assertEquals(ld.Id, results[0].matchedLeadId, 'matchedLeadId should be returned');
      System.assertEquals(true, results[0].isConverted, 'isConverted should be true');

      // Verify lead is converted
      Lead updatedLead = [SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId FROM Lead WHERE Id = :ld.Id];
      System.assertEquals(true, updatedLead.IsConverted, 'Lead should be converted');
      System.assertEquals(student.Id, updatedLead.ConvertedAccountId, 'Lead should be converted into Student Account');

      // Verify Student Account links to Guardian
      Account updatedStudent = [SELECT Id, Primary_Guardian__c, Secondary_Guardian__c FROM Account WHERE Id = :student.Id];
      System.assertEquals(guardian.Id, updatedStudent.Primary_Guardian__c, 'Student should be linked to the matching guardian');

      // Verify Guardian Account Preferred Language
      Account updatedGuardian = [SELECT Id, Language_Preference__pc FROM Account WHERE Id = :guardian.Id];
      System.assertEquals('English', updatedGuardian.Language_Preference__pc, 'Guardian preferred language should be set or remain defaulted');

      // Verify Application fields
      IndividualApplication updatedApp = [
        SELECT Id, Lead_Source__c, Campaign__c, Conversion_Type__c, Converting_Team_Member__c 
        FROM IndividualApplication 
        WHERE Id = :app.Id
      ];
      System.assertEquals(firstLeadSourceValue, updatedApp.Lead_Source__c);
      System.assertEquals(camp.Id, updatedApp.Campaign__c);
      System.assertEquals('Self-Converted (No Team Call)', updatedApp.Conversion_Type__c);
      System.assertEquals(UserInfo.getUserId(), updatedApp.Converting_Team_Member__c);
    }
  }

}