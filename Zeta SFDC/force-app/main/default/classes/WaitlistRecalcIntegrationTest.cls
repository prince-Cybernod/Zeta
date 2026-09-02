/**
 * Integration tests for the Waitlist Recalc flow.
 *
 * Tests the full workflow:
 * 1. Sorting waitlisted students
 * 2. Assigning positions
 * 3. Detecting changes
 * 4. Identifying records to promote
 *
 * Note: OfferOptimizer is a stub, so offer optimization tests
 * validate stub behavior only. Full tests added with WI-1021.
 */
@IsTest(IsParallel=true)
private class WaitlistRecalcIntegrationTest {
  private static final WaitlistRecalcServiceImpl RECALC_SERVICE = new WaitlistRecalcServiceImpl();

  @IsTest
  private static void fullRecalcFlow_sortsAndAssignsPositions() {
    // Setup: unsorted waitlisted students
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(4, null, 400), // priority 4
      createRecord(1, null, 100), // priority 1 - should be first
      createRecord(2, null, 200), // priority 2
      createRecord(1, null, 150) // priority 1 - should be second
    };

    // Execute: recalculate positions
    List<AcademicInterest> changedRecords = RECALC_SERVICE.recalculatePositions(records);

    // Verify: all records changed (had no position before)
    Assert.areEqual(4, changedRecords.size(), 'All records should have changed');

    // Verify: records are sorted correctly and have positions
    // Priority 1 students first (sorted by lottery number)
    AcademicInterest p1l100 = findByPriorityAndLottery(records, 1, 100);
    AcademicInterest p1l150 = findByPriorityAndLottery(records, 1, 150);
    AcademicInterest p2l200 = findByPriorityAndLottery(records, 2, 200);
    AcademicInterest p4l400 = findByPriorityAndLottery(records, 4, 400);

    Assert.areEqual(1, p1l100.Waitlist_Position__c, 'Priority 1, lottery 100 should be position 1');
    Assert.areEqual(2, p1l150.Waitlist_Position__c, 'Priority 1, lottery 150 should be position 2');
    Assert.areEqual(3, p2l200.Waitlist_Position__c, 'Priority 2, lottery 200 should be position 3');
    Assert.areEqual(4, p4l400.Waitlist_Position__c, 'Priority 4, lottery 400 should be position 4');
  }

  @IsTest
  private static void fullRecalcFlow_siblingBumpGoesToBottomOfGroup() {
    Datetime priorityChangeDate = Datetime.now().addHours(-1);

    // Setup: students with sibling bump scenario
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, priorityChangeDate, 100), // sibling bump - should go to bottom of group 1
      createRecord(1, null, 200), // original priority 1 - should be first
      createRecord(2, null, 300) // priority 2 - should be last
    };

    // Execute
    List<AcademicInterest> changedRecords = RECALC_SERVICE.recalculatePositions(records);

    // Verify: sibling bump student is at bottom of their priority group
    AcademicInterest siblingBump = findByPriorityAndLottery(records, 1, 100);
    AcademicInterest originalP1 = findByPriorityAndLottery(records, 1, 200);
    AcademicInterest p2Student = findByPriorityAndLottery(records, 2, 300);

    Assert.areEqual(1, originalP1.Waitlist_Position__c, 'Original priority 1 should be position 1');
    Assert.areEqual(
      2,
      siblingBump.Waitlist_Position__c,
      'Sibling bump should be position 2 (bottom of group 1)'
    );
    Assert.areEqual(3, p2Student.Waitlist_Position__c, 'Priority 2 should be position 3');
  }

  @IsTest
  private static void recalcAndPromote_promotesTopStudentsWhenSeatsAvailable() {
    // Setup: sorted waitlisted students
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecord(1, null, 100),
      createRecord(1, null, 200),
      createRecord(2, null, 300),
      createRecord(2, null, 400)
    };

    // Step 1: Recalculate positions
    RECALC_SERVICE.recalculatePositions(records);

    // Verify positions assigned
    Assert.areEqual(1, records[0].Waitlist_Position__c);
    Assert.areEqual(2, records[1].Waitlist_Position__c);
    Assert.areEqual(3, records[2].Waitlist_Position__c);
    Assert.areEqual(4, records[3].Waitlist_Position__c);

    // Step 2: Get records to promote (2 seats available)
    List<AcademicInterest> toPromote = RECALC_SERVICE.getRecordsToPromote(records, 2);

    // Verify: top 2 students selected for promotion
    Assert.areEqual(2, toPromote.size(), 'Should select 2 students for promotion');
    Assert.areEqual(
      100,
      toPromote[0].Randomized_Sort_Key__c,
      'First promoted should be lottery 100'
    );
    Assert.areEqual(
      200,
      toPromote[1].Randomized_Sort_Key__c,
      'Second promoted should be lottery 200'
    );
  }

  @IsTest
  private static void recalcByCapacity_handlesMultipleCapacitiesIndependently() {
    Id capacityId1 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id capacityId2 = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    // Setup: students across two capacities (schools/grades)
    List<AcademicInterest> records = new List<AcademicInterest>{
      createRecordWithCapacity(capacityId1, 2, null, 200), // cap1, lower priority
      createRecordWithCapacity(capacityId1, 1, null, 100), // cap1, higher priority
      createRecordWithCapacity(capacityId2, 1, null, 500), // cap2 - separate waitlist
      createRecordWithCapacity(capacityId2, 1, null, 400) // cap2 - separate waitlist
    };

    // Execute
    List<AcademicInterest> changedRecords = RECALC_SERVICE.recalculatePositionsByCapacity(records);

    // Verify: each capacity has independent position numbering
    AcademicInterest cap1p1 = findByCapacityAndLottery(records, capacityId1, 100);
    AcademicInterest cap1p2 = findByCapacityAndLottery(records, capacityId1, 200);
    AcademicInterest cap2p1 = findByCapacityAndLottery(records, capacityId2, 400);
    AcademicInterest cap2p2 = findByCapacityAndLottery(records, capacityId2, 500);

    // Capacity 1 positions
    Assert.areEqual(1, cap1p1.Waitlist_Position__c, 'Cap1 lottery 100 should be position 1');
    Assert.areEqual(2, cap1p2.Waitlist_Position__c, 'Cap1 lottery 200 should be position 2');

    // Capacity 2 positions (starts at 1, not 3)
    Assert.areEqual(1, cap2p1.Waitlist_Position__c, 'Cap2 lottery 400 should be position 1');
    Assert.areEqual(2, cap2p2.Waitlist_Position__c, 'Cap2 lottery 500 should be position 2');
  }

  @IsTest
  private static void offerOptimizer_returnsEmptyListWhenNoPreOffers() {
    OfferOptimizerServiceImpl optimizer = new OfferOptimizerServiceImpl();

    List<AcademicInterest> records = new List<AcademicInterest>{
      new AcademicInterest(School_Rank__c = 1),
      new AcademicInterest(School_Rank__c = 2)
    };

    List<LotteryStatusChange> transitions = new List<LotteryStatusChange>();
    List<AcademicInterest> toRescind = optimizer.optimizeOffers(records, transitions);

    Assert.isTrue(toRescind.isEmpty(), 'Should return empty list when no Pre-Offer records');
  }

  // Helper methods

  private static AcademicInterest createRecord(
    Decimal priority,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    return new AcademicInterest(
      Current_Priority_Group__c = priority,
      Date_of_Current_Priority_Change__c = priorityChangeDate,
      Randomized_Sort_Key__c = lotteryNumber
    );
  }

  private static AcademicInterest createRecordWithCapacity(
    Id capacityId,
    Decimal priority,
    Datetime priorityChangeDate,
    Decimal lotteryNumber
  ) {
    AcademicInterest record = createRecord(priority, priorityChangeDate, lotteryNumber);
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

  private static AcademicInterest findByCapacityAndLottery(
    List<AcademicInterest> records,
    Id capacityId,
    Decimal lottery
  ) {
    for (AcademicInterest r : records) {
      if (r.Lottery_Capacity__c == capacityId && r.Randomized_Sort_Key__c == lottery) {
        return r;
      }
    }
    return null;
  }
}