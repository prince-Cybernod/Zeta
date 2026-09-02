/**
 * Constants for lottery management.
 */
public with sharing class LotteryConstants {
  public static final String STATUS_ELIGIBLE {
    get {
      return 'Eligible';
    }
    private set;
  }

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

  public static final String STATUS_WAITLISTED {
    get {
      return 'Waitlisted';
    }
    private set;
  }

  public static final String STATUS_RESCINDED_OPTIMIZATION {
    get {
      return 'Offer Rescinded due to Seat Optimization';
    }
    private set;
  }

  public static final String STATUS_RESCINDED {
    get {
      return 'Rescinded';
    }
    private set;
  }

  public static final String LOTTERY_RUN_STATUS_DRAFT {
    get {
      return 'Not Published';
    }
    private set;
  }

  public static final String LOTTERY_RUN_STATUS_PUBLISHED {
    get {
      return 'Published';
    }
    private set;
  }

  public static final Integer OFFER_EXPIRATION_DAYS {
    get {
      return 14;
    }
    private set;
  }

  public static final String TRANSITION_REASON_LOTTERY_OFFER {
    get {
      return 'LOTTERY_OFFER';
    }
    private set;
  }

  public static final String TRANSITION_REASON_SEAT_OPTIMIZATION {
    get {
      return 'SEAT_OPTIMIZATION';
    }
    private set;
  }

  public static final String TRANSITION_REASON_NO_SEATS {
    get {
      return 'NO_SEATS_AVAILABLE';
    }
    private set;
  }

  public static final String STATUS_WITHDRAWN_DECLINED {
    get {
      return 'Withdrawn/Declined';
    }
    private set;
  }

  public static final String TRANSITION_REASON_SEAT_OFFER_WITHDRAWAL {
    get {
      return 'SEAT_OFFER_WITHDRAWAL';
    }
    private set;
  }

  public static final String WITHDRAWN_REASON_SEAT_OFFER {
    get {
      return 'Withdrawn due to Seat Offer';
    }
    private set;
  }
}