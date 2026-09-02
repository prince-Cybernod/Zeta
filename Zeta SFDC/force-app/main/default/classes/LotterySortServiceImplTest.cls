/**
 * Tests for {@link LotterySortServiceImpl}.
 */
@IsTest(IsParallel=true)
private class LotterySortServiceImplTest {
  private static final LotterySortServiceImpl SERVICE;
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SERVICE = new LotterySortServiceImpl(DATABASE_REPO_MOCK);
  }

  // ============================================================
  // assignRandomizedSortKeys tests
  // ============================================================

  @IsTest
  private static void assignRandomizedSortKeys_withNullInput_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.assignRandomizedSortKeys(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void assignRandomizedSortKeys_withEmptyList_doesNotThrow() {
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      SERVICE.assignRandomizedSortKeys(new List<AcademicInterest>());
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void assignRandomizedSortKeys_assignsKeysToRecordsWithoutKeys() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Status = 'Eligible'),
      new AcademicInterest(Status = 'Eligible')
    };

    SERVICE.assignRandomizedSortKeys(records);

    Assert.isNotNull(records[0].Randomized_Sort_Key__c, 'First record should have key');
    Assert.isNotNull(records[1].Randomized_Sort_Key__c, 'Second record should have key');
  }

  @IsTest
  private static void assignRandomizedSortKeys_preservesExistingKeys() {
    Decimal existingKey = 12345;
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Status = 'Eligible', Randomized_Sort_Key__c = existingKey)
    };

    SERVICE.assignRandomizedSortKeys(records);

    Assert.areEqual(
      existingKey,
      records[0].Randomized_Sort_Key__c,
      'Existing key should be preserved'
    );
  }

  @IsTest
  private static void assignRandomizedSortKeys_generatesUniqueKeys() {
    List<AcademicInterest> records = new List<AcademicInterest>();
    for (Integer i = 0; i < 100; i++) {
      records.add(new AcademicInterest(Status = 'Eligible'));
    }

    SERVICE.assignRandomizedSortKeys(records);

    Set<Decimal> uniqueKeys = new Set<Decimal>();
    for (AcademicInterest record : records) {
      uniqueKeys.add(record.Randomized_Sort_Key__c);
    }

    Assert.areEqual(
      100,
      uniqueKeys.size(),
      'All keys must be unique (field has unique constraint)'
    );
  }

  @IsTest
  private static void assignRandomizedSortKeys_avoidsExistingKeys() {
    Decimal existingKey = 12345;
    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(Status = 'Eligible', Randomized_Sort_Key__c = existingKey),
      new AcademicInterest(Status = 'Eligible'),
      new AcademicInterest(Status = 'Eligible')
    };

    SERVICE.assignRandomizedSortKeys(records);

    Set<Decimal> allKeys = new Set<Decimal>();
    for (AcademicInterest record : records) {
      allKeys.add(record.Randomized_Sort_Key__c);
    }

    Assert.areEqual(3, allKeys.size(), 'New keys should not collide with existing keys');
    Assert.areEqual(
      existingKey,
      records[0].Randomized_Sort_Key__c,
      'Existing key should be preserved'
    );
  }

  // ============================================================
  // sortByLotteryOrder tests
  // ============================================================

  @IsTest
  private static void sortByLotteryOrder_withNullInput_returnsNull() {
    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(null);

    Assert.isNull(result, 'Should return null for null input');
  }

  @IsTest
  private static void sortByLotteryOrder_withEmptyList_returnsEmptyList() {
    List<AcademicInterest> emptyList = new List<AcademicInterest>();

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(emptyList);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void sortByLotteryOrder_sortsByPriorityGroupAsc() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(4, null, 100),
      createRecord(1, null, 200),
      createRecord(3, null, 300),
      createRecord(2, null, 400)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

    Assert.areEqual(1, result[0].Current_Priority_Group__c, 'First should be priority 1');
    Assert.areEqual(2, result[1].Current_Priority_Group__c, 'Second should be priority 2');
    Assert.areEqual(3, result[2].Current_Priority_Group__c, 'Third should be priority 3');
    Assert.areEqual(4, result[3].Current_Priority_Group__c, 'Fourth should be priority 4');
  }

  @IsTest
  private static void sortByLotteryOrder_withinGroupSortsByLotteryNumber() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, 500),
      createRecord(2, null, 100),
      createRecord(2, null, 300)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

    Assert.areEqual(100, result[0].Randomized_Sort_Key__c, 'First should be lottery 100');
    Assert.areEqual(300, result[1].Randomized_Sort_Key__c, 'Second should be lottery 300');
    Assert.areEqual(500, result[2].Randomized_Sort_Key__c, 'Third should be lottery 500');
  }

  @IsTest
  private static void sortByLotteryOrder_recordWithLotteryNumberComesBeforeRecordWithout() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, null),
      createRecord(2, null, 100)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

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
  private static void sortByLotteryOrder_siblingBumpGoesToBottomOfGroup() {
    Datetime priorityChangeDate = Datetime.now().addHours(-1);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, priorityChangeDate, 100),
      createRecord(1, null, 200)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

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
  private static void sortByLotteryOrder_handlesNullPriorityGroup() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(null, null, 100),
      createRecord(1, null, 200)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

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
  private static void sortByLotteryOrder_mixedScenario_sortsCorrectly() {
    Datetime now = Datetime.now();

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(2, null, 300),
      createRecord(1, now, 100),
      createRecord(1, null, 200),
      createRecord(2, null, 100),
      createRecord(1, null, 150)
    };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

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
  private static void sortByLotteryOrder_singleRecord_returnsRecord() {
    List<AcademicInterest> records = new List<AcademicInterest>{ createRecord(1, null, 100) };

    List<AcademicInterest> result = SERVICE.sortByLotteryOrder(records);

    Assert.areEqual(1, result.size(), 'Should have one record');
  }

  // ============================================================
  // getTopCandidatesForCapacity tests
  // ============================================================

  @IsTest
  private static void getTopCandidatesForCapacity_withNullCapacityId_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(null, 5);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null capacity ID');
  }

  @IsTest
  private static void getTopCandidatesForCapacity_withNullSeats_returnsEmptyList() {
    Id fakeId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(fakeId, null);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null seats');
  }

  @IsTest
  private static void getTopCandidatesForCapacity_withZeroSeats_returnsEmptyList() {
    Id fakeId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(fakeId, 0);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for zero seats');
  }

  @IsTest
  private static void getTopCandidatesForCapacity_withNegativeSeats_returnsEmptyList() {
    Id fakeId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(fakeId, -1);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for negative seats');
  }

  @IsTest
  private static void getTopCandidatesForCapacity_withValidInput_returnsTopCandidates() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    List<AcademicInterest> eligibleStudents = new List<AcademicInterest>{
      createRecord(1, null, 100),
      createRecord(1, null, 200),
      createRecord(2, null, 150)
    };
    for (AcademicInterest record : eligibleStudents) {
      record.Id = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    }

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(eligibleStudents);

    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(capacityId, 2);

    Assert.areEqual(2, result.size(), 'Should return top 2 candidates');
    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void getTopCandidatesForCapacity_withNoEligible_returnsEmptyList() {
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>());

    List<AcademicInterest> result = SERVICE.getTopCandidatesForCapacity(capacityId, 5);

    Assert.isTrue(result.isEmpty(), 'Should return empty list when no eligible students');
  }

  // ============================================================
  // Helper methods
  // ============================================================

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