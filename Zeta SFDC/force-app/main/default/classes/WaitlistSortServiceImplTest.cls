/**
 * Tests for {@link WaitlistSortServiceImpl}.
 *
 * Note: Sorting logic is tested in {@link WaitlistRankComparatorTest}.
 * These tests focus on the service's responsibilities: null/empty handling and position assignment.
 */
@IsTest(IsParallel=true)
private class WaitlistSortServiceImplTest {
  private static final WaitlistSortServiceImpl SERVICE = new WaitlistSortServiceImpl();

  @IsTest
  private static void sortAndAssignPositions_withNullInput_returnsNull() {
    List<AcademicInterest> result = SERVICE.sortAndAssignPositions(null);

    Assert.isNull(result, 'Should return null for null input');
  }

  @IsTest
  private static void sortAndAssignPositions_withEmptyList_returnsEmptyList() {
    List<AcademicInterest> emptyList = new List<AcademicInterest>();

    List<AcademicInterest> result = SERVICE.sortAndAssignPositions(emptyList);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void sortAndAssignPositions_assignsSequentialPositions() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, null, 100),
      createRecord(2, null, 200),
      createRecord(3, null, 300)
    };

    List<AcademicInterest> result = SERVICE.sortAndAssignPositions(records);

    Assert.areEqual(1, result[0].Waitlist_Position__c, 'First position should be 1');
    Assert.areEqual(2, result[1].Waitlist_Position__c, 'Second position should be 2');
    Assert.areEqual(3, result[2].Waitlist_Position__c, 'Third position should be 3');
  }

  @IsTest
  private static void sortAndAssignPositions_singleRecord_assignsPositionOne() {
    List<AcademicInterest> records = new List<AcademicInterest>{ createRecord(1, null, 100) };

    List<AcademicInterest> result = SERVICE.sortAndAssignPositions(records);

    Assert.areEqual(1, result.size(), 'Should have one record');
    Assert.areEqual(1, result[0].Waitlist_Position__c, 'Position should be 1');
  }

  /**
   * Helper to create test AcademicInterest records with specified values.
   */
  private static AcademicInterest createRecord(
    Decimal priorityGroup,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    return new AcademicInterest(
      Current_Priority_Group__c = priorityGroup,
      Date_of_Current_Priority_Change__c = priorityChangeDate,
      Randomized_Sort_Key__c = lotteryNumber
    );
  }
}