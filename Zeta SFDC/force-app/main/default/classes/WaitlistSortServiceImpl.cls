/**
 * Implementation of {@link WaitlistSortService}.
 *
 * Sorts waitlisted students by priority group and lottery number,
 * with special handling for sibling bumps (recently promoted students
 * go to the bottom of their new priority group).
 */
public with sharing class WaitlistSortServiceImpl implements WaitlistSortService {
  public WaitlistSortServiceImpl() {
  }

  public List<AcademicInterest> sortAndAssignPositions(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return records;
    }

    List<AcademicInterest> sortedRecords = new List<AcademicInterest>(records);
    sortedRecords.sort(new WaitlistRankComparator());

    Integer position = 1;
    for (AcademicInterest record : sortedRecords) {
      record.Waitlist_Position__c = position++;
    }

    return sortedRecords;
  }
}