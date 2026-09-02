/**
 * Tests for {@link WaitlistRankComparator}.
 */
@IsTest(IsParallel=true)
private class WaitlistRankComparatorTest {
  private static final WaitlistRankComparator COMPARATOR = new WaitlistRankComparator();

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

    Assert.isNull(
      result[0].Date_of_Current_Priority_Change__c,
      'First should be record without priority change date'
    );
    Assert.isNotNull(
      result[1].Date_of_Current_Priority_Change__c,
      'Second should be record with priority change date (sibling bump)'
    );
  }

  @IsTest
  private static void compare_nullPriorityGroup_sortsLast() {
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

    Assert.areEqual(1, result[0].Current_Priority_Group__c);
    Assert.isNull(result[0].Date_of_Current_Priority_Change__c);
    Assert.areEqual(150, result[0].Randomized_Sort_Key__c);

    Assert.areEqual(1, result[1].Current_Priority_Group__c);
    Assert.isNull(result[1].Date_of_Current_Priority_Change__c);
    Assert.areEqual(200, result[1].Randomized_Sort_Key__c);

    Assert.areEqual(1, result[2].Current_Priority_Group__c);
    Assert.isNotNull(result[2].Date_of_Current_Priority_Change__c);
    Assert.areEqual(100, result[2].Randomized_Sort_Key__c);

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
  private static void compare_emptyList_returnsEmptyList() {
    List<AcademicInterest> records = new List<AcademicInterest>();

    List<AcademicInterest> result = sortRecords(records);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void compare_newPostLotteryApp_sortsAfterSiblingBump() {
    Datetime now = Datetime.now();
    Datetime earlier = now.addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, null, null, now),
      createRecordWithCreatedDate(1, earlier, null, earlier)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.isNotNull(
      result[0].Date_of_Current_Priority_Change__c,
      'First should be sibling bump (has date change)'
    );
    Assert.isNull(
      result[1].Date_of_Current_Priority_Change__c,
      'Second should be new post-lottery (no date change, no lottery)'
    );
    Assert.isNull(result[1].Randomized_Sort_Key__c, 'Second should have no lottery number');
  }

  @IsTest
  private static void compare_newPostLotteryApp_sortsAfterOriginalLottery() {
    Datetime now = Datetime.now();
    Datetime earlier = now.addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, null, null, now),
      createRecordWithCreatedDate(1, null, 100, earlier)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      100,
      result[0].Randomized_Sort_Key__c,
      'First should be original lottery participant'
    );
    Assert.isNull(result[1].Randomized_Sort_Key__c, 'Second should be new post-lottery applicant');
  }

  @IsTest
  private static void compare_multipleNewPostLotteryApps_sortByCreatedDate() {
    Datetime oldest = Datetime.now().addHours(-3);
    Datetime middle = Datetime.now().addHours(-2);
    Datetime newest = Datetime.now().addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, null, null, newest),
      createRecordWithCreatedDate(1, null, null, oldest),
      createRecordWithCreatedDate(1, null, null, middle)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(oldest, result[0].CreatedDate, 'First should be oldest');
    Assert.areEqual(middle, result[1].CreatedDate, 'Second should be middle');
    Assert.areEqual(newest, result[2].CreatedDate, 'Third should be newest');
  }

  @IsTest
  private static void compare_allThreeCategories_sortCorrectly() {
    Datetime now = Datetime.now();
    Datetime hour1 = now.addHours(-3);
    Datetime hour2 = now.addHours(-2);
    Datetime hour3 = now.addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCreatedDate(1, null, null, now),
      createRecordWithCreatedDate(1, null, 200, hour1),
      createRecordWithCreatedDate(1, hour2, null, hour2),
      createRecordWithCreatedDate(1, null, 100, hour3)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(100, result[0].Randomized_Sort_Key__c, 'First: lottery 100');
    Assert.isNull(result[0].Date_of_Current_Priority_Change__c);

    Assert.areEqual(200, result[1].Randomized_Sort_Key__c, 'Second: lottery 200');
    Assert.isNull(result[1].Date_of_Current_Priority_Change__c);

    Assert.isNotNull(result[2].Date_of_Current_Priority_Change__c, 'Third: sibling bump');

    Assert.isNull(result[3].Randomized_Sort_Key__c, 'Fourth: no lottery');
    Assert.isNull(result[3].Date_of_Current_Priority_Change__c, 'Fourth: no date change');
  }

  @IsTest
  private static void compare_multipleSiblingBumps_sortByDateOfPriorityChange() {
    Datetime oldest = Datetime.now().addHours(-3);
    Datetime middle = Datetime.now().addHours(-2);
    Datetime newest = Datetime.now().addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, newest, 300),
      createRecord(1, oldest, 100),
      createRecord(1, middle, 200)
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      oldest,
      result[0].Date_of_Current_Priority_Change__c,
      'First should have oldest priority change'
    );
    Assert.areEqual(
      middle,
      result[1].Date_of_Current_Priority_Change__c,
      'Second should have middle priority change'
    );
    Assert.areEqual(
      newest,
      result[2].Date_of_Current_Priority_Change__c,
      'Third should have newest priority change'
    );
  }

  @IsTest
  private static void compare_siblingBumpWithAndWithoutLotteryKey_sortByDateOfPriorityChange() {
    Datetime earlier = Datetime.now().addHours(-2);
    Datetime later = Datetime.now().addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, later, 50), // has lottery key 50 (low), but later date change
      createRecord(1, earlier, null) // no lottery key, but earlier date change
    };

    List<AcademicInterest> result = sortRecords(records);

    Assert.areEqual(
      earlier,
      result[0].Date_of_Current_Priority_Change__c,
      'Earlier priority change should come first, regardless of lottery key'
    );
    Assert.areEqual(
      later,
      result[1].Date_of_Current_Priority_Change__c,
      'Later priority change should come second, even with lower lottery key'
    );
  }

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
    String jsonStr = JSON.serialize(
      new Map<String, Object>{
        'Current_Priority_Group__c' => priorityGroup,
        'Date_of_Current_Priority_Change__c' => priorityChangeDate,
        'Randomized_Sort_Key__c' => lotteryNumber,
        'CreatedDate' => createdDate
      }
    );
    return (AcademicInterest) JSON.deserialize(jsonStr, AcademicInterest.class);
  }
}