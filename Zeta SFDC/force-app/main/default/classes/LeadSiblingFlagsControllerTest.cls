@IsTest
private class LeadSiblingFlagsControllerTest {
  private static Lead lead(String name, String email, String phone) {
    return new Lead(
      LastName = name,
      Company = 'Test household',
      Email = email,
      Phone = phone
    );
  }

  private static Account person(String name, String type, String email) {
    return new Account(
      FirstName = name,
      LastName = 'Sibling Test',
      PersonEmail = email,
      PersonBirthdate = Date.newInstance(2017, 1, 1),
      RecordTypeId = Account.SObjectType.getDescribe(
          SObjectDescribeOptions.DEFERRED
        )
        .getRecordTypeInfosByDeveloperName()
        .get(type)
        .getRecordTypeId()
    );
  }

  @IsTest
  static void matchesEmailOrPhoneAndExcludesCurrentLead() {
    List<Lead> leads = new List<Lead>{
      lead('Source', 'household@example.invalid', '2125550100'),
      lead('Email sibling', 'household@example.invalid', '2125550101'),
      lead('Phone sibling', 'other@example.invalid', '2125550100'),
      lead('Unrelated', 'unrelated@example.invalid', '2125550102')
    };
    insert leads;
    Test.startTest();
    Map<String, Object> result = LeadSiblingFlagsController.getMatches(
      leads[0].Id
    );
    Test.stopTest();
    Assert.areEqual(
      leads[0].Id,
      ((Lead) result.get('currentLead')).Id,
      'Return the current Lead separately for comparison, not as a duplicate.'
    );
    Set<Id> found = new Map<Id, Lead>((List<Lead>) result.get('leads'))
      .keySet();
    Assert.areEqual(
      new Set<Id>{ leads[1].Id, leads[2].Id },
      found,
      'Either contact field matches; the current Lead and unrelated Leads are excluded.'
    );
  }

  @IsTest
  static void blankPhoneDoesNotMatchOtherBlankPhones() {
    List<Lead> leads = new List<Lead>{
      lead('Source', 'one@example.invalid', null),
      lead('Unrelated', 'two@example.invalid', null)
    };
    insert leads;
    Test.startTest();
    Map<String, Object> result = LeadSiblingFlagsController.getMatches(
      leads[0].Id
    );
    Test.stopTest();
    Assert.areEqual(
      0,
      ((List<Lead>) result.get('leads')).size(),
      'Empty phone values must not create a household match.'
    );
  }

  @IsTest
  static void returnsTwoHundredRelatedLeadsWithBoundedQueries() {
    Lead source = lead('Source', 'large-family@example.invalid', null);
    insert source;
    List<Lead> siblings = new List<Lead>();
    for (Integer index = 0; index < 200; index++) {
      siblings.add(lead('Sibling ' + index, source.Email, null));
    }
    insert siblings;
    Test.startTest();
    Map<String, Object> result = LeadSiblingFlagsController.getMatches(
      source.Id
    );
    Integer queries = Limits.getQueries();
    Test.stopTest();
    Assert.areEqual(
      200,
      ((List<Lead>) result.get('leads')).size(),
      'Related Leads must not be limited to the duplicate API result size.'
    );
    Assert.isTrue(
      queries < 15,
      'Queries must not grow with the number of siblings.'
    );
  }

  @IsTest
  static void includesEveryApplicationStatusOnActiveTimelines() {
    insert new List<PartyRoleRelation>{
      new PartyRoleRelation(
        Name = 'Student-Guardian-CCR',
        RoleName = 'Student',
        RelatedRoleName = 'Guardian',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = false
      ),
      new PartyRoleRelation(
        Name = 'Guardian-Student-CCR',
        RoleName = 'Guardian',
        RelatedRoleName = 'Student',
        RelationshipObjectName = 'Contact_Contact_Relationship',
        ShouldCreaInversRoleAuto = false
      )
    };
    Lead source = lead('Source', 'family@example.invalid', '2125550110');
    insert source;
    Account guardian = person('Guardian', 'Guardian', source.Email);
    insert guardian;
    Account applicant = person('Applicant', 'Student', null);
    applicant.Primary_Guardian__c = guardian.Id;
    Account enrolled = person('Enrolled', 'Student', null);
    enrolled.Secondary_Guardian__c = guardian.Id;
    Account withdrawn = person('Withdrawn', 'Student', source.Email);
    Account noApplication = person('No application', 'Student', source.Email);
    Account inactiveTimelineApplicant = person(
      'Inactive timeline',
      'Student',
      source.Email
    );
    insert new List<Account>{
      applicant,
      enrolled,
      withdrawn,
      noApplication,
      inactiveTimelineApplicant
    };
    ApplicationTimeline timeline = new ApplicationTimeline(
      Name = 'Active sibling flags test',
      ApplicationOpenDate = Date.today().addDays(-1),
      ApplicationCloseDate = Date.today().addDays(1)
    );
    ApplicationTimeline inactiveTimeline = new ApplicationTimeline(
      Name = 'Inactive sibling flags test',
      ApplicationOpenDate = Date.today().addDays(-30),
      ApplicationCloseDate = Date.today().addDays(-1)
    );
    insert new List<ApplicationTimeline>{ timeline, inactiveTimeline };
    insert new List<IndividualApplication>{
      new IndividualApplication(
        AccountId = applicant.Id,
        Category = 'Education',
        Status = 'Applied',
        Application_Timeline__c = timeline.Id
      ),
      new IndividualApplication(
        AccountId = enrolled.Id,
        Category = 'Education',
        Status = 'Eligible',
        Application_Timeline__c = timeline.Id
      ),
      new IndividualApplication(
        AccountId = withdrawn.Id,
        Category = 'Education',
        Status = 'Withdrawn/Declined',
        Withdrawn_Declined_Reason_Picklist__c = 'Duplicate Application',
        Application_Timeline__c = timeline.Id
      ),
      new IndividualApplication(
        AccountId = inactiveTimelineApplicant.Id,
        Category = 'Education',
        Status = 'Applied',
        Application_Timeline__c = inactiveTimeline.Id
      )
    };
    AcademicTerm term = new AcademicTerm(
      Name = 'Current term',
      StartDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(30)
    );
    insert term;
    enrolled = [
      SELECT Id, PersonContactId
      FROM Account
      WHERE Id = :enrolled.Id
    ];
    insert new AcademicTermEnrollment(
      LearnerAccountId = enrolled.Id,
      LearnerContactId = enrolled.PersonContactId,
      AcademicTermId = term.Id,
      EnrollmentStatus = '1. Welcome Phase'
    );
    Test.startTest();
    Map<String, Object> result = LeadSiblingFlagsController.getMatches(
      source.Id
    );
    Test.stopTest();
    Assert.areEqual(
      new Set<Id>{ applicant.Id, withdrawn.Id },
      new Map<Id, Account>((List<Account>) result.get('applicants')).keySet(),
      'Every application status on an active timeline must qualify; Guardians and inactive timelines stay out.'
    );
    Assert.areEqual(
      'Student',
      ((List<Account>) result.get('applicants'))[0].RecordType.Name,
      'Account results must include the record type label for the LWC.'
    );
    Assert.areEqual(
      new Set<Id>{ enrolled.Id },
      new Map<Id, Account>((List<Account>) result.get('enrolled')).keySet(),
      'An active enrollment takes precedence over an application, including secondary guardians.'
    );
  }

  @IsTest
  static void rejectsInvalidRecordIds() {
    Test.startTest();
    for (Id invalidId : new List<Id>{ null, UserInfo.getUserId() }) {
      try {
        LeadSiblingFlagsController.getMatches(invalidId);
        Assert.fail('Only a Lead record ID can be inspected.');
      } catch (AuraHandledException error) {
        Assert.isTrue(
          error.getMessage().contains('Lead'),
          'Return a safe, useful error.'
        );
      }
    }
    Test.stopTest();
  }

  @IsTest
  static void mergesThreeLeadsWithChosenValues() {
    List<Lead> leads = new List<Lead>{
      lead('Current', 'merge@example.invalid', '2125550100'),
      lead('Keep', 'merge@example.invalid', '2125550101'),
      lead('Remove', 'merge@example.invalid', '2125550102')
    };
    insert leads;
    List<Id> ids = new List<Id>{ leads[0].Id, leads[1].Id, leads[2].Id };
    Test.startTest();
    List<Lead> comparison = LeadSiblingFlagsController.getLeadComparison(
      leads[0].Id,
      ids
    );
    Map<String, Id> choices = mergeChoices(leads[1].Id);
    choices.put('Phone', leads[2].Id);
    Id keptId = LeadSiblingFlagsController.mergeLeads(
      leads[0].Id,
      leads[1].Id,
      ids,
      choices,
      versions(comparison)
    );
    Test.stopTest();
    Assert.areEqual(leads[1].Id, keptId, 'Keep the selected primary Lead.');
    Assert.areEqual(
      '2125550102',
      [SELECT Phone FROM Lead WHERE Id = :keptId].Phone,
      'Keep the selected field value.'
    );
    List<Lead> removed = [
      SELECT Id, IsDeleted, MasterRecordId
      FROM Lead
      WHERE Id IN :ids AND Id != :keptId
      ALL ROWS
    ];
    Assert.areEqual(
      2,
      removed.size(),
      'Both selected duplicates are included.'
    );
    for (Lead record : removed) {
      Assert.isTrue(record.IsDeleted, 'Duplicate records are merged.');
      Assert.areEqual(
        keptId,
        record.MasterRecordId,
        'Both duplicates point to the survivor.'
      );
    }
  }

  @IsTest
  static void rejectsStaleComparisonAndUnapprovedFields() {
    List<Lead> leads = new List<Lead>{
      lead('Keep', 'stale@example.invalid', null),
      lead('Duplicate', 'stale@example.invalid', null)
    };
    insert leads;
    List<Id> ids = new List<Id>{ leads[0].Id, leads[1].Id };
    List<Lead> comparison = LeadSiblingFlagsController.getLeadComparison(
      leads[0].Id,
      ids
    );
    Map<Id, Datetime> stale = versions(comparison);
    stale.put(leads[0].Id, stale.get(leads[0].Id).addSeconds(-1));
    Test.startTest();
    try {
      LeadSiblingFlagsController.mergeLeads(
        leads[0].Id,
        leads[0].Id,
        ids,
        mergeChoices(leads[0].Id),
        stale
      );
      Assert.fail('A stale comparison must be rejected.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('changed'),
        'Explain that records changed.'
      );
    }
    Map<String, Id> choices = mergeChoices(leads[0].Id);
    choices.put('OwnerId', leads[1].Id);
    try {
      LeadSiblingFlagsController.mergeLeads(
        leads[0].Id,
        leads[0].Id,
        ids,
        choices,
        versions(comparison)
      );
      Assert.fail('Unapproved fields must be rejected.');
    } catch (AuraHandledException error) {
      Assert.isTrue(
        error.getMessage().contains('field'),
        'Explain invalid field choices.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Lead WHERE Id IN :ids],
      'Failed requests must leave both Leads intact.'
    );
  }

  @IsTest
  static void rejectsUnrelatedAndInvalidSelections() {
    List<Lead> leads = new List<Lead>{
      lead('Current', 'current@example.invalid', null),
      lead('Unrelated', 'other@example.invalid', null)
    };
    insert leads;
    Test.startTest();
    for (
      List<Id> ids : new List<List<Id>>{
        null,
        new List<Id>{ leads[0].Id },
        new List<Id>{ leads[0].Id, leads[0].Id },
        new List<Id>{ leads[0].Id, UserInfo.getUserId() },
        new List<Id>{ leads[0].Id, leads[1].Id }
      }
    ) {
      try {
        LeadSiblingFlagsController.getLeadComparison(leads[0].Id, ids);
        Assert.fail('Invalid or unrelated selections must be rejected.');
      } catch (AuraHandledException error) {
        Assert.isNotNull(error.getMessage(), 'Return a handled explanation.');
      }
    }
    Test.stopTest();
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Lead WHERE Id IN :leads],
      'Comparison must never modify records.'
    );
  }

  private static Map<String, Id> mergeChoices(Id primaryId) {
    Map<String, Id> choices = new Map<String, Id>();
    for (
      String field : new List<String>{
        'FirstName',
        'LastName',
        'Email',
        'Phone',
        'MobilePhone',
        'Guardian_First_Name__c',
        'Guardian_Last_Name__c',
        'Status'
      }
    ) {
      choices.put(field, primaryId);
    }
    return choices;
  }

  private static Map<Id, Datetime> versions(List<Lead> leads) {
    Map<Id, Datetime> result = new Map<Id, Datetime>();
    for (Lead record : leads) {
      result.put(record.Id, record.LastModifiedDate);
    }
    return result;
  }

  @IsTest
  static void refusesAUserWithoutLeadReadAccess() {
    Profile minimumProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    User restrictedUser = new User(
      ProfileId = minimumProfile.Id,
      Username = 'siblings.' +
        UserInfo.getOrganizationId() +
        '@example.invalid',
      Email = 'siblings@example.invalid',
      LastName = 'Restricted',
      Alias = 'siblings',
      TimeZoneSidKey = 'America/New_York',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert restrictedUser;
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Lead source = lead('Private', 'private@example.invalid', null);
      insert source;
      Lead duplicate = lead('Private duplicate', source.Email, null);
      insert duplicate;
      System.runAs(restrictedUser) {
        Test.startTest();
        try {
          LeadSiblingFlagsController.getMatches(source.Id);
          Assert.fail(
            'A user without Lead read access must not receive household data.'
          );
        } catch (AuraHandledException error) {
          Assert.isTrue(
            error.getMessage().contains('access'),
            'Access errors must be handled.'
          );
        }
        try {
          LeadSiblingFlagsController.mergeLeads(
            source.Id,
            source.Id,
            new List<Id>{ source.Id, duplicate.Id },
            mergeChoices(source.Id),
            new Map<Id, Datetime>()
          );
          Assert.fail('A restricted user must not merge Leads.');
        } catch (AuraHandledException error) {
          Assert.isTrue(
            error.getMessage().contains('access'),
            'Merge must enforce access.'
          );
        }
        Test.stopTest();
      }
    }
  }
}
