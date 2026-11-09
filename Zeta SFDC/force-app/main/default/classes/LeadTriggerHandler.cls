/**
 * {@link TriggerHandler} that handles {@link Lead} DML operations.
 *
 * Publishes a {@link Lead_Owner_Event__e} for every User owner who may need their
 * User.Open_Lead_Count__c recalculated, across insert, update, delete, and undelete. On insert
 * and on an OwnerId change to a User, the event also carries the assignment time so the
 * subscriber can stamp User.Last_Lead_Assigned__c. Queue owners are ignored.
 *
 * Before insert and update, sets Lead.Next_Follow_Up_Due__c (Next Follow-Up Due) from the
 * Enrollment Hours working days (weekends and holidays are days off).
 */
public with sharing class LeadTriggerHandler extends NoOpTriggerHandler {
  // Queried once per transaction, even when Enrollment Hours is missing
  private static Boolean enrollmentHoursLoaded = false;
  private static BusinessHours enrollmentHours {
    get {
      if (!enrollmentHoursLoaded) {
        List<BusinessHours> found = [
          SELECT Id, TimeZoneSidKey
          FROM BusinessHours
          WHERE Name = 'Enrollment Hours' AND IsActive = TRUE
          LIMIT 1
        ];
        enrollmentHours = found.isEmpty() ? null : found[0];
        enrollmentHoursLoaded = true;
      }
      return enrollmentHours;
    }
    set;
  }

  private final LeadOwnerEventService leadOwnerEventService;

  public LeadTriggerHandler() {
    this(new LeadOwnerEventServiceImpl());
  }

  @TestVisible
  private LeadTriggerHandler(LeadOwnerEventService leadOwnerEventService) {
    this.leadOwnerEventService = leadOwnerEventService;
  }

  public override SObjectType getSObjectType() {
    return Schema.Lead.SObjectType;
  }

  public override void onBeforeInsert(List<SObject> sobjects) {
    Datetime now = System.now();
    for (Lead lead : (List<Lead>) sobjects) {
      // CreatedDate is set here only when a data load keeps the original date
      setNextFollowUpDue(lead, lead.CreatedDate != null ? lead.CreatedDate : now);
    }
  }

  public override void onBeforeUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    for (Lead lead : (List<Lead>) sobjects) {
      Lead oldLead = (Lead) oldSObjectsByIds.get(lead.Id);
      Boolean changed =
        lead.Status != oldLead.Status ||
        lead.Outreach_Attempt_1__c != oldLead.Outreach_Attempt_1__c ||
        lead.Outreach_Attempt_2__c != oldLead.Outreach_Attempt_2__c ||
        lead.Outreach_Attempt_3__c != oldLead.Outreach_Attempt_3__c;
      // A blank due date also fills leads saved before this logic existed
      if (changed || lead.Next_Follow_Up_Due__c == null) {
        setNextFollowUpDue(lead, lead.CreatedDate);
      }
    }
  }

  public override void onAfterInsert(List<SObject> sobjects) {
    Datetime assignedAt = System.now();
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, userIds, assignedAt);
  }

  public override void onAfterUpdate(List<SObject> sobjects, Map<Id, SObject> oldSObjectsByIds) {
    Datetime assignedAt = System.now();
    Set<Id> newlyAssignedUserIds = new Set<Id>();
    Set<Id> ownerUserIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      Lead oldLead = (Lead) oldSObjectsByIds.get(lead.Id);
      if (lead.OwnerId != oldLead.OwnerId && isUserId(lead.OwnerId)) {
        newlyAssignedUserIds.add(lead.OwnerId);
      }
      if (isUserId(oldLead.OwnerId)) {
        ownerUserIds.add(oldLead.OwnerId);
      }
      if (isUserId(lead.OwnerId)) {
        ownerUserIds.add(lead.OwnerId);
      }
    }

    publishIfAny(ownerUserIds, newlyAssignedUserIds, assignedAt);
  }

  public override void onAfterDelete(List<SObject> oldSObjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) oldSObjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, new Set<Id>(), null);
  }

  public override void onAfterUndelete(List<SObject> sobjects) {
    Set<Id> userIds = new Set<Id>();

    for (Lead lead : (List<Lead>) sobjects) {
      if (isUserId(lead.OwnerId)) {
        userIds.add(lead.OwnerId);
      }
    }

    publishIfAny(userIds, new Set<Id>(), null);
  }

  private void publishIfAny(
    Set<Id> ownerIdsToRecount,
    Set<Id> newlyAssignedOwnerIds,
    Datetime assignedAt
  ) {
    if (!ownerIdsToRecount.isEmpty()) {
      leadOwnerEventService.publishLeadOwnerEvents(
        ownerIdsToRecount,
        newlyAssignedOwnerIds,
        assignedAt
      );
    }
  }

  private static Boolean isUserId(Id ownerId) {
    return ownerId != null && ownerId.getSObjectType() == Schema.User.SObjectType;
  }

  /**
   * Due at the end of a working day. New Lead: the next working day. Attempt 1: 2 days later.
   * Attempt 2: 7 days later. A day off moves to the next working day. Blank when closed or after Attempt 3.
   */
  private static void setNextFollowUpDue(Lead lead, Datetime createdAt) {
    Boolean isClosed = lead.Status != null && !lead.Status.containsIgnoreCase('open');
    if (isClosed || lead.Outreach_Attempt_3__c != null || enrollmentHours == null) {
      lead.Next_Follow_Up_Due__c = null;
      return;
    }

    Datetime dueDay;
    if (lead.Outreach_Attempt_2__c != null) {
      dueDay = lead.Outreach_Attempt_2__c.addDays(7);
    } else if (lead.Outreach_Attempt_1__c != null) {
      dueDay = lead.Outreach_Attempt_1__c.addDays(2);
    } else {
      dueDay = createdAt.addDays(1);
    }
    lead.Next_Follow_Up_Due__c = endOfWorkingDay(dueDay);
  }

  // Closing time of the first working day on or after the given day
  private static Datetime endOfWorkingDay(Datetime day) {
    Datetime opens = BusinessHours.nextStartDate(enrollmentHours.Id, startOfDay(day));
    Datetime nextOpens = BusinessHours.nextStartDate(enrollmentHours.Id, startOfDay(opens.addDays(1)));
    Long openMillis = BusinessHours.diff(enrollmentHours.Id, opens, nextOpens);
    return opens.addSeconds((Integer) (openMillis / 1000));
  }

  private static Datetime startOfDay(Datetime moment) {
    String tz = enrollmentHours.TimeZoneSidKey;
    Integer secondsIntoDay =
      Integer.valueOf(moment.format('H', tz)) * 3600 +
      Integer.valueOf(moment.format('m', tz)) * 60 +
      Integer.valueOf(moment.format('s', tz));
    return moment.addSeconds(-secondsIntoDay);
  }
}