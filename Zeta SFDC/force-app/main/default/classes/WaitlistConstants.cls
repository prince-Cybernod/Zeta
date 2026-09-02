/**
 * Constants for waitlist management.
 */
public with sharing class WaitlistConstants {
  public static final String STATUS_WAITLISTED {
    get {
      return 'Waitlisted';
    }
    private set;
  }

  public static final String STATUS_ELIGIBLE {
    get {
      return 'Eligible';
    }
    private set;
  }

  public static final String TRANSITION_REASON_WAITLIST_PROMOTION {
    get {
      return 'WAITLIST_PROMOTION';
    }
    private set;
  }

  public static final String TRANSITION_REASON_WAITLIST_OFFER_FINALIZED {
    get {
      return 'WAITLIST_OFFER_FINALIZED';
    }
    private set;
  }

  public static final List<SObjectField> HISTORY_TRACKED_FIELDS {
    get {
      return new List<SObjectField>{
        Schema.AcademicInterest.Status,
        Schema.AcademicInterest.Waitlist_Position__c,
        Schema.AcademicInterest.Current_Priority_Group__c
      };
    }
    private set;
  }
}