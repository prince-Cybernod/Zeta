/**
 * Tests for {@link WaitlistPositionComparator}.
 */
@IsTest(IsParallel=true)
private class WaitlistPositionComparatorTest {
  private static final WaitlistPositionComparator COMPARATOR = new WaitlistPositionComparator();

  @IsTest
  private static void compare_sortsByPositionAsc() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Waitlist_Position__c = 3),
      new AcademicInterest(Waitlist_Position__c = 1),
      new AcademicInterest(Waitlist_Position__c = 2)
    };

    records.sort(COMPARATOR);

    Assert.areEqual(1, records[0].Waitlist_Position__c);
    Assert.areEqual(2, records[1].Waitlist_Position__c);
    Assert.areEqual(3, records[2].Waitlist_Position__c);
  }

  @IsTest
  private static void compare_nullPositionSortsLast() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Waitlist_Position__c = null),
      new AcademicInterest(Waitlist_Position__c = 1)
    };

    records.sort(COMPARATOR);

    Assert.areEqual(1, records[0].Waitlist_Position__c);
    Assert.isNull(records[1].Waitlist_Position__c);
  }

  @IsTest
  private static void compare_bothNull_returnsZero() {
    Integer result = COMPARATOR.compare(
      new AcademicInterest(Waitlist_Position__c = null),
      new AcademicInterest(Waitlist_Position__c = null)
    );

    Assert.areEqual(0, result);
  }

  @IsTest
  private static void compare_equalPositions_returnsZero() {
    Integer result = COMPARATOR.compare(
      new AcademicInterest(Waitlist_Position__c = 5),
      new AcademicInterest(Waitlist_Position__c = 5)
    );

    Assert.areEqual(0, result);
  }
}