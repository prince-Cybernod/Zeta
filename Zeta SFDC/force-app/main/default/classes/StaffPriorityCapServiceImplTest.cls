/**
 * Tests for {@link StaffPriorityCapServiceImpl}.
 */
@IsTest(IsParallel=true)
private class StaffPriorityCapServiceImplTest {
  private static DatabaseRepoMock mockRepo;
  private static StaffPriorityCapKeySourceMock mockKeySource;
  private static StaffPriorityCapServiceImpl service;

  private static void setUp() {
    mockRepo = new DatabaseRepoMock();
    mockKeySource = new StaffPriorityCapKeySourceMock();
    service = new StaffPriorityCapServiceImpl(mockRepo, mockKeySource);
  }

  @IsTest
  private static void getCharterStats_nullCapacityIds_returnsEmptyAndDoesNotQuery() {
    setUp();

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(null, null, null);

    Assert.isTrue(result.isEmpty(), 'Should return an empty list');
    mockRepo.never(mockRepo.method.queryWithBinds());
  }

  @IsTest
  private static void getCharterStats_emptyCapacityIds_returnsEmptyAndDoesNotQuery() {
    setUp();

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(new List<Id>(), null, null);

    Assert.isTrue(result.isEmpty(), 'Should return an empty list');
    mockRepo.never(mockRepo.method.queryWithBinds());
  }

  @IsTest
  private static void getCharterStats_sameStudentTwoSchools_countsOnce() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 200
          )
        }
      )
      .thenReturn(
        new List<AcademicInterest>{ buildPoolRow(appId, charterId), buildPoolRow(appId, charterId) }
      )
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(1, result.size(), 'Should return one Charter');
    Assert.areEqual(
      1,
      result[0].staffApplicantCount,
      'Same student at two schools in the same Charter should count once'
    );
  }

  @IsTest
  private static void getCharterStats_flooredCap_computesMaxAllowedAndToRemove() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    List<Id> appIds = new List<Id>();
    List<AcademicInterest> poolRows = new List<AcademicInterest>();
    for (Integer i = 0; i < 20; i++) {
      Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
      appIds.add(appId);
      poolRows.add(buildPoolRow(appId, charterId));
    }

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 300, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 101
          )
        }
      )
      .thenReturn(poolRows)
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(appIds));

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(1, result.size(), 'Should return one Charter');
    Assert.areEqual(15, result[0].maxAllowed, 'floor(101 * 15 / 100) = 15');
    Assert.areEqual(5, result[0].toRemove, '20 staff applicants - 15 max allowed = 5');
    Assert.areEqual(
      StaffPriorityCapCharterStats.STATUS_OVER,
      result[0].status,
      'Should be Over when toRemove > 0'
    );
  }

  @IsTest
  private static void getCharterStats_charterSeatsBlank_blocksWithMessage() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = null
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(1, result.size(), 'Should still return the Charter row');
    Assert.areEqual(
      StaffPriorityCapCharterStats.STATUS_BLOCKED,
      result[0].status,
      'Blank Charter seats should block'
    );
    Assert.isTrue(result[0].message.contains('Charter A'), 'Message should name the Charter');
  }

  @IsTest
  private static void getCharterStats_learningProgramSeatsZero_blocksWithSchoolMessage() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 0, charterId, 'Inwood 1 Kindergarten')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 200
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(
      StaffPriorityCapCharterStats.STATUS_BLOCKED,
      result[0].status,
      'Zero LearningProgram seats should block'
    );
    Assert.isTrue(
      result[0].message.contains('Inwood 1 Kindergarten'),
      'Message should name the school'
    );
  }

  @IsTest
  private static void getCharterStats_missingCmdtRecord_blocksAllCharters() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(new List<Staff_Priority_Cap_Setting__mdt>())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 200
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(
      StaffPriorityCapCharterStats.STATUS_BLOCKED,
      result[0].status,
      'A missing CMDT record should block with no silent default'
    );
  }

  @IsTest
  private static void getCharterStats_missingCmdtWithNoStaffApplicants_stillBlocks() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    // No staff applicants at all for this Charter.
    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(new List<Staff_Priority_Cap_Setting__mdt>())
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 200
          )
        }
      )
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<Priority_Item__c>());

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(
      1,
      result.size(),
      'A missing CMDT record blocks every selected Charter, even with no staff applicants'
    );
    Assert.areEqual(StaffPriorityCapCharterStats.STATUS_BLOCKED, result[0].status);
  }

  @IsTest
  private static void getCharterStats_blankSeatsWithNoStaffApplicants_stillBlocks() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);

    // CMDT is configured and no staff applicants exist, but the Charter's seats are blank.
    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = null
          )
        }
      )
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<Priority_Item__c>());

    List<StaffPriorityCapCharterStats> result = service.getCharterStats(
      new List<Id>{ capacityId },
      null,
      null
    );

    Assert.areEqual(
      1,
      result.size(),
      'Blank Charter seats block the run even with no staff applicants, instead of being omitted'
    );
    Assert.areEqual(StaffPriorityCapCharterStats.STATUS_BLOCKED, result[0].status);
  }

  @IsTest
  private static void getCharterStats_withDateFilter_passesStartAndEndDateBinds() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Date startDate = Date.newInstance(2026, 1, 1);
    Date endDate = Date.newInstance(2026, 6, 1);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(new List<Account>())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<Priority_Item__c>());

    service.getCharterStats(new List<Id>{ capacityId }, startDate, endDate);

    List<Map<String, Object>> calls = mockRepo.getCalls(mockRepo.method.queryWithBinds());
    Map<String, Object> poolQueryBinds = (Map<String, Object>) calls[3].get('bindMap');
    Assert.areEqual(startDate, poolQueryBinds.get('startDate'), 'Should pass the start date bind');
    Assert.areEqual(endDate, poolQueryBinds.get('endDate'), 'Should pass the end date bind');
  }

  @IsTest
  private static void removeForCharter_nullCharterId_doesNothing() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);

    StaffPriorityCapRemovalResult result = service.removeForCharter(
      null,
      new List<Id>{ capacityId },
      SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType),
      null,
      null
    );

    Assert.areEqual(0, result.removedCount, 'Should remove nothing');
    mockRepo.never(mockRepo.method.queryWithBinds());
  }

  @IsTest
  private static void removeForCharter_blockedCharter_doesNothing() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(15))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = null
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    StaffPriorityCapRemovalResult result = service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType),
      null,
      null
    );

    Assert.areEqual(0, result.removedCount, 'A Blocked Charter should not be removed from');
    mockRepo.never(mockRepo.method.updateSObjects());
  }

  @IsTest
  private static void removeForCharter_secondCallAfterUnderCap_removesZero() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    // A prior call already flagged enough applicants that the Charter is now at or
    // under cap, so a second call must not attempt any further removal.
    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(50))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 4
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }));

    // maxAllowed = floor(4 * 50 / 100) = 2, staffApplicantCount = 1 -> Under, toRemove = 0
    StaffPriorityCapRemovalResult result = service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType),
      null,
      null
    );

    Assert.areEqual(0, result.removedCount, 'A second call once under cap should remove nothing');
    mockRepo.never(mockRepo.method.updateSObjects());
  }

  @IsTest
  private static void removeForCharter_scopesPoolQueryToTheGivenCharter() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(0))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 10
          )
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId, charterId) })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }))
      .thenReturn(
        new List<AcademicInterest>{
          new AcademicInterest(Id = interestId, IndividualApplicationId = appId)
        }
      )
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId }))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(new List<AcademicInterest>());
    mockRepo.when(mockRepo.method.updateSObjects()).thenReturnVoid();
    mockKeySource.when(mockKeySource.method.nextKey()).thenReturn(0.5);

    service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType),
      null,
      null
    );

    List<Map<String, Object>> calls = mockRepo.getCalls(mockRepo.method.queryWithBinds());
    Map<String, Object> poolQueryBinds = (Map<String, Object>) calls[6].get('bindMap');
    Assert.areEqual(
      charterId,
      poolQueryBinds.get('charterId'),
      'The removal pool query must be scoped to the given Charter only'
    );
  }

  @IsTest
  private static void removeForCharter_overCap_removesExactlyNInKeyOrder() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    List<Id> appIds = new List<Id>();
    List<AcademicInterest> statsPoolRows = new List<AcademicInterest>();
    List<AcademicInterest> removalPoolRows = new List<AcademicInterest>();
    for (Integer i = 0; i < 4; i++) {
      Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
      Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
      appIds.add(appId);
      statsPoolRows.add(buildPoolRow(appId, charterId));
      removalPoolRows.add(new AcademicInterest(Id = interestId, IndividualApplicationId = appId));
    }

    // Stats pass (6 queries): 20 seats, 100% cap -> maxAllowed 20, 4 staff applicants -> Under?
    // Use a small cap so toRemove = 2 of the 4 pool applicants.
    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(50))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 4
          )
        }
      )
      .thenReturn(statsPoolRows)
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(buildApprovedPriorityItems(appIds))
      // removeForCharter's own pool query + its approved-staff lookup
      .thenReturn(removalPoolRows)
      .thenReturn(buildApprovedPriorityItems(appIds))
      // removeForCharter's placed-overlap check: no placed students at this Charter
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(new List<AcademicInterest>());
    mockRepo.when(mockRepo.method.updateSObjects()).thenReturnVoid();

    // maxAllowed = floor(4 * 50 / 100) = 2, staffApplicantCount = 4 -> toRemove = 2
    mockKeySource.when(mockKeySource.method.nextKey())
      .thenReturn(0.9)
      .thenReturn(0.1)
      .thenReturn(0.5)
      .thenReturn(0.3);

    StaffPriorityCapRemovalResult result = service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      runLogId,
      null,
      null
    );

    Assert.areEqual(2, result.removedCount, 'Should remove exactly the computed N');
    Assert.areEqual(0, result.residual, 'Pool was large enough, so no residual');

    List<Map<String, Object>> updateCalls = mockRepo.getCalls(mockRepo.method.updateSObjects());
    Assert.areEqual(1, updateCalls.size(), 'Should update once');
    List<SObject> updated = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(2, updated.size(), 'Should flag exactly N AcademicInterests');

    Set<Decimal> orders = new Set<Decimal>();
    for (SObject record : updated) {
      AcademicInterest academicInterest = (AcademicInterest) record;
      Assert.isTrue(
        academicInterest.Staff_Priority_Removed__c,
        'Each removed record should be flagged'
      );
      Assert.areEqual(
        runLogId,
        academicInterest.Staff_Priority_Removed_Run__c,
        'Each removed record should reference the run'
      );
      orders.add(academicInterest.Staff_Priority_Removal_Order__c);
    }
    Assert.areEqual(
      new Set<Decimal>{ 1, 2 },
      orders,
      'Draw order should be assigned 1..N in key order'
    );
  }

  @IsTest
  private static void removeForCharter_poolExhausted_returnsResidual() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    // Two Eligible (removable) pool applicants, plus one already-placed staff applicant
    // from an earlier run. The placed applicant counts toward the cap but cannot be
    // flagged, so the pool runs out before toRemove is satisfied.
    List<Id> eligibleAppIds = new List<Id>();
    List<AcademicInterest> statsEligibleRows = new List<AcademicInterest>();
    List<AcademicInterest> removalPoolRows = new List<AcademicInterest>();
    for (Integer i = 0; i < 2; i++) {
      Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
      Id interestId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
      eligibleAppIds.add(appId);
      statsEligibleRows.add(buildPoolRow(appId, charterId));
      removalPoolRows.add(new AcademicInterest(Id = interestId, IndividualApplicationId = appId));
    }
    Id placedAppId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    List<Id> allStaffAppIds = new List<Id>(eligibleAppIds);
    allStaffAppIds.add(placedAppId);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(0))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 10
          )
        }
      )
      .thenReturn(statsEligibleRows)
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(placedAppId, charterId) })
      .thenReturn(buildApprovedPriorityItems(allStaffAppIds))
      .thenReturn(removalPoolRows)
      .thenReturn(buildApprovedPriorityItems(eligibleAppIds))
      // removeForCharter's placed-overlap check: the placed applicant isn't in the
      // Eligible pool, so excluding it has no effect here (covered by its own test)
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(placedAppId, charterId) });
    mockRepo.when(mockRepo.method.updateSObjects()).thenReturnVoid();

    mockKeySource.when(mockKeySource.method.nextKey()).thenReturn(0.5).thenReturn(0.2);

    // maxAllowed = floor(10 * 0 / 100) = 0, staffApplicantCount = 3 -> toRemove = 3,
    // but only 2 Eligible pool applicants can actually be flagged.
    StaffPriorityCapRemovalResult result = service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      runLogId,
      null,
      null
    );

    Assert.areEqual(2, result.removedCount, 'Should remove everything the pool has');
    Assert.areEqual(1, result.residual, 'Residual when the pool is exhausted short of toRemove');
  }

  @IsTest
  private static void removeForCharter_poolStudentAlsoPlacedAtCharter_excludedFromDraw() {
    setUp();
    Id capacityId = SObjectIds.generateFakeId(Schema.Lottery_Capacity__c.SObjectType);
    Id charterId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id timelineId = SObjectIds.generateFakeId(Schema.ApplicationTimeline.SObjectType);
    Id runLogId = SObjectIds.generateFakeId(Schema.Lottery_Run_Log__c.SObjectType);

    // appId1 has BOTH an Eligible pool AcademicInterest (a second school in this Charter)
    // and a placed one (Pre-Offer at a different school in the same Charter). Removing
    // the Eligible one would not reduce the Charter's count, so appId1 must be excluded
    // from the draw entirely; only appId2 is genuinely reducible.
    Id appId1 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id appId2 = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id interestId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id interestId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    mockRepo.when(mockRepo.method.queryWithBinds())
      .thenReturn(buildCapSettingList(0))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = charterId,
            Name = 'Charter A',
            Total_Available_Seats_for_School_Year__c = 10
          )
        }
      )
      .thenReturn(
        new List<AcademicInterest>{
          buildPoolRow(appId1, charterId),
          buildPoolRow(appId2, charterId)
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId1, charterId) })
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId1, appId2 }))
      .thenReturn(
        new List<AcademicInterest>{
          new AcademicInterest(Id = interestId1, IndividualApplicationId = appId1),
          new AcademicInterest(Id = interestId2, IndividualApplicationId = appId2)
        }
      )
      .thenReturn(buildApprovedPriorityItems(new List<Id>{ appId1, appId2 }))
      .thenReturn(
        new List<Lottery_Capacity__c>{
          buildCapacity(capacityId, timelineId, 100, charterId, 'School A')
        }
      )
      .thenReturn(new List<AcademicInterest>{ buildPoolRow(appId1, charterId) });
    mockRepo.when(mockRepo.method.updateSObjects()).thenReturnVoid();
    mockKeySource.when(mockKeySource.method.nextKey()).thenReturn(0.5);

    // maxAllowed = floor(10 * 0 / 100) = 0, staffApplicantCount = 2 (distinct) -> toRemove = 2,
    // but appId1 is excluded from the draw, so only appId2 can actually be removed.
    StaffPriorityCapRemovalResult result = service.removeForCharter(
      charterId,
      new List<Id>{ capacityId },
      runLogId,
      null,
      null
    );

    Assert.areEqual(1, result.removedCount, 'Only the non-placed student should be removed');
    Assert.areEqual(1, result.residual, 'The placed student cannot be reduced, leaving a residual');

    List<Map<String, Object>> updateCalls = mockRepo.getCalls(mockRepo.method.updateSObjects());
    List<SObject> updated = (List<SObject>) updateCalls[0].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should flag exactly one AcademicInterest');
    Assert.areEqual(
      appId2,
      ((AcademicInterest) updated[0]).IndividualApplicationId,
      'The flagged record must belong to the non-placed student'
    );
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    StaffPriorityCapServiceImpl defaultService = new StaffPriorityCapServiceImpl();
    Assert.isNotNull(defaultService, 'Should create instance with default constructor');
  }

  private static List<Staff_Priority_Cap_Setting__mdt> buildCapSettingList(Decimal capPercent) {
    return new List<Staff_Priority_Cap_Setting__mdt>{
      new Staff_Priority_Cap_Setting__mdt(Cap_Percent__c = capPercent)
    };
  }

  private static List<Priority_Item__c> buildApprovedPriorityItems(List<Id> applicationIds) {
    List<Priority_Item__c> items = new List<Priority_Item__c>();
    for (Id applicationId : applicationIds) {
      items.add(new Priority_Item__c(Related_Application__c = applicationId));
    }
    return items;
  }

  private static Lottery_Capacity__c buildCapacity(
    Id capacityId,
    Id timelineId,
    Decimal learningProgramSeats,
    Id charterId,
    String schoolName
  ) {
    String jsonStr = JSON.serialize(
      new Map<String, Object>{
        'attributes' => new Map<String, Object>{ 'type' => 'Lottery_Capacity__c' },
        'Id' => capacityId,
        'Program_Term_Application_Timeline__r' => new Map<String, Object>{
          'attributes' => new Map<String, Object>{ 'type' => 'ProgramTermApplnTimeline' },
          'ApplicationTimelineId' => timelineId,
          'LearningProgram' => new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'LearningProgram' },
            'Total_Available_Seats_for_School_Year__c' => learningProgramSeats,
            'School__r' => new Map<String, Object>{
              'attributes' => new Map<String, Object>{ 'type' => 'Account' },
              'ParentId' => charterId,
              'Zeta_School_Name__c' => schoolName
            }
          }
        }
      }
    );
    return (Lottery_Capacity__c) JSON.deserialize(jsonStr, Lottery_Capacity__c.class);
  }

  private static AcademicInterest buildPoolRow(Id applicationId, Id charterId) {
    String jsonStr = JSON.serialize(
      new Map<String, Object>{
        'attributes' => new Map<String, Object>{ 'type' => 'AcademicInterest' },
        'IndividualApplicationId' => applicationId,
        'Lottery_Capacity__r' => new Map<String, Object>{
          'attributes' => new Map<String, Object>{ 'type' => 'Lottery_Capacity__c' },
          'Program_Term_Application_Timeline__r' => new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'ProgramTermApplnTimeline' },
            'LearningProgram' => new Map<String, Object>{
              'attributes' => new Map<String, Object>{ 'type' => 'LearningProgram' },
              'School__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                'ParentId' => charterId
              }
            }
          }
        }
      }
    );
    return (AcademicInterest) JSON.deserialize(jsonStr, AcademicInterest.class);
  }

  @IsTest
  private static void keySourceImpl_nextKey_returnsValueInUnitInterval() {
    Decimal key = new StaffPriorityCapKeySourceImpl().nextKey();

    Assert.isTrue(key >= 0 && key < 1, 'Key should be in [0, 1)');
  }
}