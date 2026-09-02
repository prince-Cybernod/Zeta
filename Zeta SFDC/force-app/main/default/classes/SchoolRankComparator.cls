/**
 * Comparator for sorting AcademicInterest by School_Rank__c ascending.
 *
 * Sort order:
 * 1. School_Rank__c ASC (nulls sort to end)
 * 2. Randomized_Sort_Key__c ASC (nulls sort to end)
 * 3. CreatedDate ASC (nulls sort to end)
 */
public class SchoolRankComparator implements Comparator<AcademicInterest> {
  public Integer compare(AcademicInterest a, AcademicInterest b) {
    Integer rankCompare = compareNullableDecimals(a.School_Rank__c, b.School_Rank__c);
    if (rankCompare != 0) {
      return rankCompare;
    }

    Integer sortKeyCompare = compareNullableDecimals(
      a.Randomized_Sort_Key__c,
      b.Randomized_Sort_Key__c
    );
    if (sortKeyCompare != 0) {
      return sortKeyCompare;
    }

    return compareDatetimes(a.CreatedDate, b.CreatedDate);
  }

  private Integer compareNullableDecimals(Decimal a, Decimal b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    if (a < b) {
      return -1;
    }
    if (a > b) {
      return 1;
    }
    return 0;
  }

  private Integer compareDatetimes(Datetime a, Datetime b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    if (a < b) {
      return -1;
    }
    if (a > b) {
      return 1;
    }
    return 0;
  }
}