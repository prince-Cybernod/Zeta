/**
 * Invocable Action for manually converting leads during a call
 */
public without sharing class LeadManualConvertInvocable {

  private static final Id ACCOUNT_TYPE_GUARDIAN = [
    SELECT Id 
    FROM RecordType 
    WHERE SObjectType = 'Account' AND DeveloperName = 'Guardian' 
    LIMIT 1
  ].Id;

  private static final Id ACCOUNT_TYPE_STUDENT = [
    SELECT Id 
    FROM RecordType 
    WHERE SObjectType = 'Account' AND DeveloperName = 'Student' 
    LIMIT 1
  ].Id;

  public class Request {
    @InvocableVariable(Required=true)
    public Id leadId;

    @InvocableVariable
    public String applicationTimeline;
  }

  public class Result {
    @InvocableVariable
    public Id studentAccountId;

    @InvocableVariable
    public Id guardianAccountId;

    @InvocableVariable
    public Id applicationId;
  }

  @InvocableMethod(
    Label='Manually Convert Lead' 
    Description='Converts a lead manually into student and guardian person accounts and creates an IndividualApplication'
  )
  public static List<Result> manuallyConvertLeads(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: No requests provided.');
      return new List<Result>();
    }

    System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Processing ' + requests.size() + ' requests.');
    List<Result> results = new List<Result>();

    Set<Id> leadIds = new Set<Id>();
    for (Request req : requests) {
      if (req.leadId != null) {
        System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Request with leadId = ' + req.leadId + ', applicationTimeline = ' + req.applicationTimeline);
        leadIds.add(req.leadId);
      }
    }

    if (leadIds.isEmpty()) {
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: No valid leadIds found in requests.');
      for (Integer i = 0; i < requests.size(); i++) {
        results.add(new Result());
      }
      return results;
    }

    List<Lead> leads = [
      SELECT Id, FirstName, LastName, Date_of_Birth__c, Email, Phone, 
             Preferred_Contact_Language__c, LeadSource, CreatedDate, OwnerId,
             Guardian_First_Name__c, Guardian_Last_Name__c
      FROM Lead
      WHERE Id IN :leadIds
    ];
    System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Queried ' + leads.size() + ' Leads.');

    Map<Id, Id> leadToCampaign = getLeadCampaignIds(leadIds);

    LeadStatus convertStatus = [
      SELECT Id, MasterLabel 
      FROM LeadStatus 
      WHERE IsConverted = true 
      LIMIT 1
    ];
    String convertedStatusValue = convertStatus.MasterLabel;

    List<Lead> leadsToUpdate = new List<Lead>();
    List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
    List<Account> accountsToUpdate = new List<Account>();
    List<IndividualApplication> appsToInsert = new List<IndividualApplication>();

    List<Schema.PicklistEntry> pleApp = Schema.SObjectType.IndividualApplication.fields.Category.getPicklistValues();
    String appCategory = pleApp.isEmpty() ? 'Admissions' : pleApp[0].getValue();

    Map<Id, Result> studentAccToResult = new Map<Id, Result>();

    for (Request req : requests) {
      Lead l = null;
      for (Lead candidate : leads) {
        if (candidate.Id == req.leadId) {
          l = candidate;
          break;
        }
      }

      if (l == null) {
        System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Lead not found in queried list for ID: ' + req.leadId);
        continue;
      }

      // 1. Find or create Guardian Account
      Account guardianAcc = findOrCreateGuardian(l);
      Result res = new Result();
      res.guardianAccountId = guardianAcc.Id;

      // Set preferred language only when blank
      if (String.isBlank(guardianAcc.Language_Preference__pc) && String.isNotBlank(l.Preferred_Contact_Language__c)) {
        guardianAcc.Language_Preference__pc = l.Preferred_Contact_Language__c;
        accountsToUpdate.add(guardianAcc);
        System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Set Guardian Language Preference to: ' + l.Preferred_Contact_Language__c);
      }

      // 2. Find or create Student Account
      Account studentAcc = findOrCreateStudent(l);
      res.studentAccountId = studentAcc.Id;
      studentAccToResult.put(studentAcc.Id, res);

      // 3. Link Student and Guardian Accounts
      Boolean studentUpdated = false;
      if (studentAcc.Primary_Guardian__c == null) {
        studentAcc.Primary_Guardian__c = guardianAcc.Id;
        studentUpdated = true;
        System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Linking Guardian ' + guardianAcc.Id + ' as Primary Guardian on Student Account.');
      } else if (studentAcc.Primary_Guardian__c != guardianAcc.Id) {
        studentAcc.Secondary_Guardian__c = guardianAcc.Id;
        studentUpdated = true;
        System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Linking Guardian ' + guardianAcc.Id + ' as Secondary Guardian on Student Account.');
      }

      if (studentUpdated) {
        accountsToUpdate.add(studentAcc);
      }

      // 4. Update Lead owner to running user
      l.OwnerId = UserInfo.getUserId();
      leadsToUpdate.add(l);

      // 5. Prepare standard Lead Convert
      Database.LeadConvert lc = new Database.LeadConvert();
      lc.setLeadId(l.Id);
      lc.setAccountId(studentAcc.Id);
      if (studentAcc.PersonContactId != null) {
        lc.setContactId(studentAcc.PersonContactId);
      }
      lc.setConvertedStatus(convertedStatusValue);
      lc.setDoNotCreateOpportunity(true);
      leadConverts.add(lc);

      // 6. Create IndividualApplication
      IndividualApplication app = new IndividualApplication(
        Application_Timeline__c = req.applicationTimeline,
        AccountId = studentAcc.Id,
        Primary_Guardian__c = guardianAcc.Id,
        Secondary_Guardian__c = (studentAcc.Secondary_Guardian__c == guardianAcc.Id) ? guardianAcc.Id : null,
        Status = 'Draft',
        Category = appCategory,
        SubmittedByContactId = guardianAcc.PersonContactId,
        Lead_Source__c = l.LeadSource,
        Campaign__c = leadToCampaign.get(l.Id),
        Conversion_Type__c = 'Team-Assisted Conversion',
        Lead_First_Contact_Date__c = l.CreatedDate,
        Converting_Team_Member__c = UserInfo.getUserId(),
        Created_through_Manual_Lead_Conversion__c = true
      );
      appsToInsert.add(app);
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Prepared IndividualApplication for Student Account ID: ' + studentAcc.Id);
    }

    if (!leadsToUpdate.isEmpty()) {
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Updating ' + leadsToUpdate.size() + ' Leads to change Owner to current user.');
      update leadsToUpdate;
    }

    if (!leadConverts.isEmpty()) {
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Executing Lead Convert for ' + leadConverts.size() + ' leads.');
      Database.convertLead(leadConverts);
    }

    if (!accountsToUpdate.isEmpty()) {
      Map<Id, Account> accMap = new Map<Id, Account>();
      for (Account a : accountsToUpdate) {
        accMap.put(a.Id, a);
      }
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Updating ' + accMap.size() + ' Accounts (Student/Guardian).');
      update accMap.values();
    }

    if (!appsToInsert.isEmpty()) {
      System.debug('LeadManualConvertInvocable.manuallyConvertLeads: Inserting ' + appsToInsert.size() + ' IndividualApplications.');
      insert appsToInsert;
      for (IndividualApplication app : appsToInsert) {
        Result res = studentAccToResult.get(app.AccountId);
        if (res != null) {
          res.applicationId = app.Id;
        }
      }
    }

    for (Request req : requests) {
      Lead matchedLead = null;
      for (Lead candidate : leads) {
        if (candidate.Id == req.leadId) {
          matchedLead = candidate;
          break;
        }
      }

      if (matchedLead != null) {
        Id studentId = findOrCreateStudent(matchedLead).Id;
        results.add(studentAccToResult.get(studentId));
      } else {
        results.add(new Result());
      }
    }

    return results;
  }

  private static Map<Id, Id> getLeadCampaignIds(Set<Id> leadIds) {
    Map<Id, Id> leadToCampaign = new Map<Id, Id>();
    for (CampaignMember cm : [
      SELECT LeadId, CampaignId 
      FROM CampaignMember 
      WHERE LeadId IN :leadIds
    ]) {
      leadToCampaign.put(cm.LeadId, cm.CampaignId);
    }
    System.debug('LeadManualConvertInvocable: Bulk Campaign map populated: ' + leadToCampaign);
    return leadToCampaign;
  }

  private static Account findOrCreateGuardian(Lead l) {
    String gFirst = l.Guardian_First_Name__c;
    String gLast = l.Guardian_Last_Name__c;
    String email = l.Email;
    String phone = l.Phone;
    System.debug('LeadManualConvertInvocable.findOrCreateGuardian: Looking for Guardian: ' + gFirst + ' ' + gLast);

    List<Account> existingGuardians = [
      SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Phone, Language_Preference__pc, PersonContactId
      FROM Account
      WHERE RecordTypeId = :ACCOUNT_TYPE_GUARDIAN
        AND FirstName = :gFirst
        AND LastName = :gLast
        AND (PersonEmail = :email OR PersonMobilePhone = :phone OR Phone = :phone)
      LIMIT 1
    ];

    if (!existingGuardians.isEmpty()) {
      System.debug('LeadManualConvertInvocable.findOrCreateGuardian: Existing Guardian Account found. ID: ' + existingGuardians[0].Id);
      return existingGuardians[0];
    }

    System.debug('LeadManualConvertInvocable.findOrCreateGuardian: No existing Guardian Account found. Creating new Guardian Account.');
    Account newGuardian = new Account(
      FirstName = gFirst,
      LastName = gLast,
      PersonEmail = email,
      PersonMobilePhone = phone,
      Phone = phone,
      RecordTypeId = ACCOUNT_TYPE_GUARDIAN
    );
    insert newGuardian;
    System.debug('LeadManualConvertInvocable.findOrCreateGuardian: Created new Guardian Account. ID: ' + newGuardian.Id);

    return [
      SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Phone, Language_Preference__pc, PersonContactId
      FROM Account
      WHERE Id = :newGuardian.Id
    ];
  }

  private static Account findOrCreateStudent(Lead l) {
    String sFirst = l.FirstName;
    String sLast = l.LastName;
    Date dob = l.Date_of_Birth__c;
    System.debug('LeadManualConvertInvocable.findOrCreateStudent: Looking for Student: ' + sFirst + ' ' + sLast + ', DOB: ' + dob);

    List<Account> existingStudents = [
      SELECT Id, FirstName, LastName, PersonBirthdate, Primary_Guardian__c, Secondary_Guardian__c, PersonContactId
      FROM Account
      WHERE RecordTypeId = :ACCOUNT_TYPE_STUDENT
        AND FirstName = :sFirst
        AND LastName = :sLast
        AND PersonBirthdate = :dob
      LIMIT 1
    ];

    if (!existingStudents.isEmpty()) {
      System.debug('LeadManualConvertInvocable.findOrCreateStudent: Existing Student Account found. ID: ' + existingStudents[0].Id);
      return existingStudents[0];
    }

    System.debug('LeadManualConvertInvocable.findOrCreateStudent: No existing Student Account found. Creating new Student Account.');
    Account newStudent = new Account(
      FirstName = sFirst,
      LastName = sLast,
      PersonBirthdate = dob,
      RecordTypeId = ACCOUNT_TYPE_STUDENT
    );
    insert newStudent;
    System.debug('LeadManualConvertInvocable.findOrCreateStudent: Created new Student Account. ID: ' + newStudent.Id);

    return [
      SELECT Id, FirstName, LastName, PersonBirthdate, Primary_Guardian__c, Secondary_Guardian__c, PersonContactId
      FROM Account
      WHERE Id = :newStudent.Id
    ];
  }

}