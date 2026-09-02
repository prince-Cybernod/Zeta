/**
 * Tests for {@link WaitlistRecalcServiceImpl}.
 */
@IsTest(IsParallel=true)
private class WaitlistRecalcServiceImplTest {
  private static final WaitlistRecalcServiceImpl SERVICE = new WaitlistRecalcServiceImpl();

  @IsTest
  private static void recalculatePositions_withNullInput_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.recalculatePositions(null);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null input');
  }

  @IsTest
  private static void recalculatePositions_withEmptyList_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.recalculatePositions(new List<AcademicInterest>());

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void recalculatePositions_assignsSequentialPositions() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(null, 2, null, 100), // priority 2, lottery 100
      createRecord(null, 1, null, 200), // priority 1, lottery 200
      createRecord(null, 1, null, 100) // priority 1, lottery 100
    };

    List<AcademicInterest> result = SERVICE.recalculatePositions(records);

    Assert.areEqual(3, result.size(), 'All records should be returned');

    Map<Decimal, AcademicInterest> byLottery = new Map<Decimal, AcademicInterest>();
    for (AcademicInterest r : records) {
      byLottery.put(r.Randomized_Sort_Key__c, r);
    }

    AcademicInterest p1l100 = findByPriorityAndLottery(records, 1, 100);
    Assert.areEqual(1, p1l100.Waitlist_Position__c, 'Priority 1, lottery 100 should be position 1');

    AcademicInterest p1l200 = findByPriorityAndLottery(records, 1, 200);
    Assert.areEqual(2, p1l200.Waitlist_Position__c, 'Priority 1, lottery 200 should be position 2');

    AcademicInterest p2l100 = findByPriorityAndLottery(records, 2, 100);
    Assert.areEqual(3, p2l100.Waitlist_Position__c, 'Priority 2, lottery 100 should be position 3');
  }

  @IsTest
  private static void recalculatePositions_returnsOnlyChangedRecords() {
    Id fakeId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id fakeId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithId(fakeId1, 1, 1, null, 100), // already position 1
      createRecordWithId(fakeId2, null, 1, null, 200) // no position yet
    };

    List<AcademicInterest> result = SERVICE.recalculatePositions(records);

    Assert.areEqual(1, result.size(), 'Only one record should have changed');
    Assert.areEqual(fakeId2, result[0].Id, 'Changed record should be the one without position');
    Assert.areEqual(2, result[0].Waitlist_Position__c, 'New position should be 2');
  }

  @IsTest
  private static void recalculatePositions_detectsPositionSwap() {
    Id fakeId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id fakeId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    // Record 1 was position 1 but has lower priority
    // Record 2 was position 2 but has higher priority
    // They should swap
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithId(fakeId1, 1, 2, null, 100), // was pos 1, priority 2
      createRecordWithId(fakeId2, 2, 1, null, 100) // was pos 2, priority 1
    };

    List<AcademicInterest> result = SERVICE.recalculatePositions(records);

    Assert.areEqual(2, result.size(), 'Both records should have changed');

    AcademicInterest record1 = null;
    AcademicInterest record2 = null;
    for (AcademicInterest r : result) {
      if (r.Id == fakeId1) {
        record1 = r;
      }
      if (r.Id == fakeId2) {
        record2 = r;
      }
    }

    Assert.areEqual(2, record1.Waitlist_Position__c, 'Record 1 should now be position 2');
    Assert.areEqual(1, record2.Waitlist_Position__c, 'Record 2 should now be position 1');
  }

  @IsTest
  private static void recalculatePositionsByCapacity_groupsRecordsCorrectly() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCapacity(capacityId1, 1, null, 200), // cap1, lottery 200
      createRecordWithCapacity(capacityId1, 1, null, 100), // cap1, lottery 100
      createRecordWithCapacity(capacityId2, 1, null, 300) // cap2, lottery 300
    };

    List<AcademicInterest> result = SERVICE.recalculatePositionsByCapacity(records);

    Assert.areEqual(3, result.size(), 'All records should be returned');

    for (AcademicInterest r : records) {
      if (r.Lottery_Capacity__c == capacityId1 && r.Randomized_Sort_Key__c == 100) {
        Assert.areEqual(1, r.Waitlist_Position__c, 'Cap1 lottery 100 should be position 1');
      }
      if (r.Lottery_Capacity__c == capacityId1 && r.Randomized_Sort_Key__c == 200) {
        Assert.areEqual(2, r.Waitlist_Position__c, 'Cap1 lottery 200 should be position 2');
      }
      if (r.Lottery_Capacity__c == capacityId2) {
        Assert.areEqual(
          1,
          r.Waitlist_Position__c,
          'Cap2 should have position 1 (separate waitlist)'
        );
      }
    }
  }

  @IsTest
  private static void recalculatePositionsByCapacity_withNullCapacity_skipsRecord() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCapacity(capacityId1, 1, null, 100),
      createRecordWithCapacity(null, 1, null, 200) // null capacity
    };

    List<AcademicInterest> result = SERVICE.recalculatePositionsByCapacity(records);

    Assert.areEqual(1, result.size(), 'Only record with capacity should be returned');
  }

  @IsTest
  private static void recalculatePositionsByCapacity_withEmptyList_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.recalculatePositionsByCapacity(
      new List<AcademicInterest>()
    );

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty input');
  }

  @IsTest
  private static void constructor_canBeInstantiated() {
    WaitlistRecalcServiceImpl instance = new WaitlistRecalcServiceImpl();

    Assert.isNotNull(instance, 'Service should be instantiable');
  }

  @IsTest
  private static void constructor_acceptsCustomSortService() {
    WaitlistSortServiceMock mockSort = new WaitlistSortServiceMock();
    mockSort.when(mockSort.method.sortAndAssignPositions())
      .thenReturn(new List<AcademicInterest>());

    WaitlistRecalcServiceImpl instance = new WaitlistRecalcServiceImpl(mockSort);
    instance.recalculatePositions(new List<AcademicInterest>{ new AcademicInterest() });

    Assert.areEqual(
      1,
      mockSort.getCallCount(mockSort.method.sortAndAssignPositions()),
      'Sort service should be called'
    );
  }

  // getRecordsToPromote tests

  @IsTest
  private static void getRecordsToPromote_withNullRecords_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.getRecordsToPromote(null, 5);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null records');
  }

  @IsTest
  private static void getRecordsToPromote_withEmptyRecords_returnsEmptyList() {
    List<AcademicInterest> result = SERVICE.getRecordsToPromote(new List<AcademicInterest>(), 5);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for empty records');
  }

  @IsTest
  private static void getRecordsToPromote_withNullSeats_returnsEmptyList() {
    List<AcademicInterest> records = new List<AcademicInterest>{ new AcademicInterest() };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, null);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for null seats');
  }

  @IsTest
  private static void getRecordsToPromote_withZeroSeats_returnsEmptyList() {
    List<AcademicInterest> records = new List<AcademicInterest>{ new AcademicInterest() };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, 0);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for zero seats');
  }

  @IsTest
  private static void getRecordsToPromote_withNegativeSeats_returnsEmptyList() {
    List<AcademicInterest> records = new List<AcademicInterest>{ new AcademicInterest() };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, -1);

    Assert.isTrue(result.isEmpty(), 'Should return empty list for negative seats');
  }

  @IsTest
  private static void getRecordsToPromote_returnsTopNRecords() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, 1, null, 100), // position 1
      createRecord(2, 1, null, 200), // position 2
      createRecord(3, 1, null, 300), // position 3
      createRecord(4, 1, null, 400) // position 4
    };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, 2);

    Assert.areEqual(2, result.size(), 'Should return 2 records');
    Assert.areEqual(1, result[0].Waitlist_Position__c, 'First record should be position 1');
    Assert.areEqual(2, result[1].Waitlist_Position__c, 'Second record should be position 2');
  }

  @IsTest
  private static void getRecordsToPromote_withMoreSeatsThanRecords_returnsAllRecords() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, 1, null, 100),
      createRecord(2, 1, null, 200)
    };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, 10);

    Assert.areEqual(2, result.size(), 'Should return all records when seats > records');
  }

  @IsTest
  private static void getRecordsToPromote_withOneSeat_returnsOneRecord() {
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, 1, null, 100),
      createRecord(2, 1, null, 200)
    };

    List<AcademicInterest> result = SERVICE.getRecordsToPromote(records, 1);

    Assert.areEqual(1, result.size(), 'Should return 1 record');
    Assert.areEqual(1, result[0].Waitlist_Position__c, 'Should be position 1');
  }

  // Helper methods

  private static AcademicInterest createRecord(
    Decimal position,
    Decimal priority,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    return new AcademicInterest(
      Waitlist_Position__c = position,
      Current_Priority_Group__c = priority,
      Date_of_Current_Priority_Change__c = priorityChangeDate,
      Randomized_Sort_Key__c = lotteryNumber
    );
  }

  private static AcademicInterest createRecordWithId(
    Id recordId,
    Decimal position,
    Decimal priority,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    AcademicInterest record = createRecord(position, priority, priorityChangeDate, lotteryNumber);
    record.Id = recordId;
    return record;
  }

  private static AcademicInterest createRecordWithCapacity(
    Id capacityId,
    Decimal priority,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    AcademicInterest record = createRecord(null, priority, priorityChangeDate, lotteryNumber);
    record.Lottery_Capacity__c = capacityId;
    return record;
  }

  private static AcademicInterest findByPriorityAndLottery(
    List<AcademicInterest> records,
    Decimal priority,
    Decimal lottery
  ) {
    for (AcademicInterest r : records) {
      if (r.Current_Priority_Group__c == priority && r.Randomized_Sort_Key__c == lottery) {
        return r;
      }
    }
    return null;
  }
}