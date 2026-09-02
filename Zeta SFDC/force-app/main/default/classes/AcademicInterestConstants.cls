/**
 * Constants for working with {@link AcademicInterest}.
 */
public with sharing class AcademicInterestConstants {
  // Status values
  public static final String STATUS_PRE_OFFER {
    get {
      return 'Pre-Offer';
    }
    private set;
  }

  public static final String STATUS_SEAT_OFFERED {
    get {
      return 'Seat Offered';
    }
    private set;
  }

  public static final String STATUS_SEAT_ACCEPTED {
    get {
      return 'Seat Accepted';
    }
    private set;
  }

  public static final String STATUS_RESCINDED {
    get {
      return 'Rescinded';
    }
    private set;
  }

  public static final String STATUS_WITHDRAWN_DECLINED {
    get {
      return 'Withdrawn/Declined';
    }
    private set;
  }
}