/**
 * Comparator for determining waitlist rank order.
 *
 * Sort order:
 * 1. Current_Priority_Group__c ASC (lower = higher priority)
 * 2. Within group by category:
 *    - Category 1: Original lottery participants (has lottery number, no date change)
 *    - Category 2: Sibling bumps (has date change)
 *    - Category 3: New post-lottery applicants (no lottery number, no date change)
 * 3. Within same category:
 *    - Category 2: Date_of_Current_Priority_Change__c ASC
 *    - Categories 1 & 3: Randomized_Sort_Key__c ASC, then CreatedDate ASC
 */
public class WaitlistRankComparator implements Comparator<AcademicInterest> {
  public Integer compare(AcademicInterest a, AcademicInterest b) {
    // 1. Compare by priority group (lower = higher priority)
    Integer priorityCompare = comparePriorityGroup(a, b);
    if (priorityCompare != 0) {
      return priorityCompare;
    }

    // 2. Within same group: sort by category
    // (original lottery -> sibling bumps -> new post-lottery)
    Integer categoryA = getRecordCategory(a);
    Integer categoryB = getRecordCategory(b);
    if (categoryA != categoryB) {
      return categoryA < categoryB ? -1 : 1;
    }

    // 3. Within same category:
    //    Category 2 (sibling bumps): sort by date of priority change
    //    Categories 1 & 3: sort by lottery order, then CreatedDate
    if (categoryA == 2) {
      return compareDateOfPriorityChange(a, b);
    }

    Integer lotteryCompare = compareLotteryOrder(a, b);
    if (lotteryCompare != 0) {
      return lotteryCompare;
    }

    return compareCreatedDate(a, b);
  }

  private Integer comparePriorityGroup(AcademicInterest a, AcademicInterest b) {
    Decimal priorityA = a.Current_Priority_Group__c != null ? a.Current_Priority_Group__c : 999;
    Decimal priorityB = b.Current_Priority_Group__c != null ? b.Current_Priority_Group__c : 999;

    if (priorityA < priorityB) {
      return -1;
    } else if (priorityA > priorityB) {
      return 1;
    }
    return 0;
  }

  private Integer getRecordCategory(AcademicInterest record) {
    Boolean hasLottery = record.Randomized_Sort_Key__c != null;
    Boolean hasDateChange = record.Date_of_Current_Priority_Change__c != null;

    if (hasLottery && !hasDateChange) {
      return 1; // Original lottery participant
    } else if (hasDateChange) {
      return 2; // Sibling bump
    } else {
      return 3; // New post-lottery applicant
    }
  }

  private Integer compareDateOfPriorityChange(AcademicInterest a, AcademicInterest b) {
    Datetime dateA = a.Date_of_Current_Priority_Change__c;
    Datetime dateB = b.Date_of_Current_Priority_Change__c;

    if (dateA == null && dateB == null) {
      return 0;
    }
    if (dateA == null) {
      return 1;
    }
    if (dateB == null) {
      return -1;
    }

    if (dateA < dateB) {
      return -1;
    } else if (dateA > dateB) {
      return 1;
    }
    return 0;
  }

  private Integer compareLotteryOrder(AcademicInterest a, AcademicInterest b) {
    // Use lottery number if both have it
    if (a.Randomized_Sort_Key__c != null && b.Randomized_Sort_Key__c != null) {
      if (a.Randomized_Sort_Key__c < b.Randomized_Sort_Key__c) {
        return -1;
      } else if (a.Randomized_Sort_Key__c > b.Randomized_Sort_Key__c) {
        return 1;
      }
      return 0;
    }

    // If only one has lottery number, that one comes first (has defined order)
    if (a.Randomized_Sort_Key__c != null && b.Randomized_Sort_Key__c == null) {
      return -1;
    } else if (a.Randomized_Sort_Key__c == null && b.Randomized_Sort_Key__c != null) {
      return 1;
    }

    // Neither has lottery number, fall through to CreatedDate
    return 0;
  }

  private Integer compareCreatedDate(AcademicInterest a, AcademicInterest b) {
    Datetime createdA = a.CreatedDate;
    Datetime createdB = b.CreatedDate;

    if (createdA == null && createdB == null) {
      return 0;
    }
    if (createdA == null) {
      return 1;
    }
    if (createdB == null) {
      return -1;
    }

    if (createdA < createdB) {
      return -1;
    } else if (createdA > createdB) {
      return 1;
    }
    return 0;
  }
}