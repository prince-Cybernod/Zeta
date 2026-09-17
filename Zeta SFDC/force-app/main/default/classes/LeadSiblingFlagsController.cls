/** Household matches and explicit Lead comparison/merge actions. */
public with sharing class LeadSiblingFlagsController {
  private static final Integer RESULT_LIMIT = 500;
  private static final Set<String> MERGE_FIELDS = new Set<String>{
    'FirstName',
    'LastName',
    'Email',
    'Phone',
    'MobilePhone',
    'Guardian_First_Name__c',
    'Guardian_Last_Name__c',
    'Status'
  };

  /** Reads fresh comparison values and locks selected records for this transaction. */
  @AuraEnabled
  public static List<Lead> getLeadComparison(Id leadId, List<Id> selectedIds) {
    try {
      return new LeadMerge(leadId, selectedIds).records.values();
    } catch (AuraHandledException error) {
      throw error;
    } catch (Exception error) {
      throw handledError(
        'Unable to compare Leads. Check your access, then refresh.'
      );
    }
  }

  /** Merges only selected Leads, using values reread from approved source fields. */
  // Keep explicit LWC parameters instead of introducing a separate request DTO file.
  @SuppressWarnings('PMD.ExcessiveParameterList')
  @AuraEnabled
  public static Id mergeLeads(
    Id leadId,
    Id primaryId,
    List<Id> selectedIds,
    Map<String, Id> fieldSources,
    Map<Id, Datetime> versions
  ) {
    try {
      return new LeadMerge(leadId, selectedIds)
        .save(primaryId, fieldSources, versions);
    } catch (AuraHandledException error) {
      throw error;
    } catch (Exception error) {
      throw handledError(
        'Unable to merge Leads. No records were merged. Check your edit/delete access and record validation rules, then compare again.'
      );
    }
  }

  /** Keeps merge validation separate from household discovery without extra files. */
  private with sharing class LeadMerge {
    private Map<Id, Lead> records;

    private LeadMerge(Id leadId, List<Id> selectedIds) {
      Schema.DescribeSObjectResult leadInfo = Lead.SObjectType.getDescribe(
        SObjectDescribeOptions.DEFERRED
      );
      requireValid(
        leadInfo.isUpdateable() && leadInfo.isDeletable(),
        'You need edit and delete access to Leads to compare and merge.'
      );
      validateSelection(leadId, selectedIds);
      records = new Map<Id, Lead>(
        [
          SELECT
            Id,
            Name,
            FirstName,
            LastName,
            Email,
            Phone,
            MobilePhone,
            Guardian_First_Name__c,
            Guardian_Last_Name__c,
            Status,
            LastModifiedDate
          FROM Lead
          WHERE Id IN :selectedIds AND IsConverted = FALSE
          WITH USER_MODE
          FOR UPDATE
        ]
      );
      requireValid(
        records.size() == selectedIds.size(),
        'A selected Lead is unavailable or converted. Refresh and select again.'
      );
      validateContactMatches(leadId);
    }

    private void validateSelection(Id leadId, List<Id> selectedIds) {
      requireValid(
        selectedIds != null &&
          selectedIds.size() >= 2 &&
          selectedIds.size() <= 3,
        'Select two or three Leads.'
      );
      requireValid(
        new Set<Id>(selectedIds).size() == selectedIds.size() &&
        selectedIds.contains(leadId),
        'Select different Leads, including the current Lead.'
      );
      for (Id selectedId : selectedIds) {
        requireValid(
          selectedId != null && selectedId.getSObjectType() == Lead.SObjectType,
          'Only Lead records can be merged here.'
        );
      }
    }

    private void validateContactMatches(Id leadId) {
      Lead source = records.get(leadId);
      for (Lead record : records.values()) {
        Boolean sameEmail =
          String.isNotBlank(source.Email) &&
          source.Email.equalsIgnoreCase(record.Email);
        Boolean samePhone =
          String.isNotBlank(source.Phone) && source.Phone == record.Phone;
        requireValid(
          record.Id == leadId || sameEmail || samePhone,
          'Selected Leads no longer share the current Lead\'s phone or email. Refresh and select again.'
        );
      }
    }

    private Id save(
      Id primaryId,
      Map<String, Id> fieldSources,
      Map<Id, Datetime> versions
    ) {
      validateChoices(primaryId, fieldSources);
      for (Lead record : records.values()) {
        requireValid(
          versions != null &&
            versions.get(record.Id) == record.LastModifiedDate,
          'These Leads changed after comparison. Go back and compare again.'
        );
      }
      Lead survivor = new Lead(Id = primaryId);
      for (String field : MERGE_FIELDS) {
        Object chosenValue = records.get(fieldSources.get(field)).get(field);
        if (chosenValue != records.get(primaryId).get(field)) {
          survivor.put(field, chosenValue);
        }
      }
      Set<Id> duplicateIds = records.keySet().clone();
      duplicateIds.remove(primaryId);
      Database.merge(
        survivor,
        new List<Id>(duplicateIds),
        true,
        AccessLevel.USER_MODE
      );
      return primaryId;
    }

    private void validateChoices(Id primaryId, Map<String, Id> fieldSources) {
      requireValid(
        records.containsKey(primaryId),
        'Choose a selected Lead to keep.'
      );
      requireValid(
        fieldSources != null && fieldSources.keySet() == MERGE_FIELDS,
        'Choose a source for each comparison field.'
      );
      for (Id sourceId : fieldSources.values()) {
        requireValid(
          records.containsKey(sourceId),
          'Each field value must come from a selected Lead.'
        );
      }
    }

    private void requireValid(Boolean valid, String message) {
      if (!valid) {
        throw handledError(message);
      }
    }
  }

  /** Returns visible contact matches grouped as Leads, applicants, and enrolled students. */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getMatches(Id leadId) {
    if (leadId == null || leadId.getSObjectType() != Lead.SObjectType) {
      throw handledError(
        'Open a Lead record to check for siblings and duplicates.'
      );
    }
    try {
      return findMatches(leadId);
    } catch (Exception error) {
      throw handledError(
        'Unable to check siblings and duplicates. Check your access to Leads, Accounts, applications, and enrollments, then refresh.'
      );
    }
  }

  private static Map<String, Object> findMatches(Id leadId) {
    Lead source = [
      SELECT
        Id,
        Name,
        Email,
        Phone,
        Guardian_First_Name__c,
        Guardian_Last_Name__c,
        Status
      FROM Lead
      WHERE Id = :leadId
      WITH USER_MODE
    ];
    Set<String> emails = nonBlank(source.Email);
    Set<String> phones = nonBlank(source.Phone);
    Map<String, Object> result = new Map<String, Object>{
      'currentLead' => source,
      'leads' => new List<Lead>(),
      'applicants' => new List<Account>(),
      'enrolled' => new List<Account>(),
      'limited' => false
    };
    if (emails.isEmpty() && phones.isEmpty()) {
      return result;
    }

    Integer queryLimit = RESULT_LIMIT + 1;
    List<Lead> leads = [
      SELECT
        Id,
        Name,
        Phone,
        Email,
        Guardian_First_Name__c,
        Guardian_Last_Name__c,
        Status
      FROM Lead
      WHERE
        Id != :leadId
        AND IsConverted = FALSE
        AND (Email IN :emails
        OR Phone IN :phones)
      WITH USER_MODE
      ORDER BY Name, Id
      LIMIT :queryLimit
    ];
    trimResults(leads, result);
    result.put('leads', leads);

    Set<Id> phoneMatches = phones.isEmpty()
      ? new Set<Id>()
      : findPhoneMatches(leadId, result);

    // Requery candidates in user mode before using guardian IDs to expand a household.
    List<Account> contacts = [
      SELECT Id
      FROM Account
      WHERE
        IsPersonAccount = TRUE
        AND (Id IN :phoneMatches
        OR PersonEmail IN :emails
        OR Phone IN :phones
        OR PersonMobilePhone IN :phones)
      WITH USER_MODE
      ORDER BY Id
      LIMIT :queryLimit
    ];
    trimResults(contacts, result);
    Set<Id> contactIds = new Map<Id, Account>(contacts).keySet();
    result.put('contactIds', contactIds);
    if (contactIds.isEmpty()) {
      return result;
    }
    List<Account> students = [
      SELECT
        Id,
        Name,
        Phone,
        PersonMobilePhone,
        PersonEmail,
        RecordType.Name,
        Primary_Guardian__c,
        Secondary_Guardian__c,
        Primary_Guardian__r.Name,
        Primary_Guardian__r.Phone,
        Primary_Guardian__r.PersonMobilePhone,
        Primary_Guardian__r.PersonEmail,
        Secondary_Guardian__r.Name,
        Secondary_Guardian__r.Phone,
        Secondary_Guardian__r.PersonMobilePhone,
        Secondary_Guardian__r.PersonEmail,
        (
          SELECT Id, Status
          FROM IndividualApplicationAccount
          WHERE Application_Timeline__r.Active__c = TRUE
          ORDER BY CreatedDate DESC
          LIMIT 1
        ),
        (
          SELECT Id, EnrollmentStatus
          FROM AcademicTermEnrollments
          WHERE Active__c = TRUE
          ORDER BY CreatedDate DESC
          LIMIT 1
        )
      FROM Account
      WHERE
        IsPersonAccount = TRUE
        AND RecordType.DeveloperName = 'Student'
        AND (Id IN :contactIds
        OR Primary_Guardian__c IN :contactIds
        OR Secondary_Guardian__c IN :contactIds)
      WITH USER_MODE
      ORDER BY Name, Id
      LIMIT :queryLimit
    ];
    trimResults(students, result);
    for (Account student : students) {
      if (!student.AcademicTermEnrollments.isEmpty()) {
        ((List<Account>) result.get('enrolled')).add(student);
      } else if (!student.IndividualApplicationAccount.isEmpty()) {
        ((List<Account>) result.get('applicants')).add(student);
      }
    }
    return result;
  }

  // Salesforce supplies phone normalization; name/birthdate-only matches are excluded.
  private static Set<Id> findPhoneMatches(
    Id leadId,
    Map<String, Object> result
  ) {
    Set<Id> accountIds = new Set<Id>();
    Datacloud.FindDuplicatesResult found = Datacloud.FindDuplicatesByIds.findDuplicatesByIds(
      new List<Id>{ leadId }
    )[0];
    for (Datacloud.DuplicateResult duplicate : found.getDuplicateResults()) {
      if (duplicate.getDuplicateRule() != 'Guardian_Lead_Duplicate_Rule_v2') {
        continue;
      }
      for (Datacloud.MatchResult match : duplicate.getMatchResults()) {
        if (match.getEntityType() != 'Account') {
          continue;
        }
        if (match.getMatchRecords().size() >= 100) {
          result.put('limited', true);
        }
        for (Datacloud.MatchRecord record : match.getMatchRecords()) {
          accountIds.add((Id) record.getRecord().get('Id'));
        }
      }
    }
    return accountIds;
  }

  private static Set<String> nonBlank(String value) {
    return String.isBlank(value)
      ? new Set<String>()
      : new Set<String>{ value.trim() };
  }

  private static void trimResults(
    List<SObject> records,
    Map<String, Object> result
  ) {
    if (records.size() > RESULT_LIMIT) {
      records.remove(RESULT_LIMIT);
      result.put('limited', true);
    }
  }

  private static AuraHandledException handledError(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
