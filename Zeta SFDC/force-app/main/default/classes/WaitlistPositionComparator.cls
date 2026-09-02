/**
 * Comparator for sorting AcademicInterest by Waitlist_Position__c ascending.
 * Nulls sort to end.
 */
public class WaitlistPositionComparator implements Comparator<AcademicInterest> {
  public Integer compare(AcademicInterest a, AcademicInterest b) {
    Decimal posA = a.Waitlist_Position__c;
    Decimal posB = b.Waitlist_Position__c;
    if (posA == null && posB == null) {
      return 0;
    }
    if (posA == null) {
      return 1;
    }
    if (posB == null) {
      return -1;
    }
    return posA < posB ? -1 : (posA > posB ? 1 : 0);
  }
}