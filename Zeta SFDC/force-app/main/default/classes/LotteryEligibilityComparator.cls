/**
 * Comparator for sorting lottery candidates by eligibility order.
 *
 * Sort order:
 * 1. Current_Priority_Group__c ASC (lower = higher priority)
 * 2. Within group: students WITHOUT Date_of_Current_Priority_Change__c first
 * 3. Then by: Randomized_Sort_Key__c ASC
 * 4. Tie-breaker: CreatedDate ASC
 */
public class LotteryEligibilityComparator implements Comparator<AcademicInterest> {
  public Integer compare(AcademicInterest a, AcademicInterest b) {
    // 1. Compare by priority group (lower = higher priority)
    Integer priorityCompare = comparePriorityGroup(a, b);
    if (priorityCompare != 0) {
      return priorityCompare;
    }

    // 2. Within same group: students without priority change date first
    Integer datePresenceCompare = comparePriorityChangeDatePresence(a, b);
    if (datePresenceCompare != 0) {
      return datePresenceCompare;
    }

    // 3. Compare by lottery number
    Integer lotteryCompare = compareLotteryNumber(a, b);
    if (lotteryCompare != 0) {
      return lotteryCompare;
    }

    // 4. Tie-breaker: CreatedDate
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

  private Integer comparePriorityChangeDatePresence(AcademicInterest a, AcademicInterest b) {
    Boolean hasDateA = a.Date_of_Current_Priority_Change__c != null;
    Boolean hasDateB = b.Date_of_Current_Priority_Change__c != null;

    // Students WITHOUT date come first (original lottery order)
    // Students WITH date come last (sibling bumps)
    if (!hasDateA && hasDateB) {
      return -1;
    } else if (hasDateA && !hasDateB) {
      return 1;
    }
    return 0;
  }

  private Integer compareLotteryNumber(AcademicInterest a, AcademicInterest b) {
    // Both have lottery numbers - compare them
    if (a.Randomized_Sort_Key__c != null && b.Randomized_Sort_Key__c != null) {
      if (a.Randomized_Sort_Key__c < b.Randomized_Sort_Key__c) {
        return -1;
      } else if (a.Randomized_Sort_Key__c > b.Randomized_Sort_Key__c) {
        return 1;
      }
      return 0;
    }

    // Record with lottery number comes before record without
    if (a.Randomized_Sort_Key__c != null && b.Randomized_Sort_Key__c == null) {
      return -1;
    } else if (a.Randomized_Sort_Key__c == null && b.Randomized_Sort_Key__c != null) {
      return 1;
    }

    // Neither has lottery number - fall through to CreatedDate
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