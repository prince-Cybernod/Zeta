/**
 * Constants for working with {@link Priority_Item__c}.
 */
public with sharing class PriorityItemConstants {
  public static final String PRIORITY_TYPE_SIBLING_APPLYING {
    get {
      return 'Sibling Applying';
    }
    private set;
  }

  public static final String PRIORITY_TYPE_SIBLING_ATTENDING {
    get {
      return 'Sibling Attending';
    }
    private set;
  }

  public static final String PRIORITY_TYPE_PARENT_IS_ZETA_STAFF {
    get {
      return 'Parent is Zeta Staff';
    }
    private set;
  }

  public static final String REVIEW_STATUS_APPROVED {
    get {
      return 'Approved';
    }
    private set;
  }

  public static final String REVIEW_STATUS_DENIED {
    get {
      return 'Denied';
    }
    private set;
  }

  public static final String REVIEW_STATUS_PENDING {
    get {
      return 'Pending';
    }
    private set;
  }
}