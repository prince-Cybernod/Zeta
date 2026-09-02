/**
 * Tests for {@link LotteryEligibilityComparator}.
 */
@IsTest(IsParallel=true)
private class LotteryEligibilityComparatorTest {
  private static final LotteryEligibilityComparator COMPARATOR = new LotteryEligibilityComparator();

  @IsTest
  private static void compare_withNullInput_returnsNull() {
    List<AcademicInterest> result = sortRecords(null);

    Assert.isNull(result, 'Should return null for null input');
  }

  @IsTest
  private static void compare_withEmptyList_returnsEmptyList() {
    List<AcademicInterest> emptyList = new List<AcademicInterest>();

    List<AcademicInterest> result = sortRecords(emptyList);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void compare_sortsByPriorityGroupAsc() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(4, null, 100),
      createRecord(1, null, 200),
      createRecord(3, null, 300),
      createRecord(2, null, 400)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(1, result[0].Current_Priority_Group__c, 'First should be priority 1');
    Assert.areEqual(2, result[1].Current_Priority_Group__c, 'Second should be priority 2');
    Assert.areEqual(3, result[2].Current_Priority_Group__c, 'Third should be priority 3');
    Assert.areEqual(4, result[3].Current_Priority_Group__c, 'Fourth should be priority 4');
  }

  @IsTest
  private static void compare_withinGroupSortsByLotteryNumber() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, 500),
      createRecord(2, null, 100),
      createRecord(2, null, 300)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(100, result[0].Randomized_Sort_Key__c, 'First should be lottery 100');
    Assert.areEqual(300, result[1].Randomized_Sort_Key__c, 'Second should be lottery 300');
    Assert.areEqual(500, result[2].Randomized_Sort_Key__c, 'Third should be lottery 500');
  }

  @IsTest
  private static void compare_recordWithLotteryNumberComesBeforeRecordWithout() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, null), // no lottery number
      createRecord(2, null, 100) // has lottery number
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      100,
      result[0].Randomized_Sort_Key__c,
      'Record with lottery number should come first'
    );
    Assert.isNull(
      result[1].Randomized_Sort_Key__c,
      'Record without lottery number should come last'
    );
  }

  @IsTest
  private static void compare_siblingBumpGoesToBottomOfGroup() {
    Datetime priorityChangeDate = Datetime.now().addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, priorityChangeDate, 100), // sibling bump
      createRecord(1, null, 200) // original lottery order
    };

    List<AcademicInterest> result = sortRecords(records);

    // Record WITHOUT priority change date comes first
    Assert.isNull(
      result[0].Date_of_Current_Priority_Change__c,
      'First should be record without priority change date'
    );
    // Record WITH priority change date (sibling bump) comes last
    Assert.isNotNull(
      result[1].Date_of_Current_Priority_Change__c,
      'Second should be record with priority change date (sibling bump)'
    );
  }

  @IsTest
  private static void compare_handlesNullPriorityGroup() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(null, null, 100),
      createRecord(1, null, 200)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      1,
      result[0].Current_Priority_Group__c,
      'Record with priority should come first'
    );
    Assert.isNull(
      result[1].Current_Priority_Group__c,
      'Record with null priority should come last'
    );
  }

  @IsTest
  private static void compare_mixedScenario_sortsCorrectly() {
    Datetime now = Datetime.now();

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, 300),
      createRecord(1, now, 100), // sibling bump in group 1
      createRecord(1, null, 200), // original group 1
      createRecord(2, null, 100),
      createRecord(1, null, 150) // original group 1
    };

    List<AcademicInterest> result = sortRecords(records);

    // Group 1 without date change first (sorted by lottery number)
    Assert.areEqual(1, result[0].Current_Priority_Group__c);
    Assert.isNull(result[0].Date_of_Current_Priority_Change__c);
    Assert.areEqual(150, result[0].Randomized_Sort_Key__c);

    Assert.areEqual(1, result[1].Current_Priority_Group__c);
    Assert.isNull(result[1].Date_of_Current_Priority_Change__c);
    Assert.areEqual(200, result[1].Randomized_Sort_Key__c);

    // Group 1 with date change (sibling bump) at bottom of group 1
    Assert.areEqual(1, result[2].Current_Priority_Group__c);
    Assert.isNotNull(result[2].Date_of_Current_Priority_Change__c);
    Assert.areEqual(100, result[2].Randomized_Sort_Key__c);

    // Group 2 (sorted by lottery number)
    Assert.areEqual(2, result[3].Current_Priority_Group__c);
    Assert.areEqual(100, result[3].Randomized_Sort_Key__c);

    Assert.areEqual(2, result[4].Current_Priority_Group__c);
    Assert.areEqual(300, result[4].Randomized_Sort_Key__c);
  }

  @IsTest
  private static void compare_singleRecord_returnsRecord() {
    List<AcademicInterest> records = new List<AcademicInterest>{ createRecord(1, null, 100) };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(1, result.size(), 'Should have one record');
  }

  @IsTest
  private static void compare_bothLotteryNumbersNull_usesCreatedDateTieBreaker() {
    Datetime earlier = Datetime.newInstance(2025, 1, 1, 10, 0, 0);
    Datetime later = Datetime.newInstance(2025, 1, 1, 12, 0, 0);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, null, null, later),
      createRecordWithCreatedDate(1, null, null, earlier)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(earlier, result[0].CreatedDate, 'Earlier CreatedDate should sort first');
    Assert.areEqual(later, result[1].CreatedDate, 'Later CreatedDate should sort last');
  }

  @IsTest
  private static void compare_bothCreatedDatesNull_returnsEqual() {
    AcademicInterest a = createRecordWithCreatedDate(1, null, null, null);
    AcademicInterest b = createRecordWithCreatedDate(1, null, null, null);

    Integer result = COMPARATOR.compare(a, b);

    Assert.areEqual(0, result, 'Both null CreatedDates should be equal');
  }

  @IsTest
  private static void compare_samePriorityBothNullDates_usesLotteryNumber() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, 500),
      createRecord(2, null, 100)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      100,
      result[0].Randomized_Sort_Key__c,
      'Lower lottery number should sort first'
    );
    Assert.areEqual(
      500,
      result[1].Randomized_Sort_Key__c,
      'Higher lottery number should sort last'
    );
  }

  // ============================================================
  // Helper methods
  // ============================================================

  private static List<AcademicInterest> sortRecords(List<AcademicInterest> records) {
    if (records == null || records.isEmpty()) {
      return records;
    }
    List<AcademicInterest> sorted = new List<AcademicInterest>(records);
    sorted.sort(COMPARATOR);
    return sorted;
  }

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

  private static AcademicInterest createRecordWithCreatedDate(
    Decimal priorityGroup,
    Datetime priorityChangeDate,
    Decimal lotteryNumber,
    Datetime createdDate
  ) {
    AcademicInterest ai = new AcademicInterest(
      Current_Priority_Group__c = priorityGroup,
      Date_of_Current_Priority_Change__c = priorityChangeDate,
      Randomized_Sort_Key__c = lotteryNumber
    );
    if (createdDate != null) {
      return (AcademicInterest) ReadOnlySObject.create(
        ai,
        new Map<String, Object>{ 'CreatedDate' => createdDate }
      );
    }
    return ai;
  }
}