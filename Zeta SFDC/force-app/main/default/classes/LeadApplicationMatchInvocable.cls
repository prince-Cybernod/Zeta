/**
 * Invocable Action for automatically matching and converting leads on application creation
 */
public without sharing class LeadApplicationMatchInvocable {

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
    public Id applicationId;
  }

  public class Result {
    @InvocableVariable
    public Id matchedLeadId;

    @InvocableVariable
    public Boolean isConverted;
  }

  @InvocableMethod(
    Label='Match and Convert Lead on Application Submit' 
    Description='Automatically detects and self-converts matching leads when an application is submitted'
  )
  public static List<Result> matchAndConvertLeads(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: No requests provided.');
      return new List<Result>();
    }

    System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Processing ' + requests.size() + ' requests.');
    List<Result> results = new List<Result>();

    Set<Id> appIds = new Set<Id>();
    for (Request req : requests) {
      if (req.applicationId != null) {
        System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Adding applicationId = ' + req.applicationId);
        appIds.add(req.applicationId);
      }
    }

    if (appIds.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: No valid applicationIds found.');
      for (Integer i = 0; i < requests.size(); i++) {
        results.add(new Result());
      }
      return results;
    }

    List<IndividualApplication> apps = [
      SELECT Id, AccountId, Primary_Guardian__c, Secondary_Guardian__c,
             Lead_Source__c, Campaign__c, Conversion_Type__c,
             Lead_First_Contact_Date__c, Converting_Team_Member__c
      FROM IndividualApplication
      WHERE Id IN :appIds
    ];
    System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Queried ' + apps.size() + ' IndividualApplications.');

    Set<Id> studentAccountIds = new Set<Id>();
    for (IndividualApplication app : apps) {
      if (app.AccountId != null) {
        studentAccountIds.add(app.AccountId);
      }
    }

    Map<Id, Account> studentAccounts = new Map<Id, Account>([
      SELECT Id, FirstName, LastName, PersonBirthdate, PersonContactId,
             Primary_Guardian__c, Secondary_Guardian__c
      FROM Account
      WHERE Id IN :studentAccountIds
    ]);
    System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Found ' + studentAccounts.size() + ' student Accounts.');

    Set<Id> guardianAccountIds = new Set<Id>();
    for (Account student : studentAccounts.values()) {
      if (student.Primary_Guardian__c != null) {
        guardianAccountIds.add(student.Primary_Guardian__c);
      }
    }

    Map<Id, Account> guardianAccounts = new Map<Id, Account>([
      SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Phone, Language_Preference__pc
      FROM Account
      WHERE Id IN :guardianAccountIds
    ]);
    System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Found ' + guardianAccounts.size() + ' guardian Accounts.');

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
    List<IndividualApplication> appsToUpdate = new List<IndividualApplication>();

    // First pass to find matching leads and get campaign mapping in bulk
    Set<Id> matchedLeadIds = new Set<Id>();
    for (IndividualApplication app : apps) {
      Account studentAcc = studentAccounts.get(app.AccountId);
      if (studentAcc == null) {
        continue;
      }
      Account guardianAcc = (studentAcc.Primary_Guardian__c != null) ? guardianAccounts.get(studentAcc.Primary_Guardian__c) : null;
      List<Lead> matchingLeads = findMatchingLeads(studentAcc, guardianAcc);
      if (!matchingLeads.isEmpty()) {
        matchedLeadIds.add(matchingLeads[0].Id);
      }
    }
    Map<Id, Id> leadToCampaign = getLeadCampaignIds(matchedLeadIds);
    System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Bulk Campaign map populated for leadIds: ' + leadToCampaign.keySet());

    Map<Id, Result> appToResult = new Map<Id, Result>();
    for (IndividualApplication app : apps) {
      Result res = new Result();
      res.isConverted = false;
      appToResult.put(app.Id, res);
    }

    for (IndividualApplication app : apps) {
      Result res = appToResult.get(app.Id);

      Account studentAcc = studentAccounts.get(app.AccountId);
      if (studentAcc == null) {
        continue;
      }

      Account guardianAcc = (studentAcc.Primary_Guardian__c != null) ? guardianAccounts.get(studentAcc.Primary_Guardian__c) : null;
      List<Lead> matchingLeads = findMatchingLeads(studentAcc, guardianAcc);
      if (matchingLeads.isEmpty()) {
        continue;
      }

      Lead matchedLead = matchingLeads[0];
      res.matchedLeadId = matchedLead.Id;
      res.isConverted = true;

      // Prepare Lead owner update to remove it from queues
      matchedLead.OwnerId = UserInfo.getUserId();
      leadsToUpdate.add(matchedLead);

      // Construct standard Lead Convert
      Database.LeadConvert lc = new Database.LeadConvert();
      lc.setLeadId(matchedLead.Id);
      lc.setAccountId(studentAcc.Id);
      if (studentAcc.PersonContactId != null) {
        lc.setContactId(studentAcc.PersonContactId);
      }
      lc.setConvertedStatus(convertedStatusValue);
      lc.setDoNotCreateOpportunity(true);
      leadConverts.add(lc);

      // Handle Guardian matching and updates
      Id finalGuardianId = null;
      if (String.isNotBlank(matchedLead.Guardian_First_Name__c) && String.isNotBlank(matchedLead.Guardian_Last_Name__c)) {
        Account matchedGuardian = findOrCreateGuardian(matchedLead);
        finalGuardianId = matchedGuardian.Id;

        // Set preference language only when blank
        if (String.isBlank(matchedGuardian.Language_Preference__pc) && String.isNotBlank(matchedLead.Preferred_Contact_Language__c)) {
          matchedGuardian.Language_Preference__pc = matchedLead.Preferred_Contact_Language__c;
          accountsToUpdate.add(matchedGuardian);
          System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Set Guardian Language Preference to: ' + matchedLead.Preferred_Contact_Language__c);
        }
      }

      // Check Primary/Secondary Guardian relationships
      Boolean studentUpdated = false;
      if (finalGuardianId != null) {
        if (studentAcc.Primary_Guardian__c == null) {
          studentAcc.Primary_Guardian__c = finalGuardianId;
          studentUpdated = true;
          System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Setting Primary Guardian on Student Account: ' + finalGuardianId);
        } else if (studentAcc.Primary_Guardian__c != finalGuardianId) {
          studentAcc.Secondary_Guardian__c = finalGuardianId;
          studentUpdated = true;
          System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Setting Secondary Guardian on Student Account: ' + finalGuardianId);
        }
      }

      if (studentUpdated) {
        accountsToUpdate.add(studentAcc);
      }

      // Update IndividualApplication fields
      if (String.isNotBlank(matchedLead.LeadSource)) {
        app.Lead_Source__c = matchedLead.LeadSource;
      }
      Id campaignId = leadToCampaign.get(matchedLead.Id);
      if (campaignId != null) {
        app.Campaign__c = campaignId;
      }
      app.Conversion_Type__c = 'Self-Converted (No Team Call)';
      app.Converting_Team_Member__c = UserInfo.getUserId();
      app.Lead_First_Contact_Date__c = matchedLead.CreatedDate;
      appsToUpdate.add(app);
    }

    if (!leadsToUpdate.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Updating ' + leadsToUpdate.size() + ' Leads to change Owner to current user.');
      update leadsToUpdate;
    }

    if (!leadConverts.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Executing Lead Convert for ' + leadConverts.size() + ' leads.');
      Database.convertLead(leadConverts);
    }

    if (!accountsToUpdate.isEmpty()) {
      // Deduplicate accounts to update
      Map<Id, Account> accMap = new Map<Id, Account>();
      for (Account a : accountsToUpdate) {
        accMap.put(a.Id, a);
      }
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Updating ' + accMap.size() + ' Accounts (Student/Guardian).');
      update accMap.values();
    }

    if (!appsToUpdate.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.matchAndConvertLeads: Updating ' + appsToUpdate.size() + ' IndividualApplications with conversion metrics.');
      update appsToUpdate;
    }

    for (Request req : requests) {
      Result res = appToResult.get(req.applicationId);
      if (res != null) {
        results.add(res);
      } else {
        results.add(new Result());
      }
    }

    return results;
  }

  private static List<Lead> findMatchingLeads(Account studentAcc, Account guardianAcc) {
    System.debug('LeadApplicationMatchInvocable.findMatchingLeads: Searching matching leads for Student Account FirstName = ' + studentAcc.FirstName + ', LastName = ' + studentAcc.LastName);
    Set<Id> leadIds = new Set<Id>();
    List<SObject> prototypes = new List<SObject>();
    if (studentAcc != null) {
      prototypes.add(studentAcc);
    }
    if (guardianAcc != null) {
      prototypes.add(guardianAcc);
    }

    try {
      List<Datacloud.FindDuplicatesResult> dupResults = Datacloud.FindDuplicates.findDuplicates(prototypes);
      for (Datacloud.FindDuplicatesResult res : dupResults) {
        for (Datacloud.DuplicateResult dupRes : res.getDuplicateResults()) {
          for (Datacloud.MatchResult matchRes : dupRes.getMatchResults()) {
            for (Datacloud.MatchRecord matchRec : matchRes.getMatchRecords()) {
              SObject matchedRecord = matchRec.getRecord();
              if (matchedRecord.getSObjectType() == Lead.SObjectType) {
                System.debug('LeadApplicationMatchInvocable.findMatchingLeads: Datacloud Duplicate rule matched Lead ID: ' + matchedRecord.Id);
                leadIds.add(matchedRecord.Id);
              }
            }
          }
        }
      }
    } catch (Exception e) {
      System.debug('LeadApplicationMatchInvocable.findMatchingLeads: Exception during findDuplicates: ' + e.getMessage());
    }

    // Direct fallback query to guarantee matching
    if (studentAcc != null) {
      String sFirst = studentAcc.FirstName;
      String sLast = studentAcc.LastName;
      Date sDob = studentAcc.PersonBirthdate;
      List<Lead> nameMatches = [
        SELECT Id, FirstName, LastName, Date_of_Birth__c, Email, Phone, Preferred_Contact_Language__c, LeadSource, CreatedDate, OwnerId, Guardian_First_Name__c, Guardian_Last_Name__c
        FROM Lead
        WHERE IsConverted = false 
          AND FirstName = :sFirst 
          AND LastName = :sLast
      ];
      for (Lead l : nameMatches) {
        Boolean sDobMatch = (sDob == null || l.Date_of_Birth__c == sDob);
        if (sDobMatch) {
          if (guardianAcc != null) {
            Boolean emailMatch = (String.isNotBlank(l.Email) && l.Email.equalsIgnoreCase(guardianAcc.PersonEmail));
            String cleanedLeadPhone = (l.Phone != null) ? l.Phone.replaceAll('[^0-9]', '') : '';
            String cleanedGPhone = (guardianAcc.PersonMobilePhone != null) ? guardianAcc.PersonMobilePhone.replaceAll('[^0-9]', '') : '';
            String cleanedGHome = (guardianAcc.Phone != null) ? guardianAcc.Phone.replaceAll('[^0-9]', '') : '';
            Boolean phoneMatch = (String.isNotBlank(cleanedLeadPhone) && (cleanedLeadPhone == cleanedGPhone || cleanedLeadPhone == cleanedGHome));
            if (emailMatch || phoneMatch) {
              System.debug('LeadApplicationMatchInvocable.findMatchingLeads: Fallback matched on Email or Phone. Lead ID: ' + l.Id);
              leadIds.add(l.Id);
            }
          } else {
            System.debug('LeadApplicationMatchInvocable.findMatchingLeads: Fallback matched Student Name & DOB. Lead ID: ' + l.Id);
            leadIds.add(l.Id);
          }
        }
      }
    }

    if (leadIds.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.findMatchingLeads: No matching leads found.');
      return new List<Lead>();
    }

    return [
      SELECT Id, FirstName, LastName, Date_of_Birth__c, Email, Phone, 
             Preferred_Contact_Language__c, LeadSource, CreatedDate, OwnerId,
             Guardian_First_Name__c, Guardian_Last_Name__c
      FROM Lead
      WHERE Id IN :leadIds AND IsConverted = false
    ];
  }

  private static Account findOrCreateGuardian(Lead l) {
    String gFirst = l.Guardian_First_Name__c;
    String gLast = l.Guardian_Last_Name__c;
    String email = l.Email;
    String phone = l.Phone;
    System.debug('LeadApplicationMatchInvocable.findOrCreateGuardian: Looking for Guardian: ' + gFirst + ' ' + gLast);

    List<Account> existingGuardians = [
      SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Phone, Language_Preference__pc
      FROM Account
      WHERE RecordTypeId = :ACCOUNT_TYPE_GUARDIAN
        AND FirstName = :gFirst
        AND LastName = :gLast
        AND (PersonEmail = :email OR PersonMobilePhone = :phone OR Phone = :phone)
      LIMIT 1
    ];

    if (!existingGuardians.isEmpty()) {
      System.debug('LeadApplicationMatchInvocable.findOrCreateGuardian: Existing Guardian Account found. ID: ' + existingGuardians[0].Id);
      return existingGuardians[0];
    }

    System.debug('LeadApplicationMatchInvocable.findOrCreateGuardian: No existing Guardian Account found. Creating new Guardian Account.');
    Account newGuardian = new Account(
      FirstName = gFirst,
      LastName = gLast,
      PersonEmail = email,
      PersonMobilePhone = phone,
      Phone = phone,
      RecordTypeId = ACCOUNT_TYPE_GUARDIAN
    );
    insert newGuardian;
    System.debug('LeadApplicationMatchInvocable.findOrCreateGuardian: Created new Guardian Account. ID: ' + newGuardian.Id);

    return [
      SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone, Phone, Language_Preference__pc
      FROM Account
      WHERE Id = :newGuardian.Id
    ];
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
    return leadToCampaign;
  }

}