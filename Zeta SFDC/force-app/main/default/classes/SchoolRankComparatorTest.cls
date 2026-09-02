/**
 * Tests for {@link SchoolRankComparator}.
 */
@IsTest(IsParallel=true)
private class SchoolRankComparatorTest {
  private static final SchoolRankComparator COMPARATOR = new SchoolRankComparator();

  @IsTest
  private static void compare_sortsBySchoolRankAsc() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(3, null),
      createRecord(1, null),
      createRecord(2, null)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(1, result[0].School_Rank__c, 'First should be rank 1');
    Assert.areEqual(2, result[1].School_Rank__c, 'Second should be rank 2');
    Assert.areEqual(3, result[2].School_Rank__c, 'Third should be rank 3');
  }

  @IsTest
  private static void compare_nullSchoolRank_sortsLast() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(null, null),
      createRecord(5, null),
      createRecord(null, null)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(5, result[0].School_Rank__c, 'Record with rank should come first');
    Assert.isNull(result[1].School_Rank__c, 'Null ranks should sort to end');
    Assert.isNull(result[2].School_Rank__c, 'Null ranks should sort to end');
  }

  @IsTest
  private static void compare_sameRank_usesLotteryNumberAsTieBreaker() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, 500),
      createRecord(1, 100),
      createRecord(1, 300)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(100, result[0].Randomized_Sort_Key__c, 'First should be lottery 100');
    Assert.areEqual(300, result[1].Randomized_Sort_Key__c, 'Second should be lottery 300');
    Assert.areEqual(500, result[2].Randomized_Sort_Key__c, 'Third should be lottery 500');
  }

  @IsTest
  private static void compare_nullLotteryNumber_sortsLast() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, null),
      createRecord(1, 100)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      100,
      result[0].Randomized_Sort_Key__c,
      'Record with lottery number should come first'
    );
    Assert.isNull(result[1].Randomized_Sort_Key__c, 'Null lottery number should sort to end');
  }

  @IsTest
  private static void compare_mixedScenario_sortsCorrectly() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, 100),
      createRecord(1, 500),
      createRecord(1, 100),
      createRecord(null, 50)
    };

    List<AcademicInterest> result = sortRecords(records);

    // Rank 1 with lottery 100 first
    Assert.areEqual(1, result[0].School_Rank__c);
    Assert.areEqual(100, result[0].Randomized_Sort_Key__c);

    // Rank 1 with lottery 500
    Assert.areEqual(1, result[1].School_Rank__c);
    Assert.areEqual(500, result[1].Randomized_Sort_Key__c);

    // Rank 2
    Assert.areEqual(2, result[2].School_Rank__c);

    // Null rank (sorts last)
    Assert.isNull(result[3].School_Rank__c);
  }

  @IsTest
  private static void compare_singleRecord_returnsRecord() {
    List<AcademicInterest> records = new List<AcademicInterest>{ createRecord(1, 100) };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(1, result.size(), 'Should have one record');
  }

  @IsTest
  private static void compare_emptyList_returnsEmptyList() {
    List<AcademicInterest> records = new List<AcademicInterest>();

    List<AcademicInterest> result = sortRecords(records);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void compare_sameRankSameSortKey_usesCreatedDateTieBreaker() {
    Datetime earlier = Datetime.newInstance(2025, 1, 1, 10, 0, 0);
    Datetime later = Datetime.newInstance(2025, 1, 1, 12, 0, 0);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, 100, later),
      createRecordWithCreatedDate(1, 100, earlier)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(earlier, result[0].CreatedDate, 'Earlier CreatedDate should sort first');
    Assert.areEqual(later, result[1].CreatedDate, 'Later CreatedDate should sort last');
  }

  @IsTest
  private static void compare_sameRankSameSortKey_nullCreatedDateSortsLast() {
    Datetime earlier = Datetime.newInstance(2025, 1, 1, 10, 0, 0);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, 100, null),
      createRecordWithCreatedDate(1, 100, earlier)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(earlier, result[0].CreatedDate, 'Non-null CreatedDate should sort first');
    Assert.isNull(result[1].CreatedDate, 'Null CreatedDate should sort last');
  }

  @IsTest
  private static void compare_sameRankSameSortKey_bothCreatedDatesNull_returnsEqual() {
    AcademicInterest a = createRecordWithCreatedDate(1, 100, null);
    AcademicInterest b = createRecordWithCreatedDate(1, 100, null);

    Integer result = COMPARATOR.compare(a, b);

    Assert.areEqual(0, result, 'Both null CreatedDates should be equal');
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

  private static AcademicInterest createRecord(Decimal schoolRank, Decimal lotteryNumber) {
    return new AcademicInterest(
      School_Rank__c = schoolRank,
      Randomized_Sort_Key__c = lotteryNumber
    );
  }

  private static AcademicInterest createRecordWithCreatedDate(
    Decimal schoolRank,
    Decimal lotteryNumber,
    Datetime createdDate
  ) {
    AcademicInterest ai = new AcademicInterest(
      School_Rank__c = schoolRank,
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