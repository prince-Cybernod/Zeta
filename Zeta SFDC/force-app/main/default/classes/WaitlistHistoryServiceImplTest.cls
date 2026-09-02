/**
 * Tests for {@link WaitlistHistoryServiceImpl}.
 */
@IsTest(IsParallel=true)
private class WaitlistHistoryServiceImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final WaitlistHistoryServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new WaitlistHistoryServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void createHistoryRecords_withStatusChange_createsHistoryRecord() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Eligible',
      Waitlist_Position__c = null,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = null,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>{
      recordId => oldRecord
    };
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord };

    MOCK_REPO.when(MOCK_REPO.method.insertSObjects()).thenReturnVoid();

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    List<Map<String, Object>> insertCalls = MOCK_REPO.getCalls(MOCK_REPO.method.insertSObjects());
    Assert.areEqual(1, insertCalls.size(), 'Should insert history records');

    List<SObject> insertedRecords = (List<SObject>) insertCalls[0].get('sobjects');
    Assert.areEqual(1, insertedRecords.size(), 'Should insert one history record');

    Waitlist_Movement_History__c history = (Waitlist_Movement_History__c) insertedRecords[0];
    Assert.areEqual(recordId, history.School_Application__c, 'Should link to AcademicInterest');
    Assert.areEqual(2, history.Previous_Priority_Group__c, 'Should capture old priority');
    Assert.areEqual(2, history.New_Priority_Group__c, 'Should capture new priority');
    Assert.areEqual(42, history.Lottery_Number__c, 'Should capture lottery number');
    Assert.isTrue(
      history.Change_Reason__c.contains('Status'),
      'Should include status change reason'
    );
  }

  @IsTest
  private static void createHistoryRecords_withPositionChange_createsHistoryRecord() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 3,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>{
      recordId => oldRecord
    };
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord };

    MOCK_REPO.when(MOCK_REPO.method.insertSObjects()).thenReturnVoid();

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    List<Map<String, Object>> insertCalls = MOCK_REPO.getCalls(MOCK_REPO.method.insertSObjects());
    Assert.areEqual(1, insertCalls.size(), 'Should insert history records');

    List<SObject> insertedRecords = (List<SObject>) insertCalls[0].get('sobjects');
    Waitlist_Movement_History__c history = (Waitlist_Movement_History__c) insertedRecords[0];
    Assert.areEqual(5, history.Previous_Waitlist_Number__c, 'Should capture old position');
    Assert.areEqual(3, history.New_Waitlist_Number__c, 'Should capture new position');
    Assert.isTrue(
      history.Change_Reason__c.contains('Position'),
      'Should include position change reason'
    );
  }

  @IsTest
  private static void createHistoryRecords_withPriorityChange_createsHistoryRecord() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 3,
      Randomized_Sort_Key__c = 42
    );

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 1,
      Randomized_Sort_Key__c = 42
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>{
      recordId => oldRecord
    };
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord };

    MOCK_REPO.when(MOCK_REPO.method.insertSObjects()).thenReturnVoid();

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    List<Map<String, Object>> insertCalls = MOCK_REPO.getCalls(MOCK_REPO.method.insertSObjects());
    List<SObject> insertedRecords = (List<SObject>) insertCalls[0].get('sobjects');
    Waitlist_Movement_History__c history = (Waitlist_Movement_History__c) insertedRecords[0];
    Assert.areEqual(3, history.Previous_Priority_Group__c, 'Should capture old priority');
    Assert.areEqual(1, history.New_Priority_Group__c, 'Should capture new priority');
    Assert.isTrue(
      history.Change_Reason__c.contains('Priority Group'),
      'Should include priority change reason'
    );
  }

  @IsTest
  private static void createHistoryRecords_withNoChange_doesNotCreateHistoryRecord() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 2,
      Randomized_Sort_Key__c = 42
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>{
      recordId => oldRecord
    };
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord };

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    MOCK_REPO.never(MOCK_REPO.method.insertSObjects());
  }

  @IsTest
  private static void createHistoryRecords_withMultipleRecords_handlesInBulk() {
    Id recordId1 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id recordId2 = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord1 = new AcademicInterest(
      Id = recordId1,
      Status = 'Eligible',
      Waitlist_Position__c = null,
      Current_Priority_Group__c = 2
    );
    AcademicInterest oldRecord2 = new AcademicInterest(
      Id = recordId2,
      Status = 'Eligible',
      Waitlist_Position__c = null,
      Current_Priority_Group__c = 3
    );

    AcademicInterest newRecord1 = new AcademicInterest(
      Id = recordId1,
      Status = 'Waitlisted',
      Waitlist_Position__c = 1,
      Current_Priority_Group__c = 2
    );
    AcademicInterest newRecord2 = new AcademicInterest(
      Id = recordId2,
      Status = 'Waitlisted',
      Waitlist_Position__c = 2,
      Current_Priority_Group__c = 3
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>{
      recordId1 => oldRecord1,
      recordId2 => oldRecord2
    };
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord1, newRecord2 };

    MOCK_REPO.when(MOCK_REPO.method.insertSObjects()).thenReturnVoid();

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    List<Map<String, Object>> insertCalls = MOCK_REPO.getCalls(MOCK_REPO.method.insertSObjects());
    Assert.areEqual(1, insertCalls.size(), 'Should insert in single bulk operation');

    List<SObject> insertedRecords = (List<SObject>) insertCalls[0].get('sobjects');
    Assert.areEqual(2, insertedRecords.size(), 'Should insert two history records');
  }

  @IsTest
  private static void createHistoryRecords_withNullNewRecords_doesNothing() {
    SERVICE.createHistoryRecords(new Map<Id, AcademicInterest>(), null);
    MOCK_REPO.never(MOCK_REPO.method.insertSObjects());
  }

  @IsTest
  private static void createHistoryRecords_withEmptyNewRecords_doesNothing() {
    SERVICE.createHistoryRecords(new Map<Id, AcademicInterest>(), new List<AcademicInterest>());
    MOCK_REPO.never(MOCK_REPO.method.insertSObjects());
  }

  @IsTest
  private static void createHistoryRecords_withMissingOldRecord_skipsRecord() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 1,
      Current_Priority_Group__c = 2
    );

    Map<Id, AcademicInterest> oldRecordsById = new Map<Id, AcademicInterest>();
    List<AcademicInterest> newRecords = new List<AcademicInterest>{ newRecord };

    SERVICE.createHistoryRecords(oldRecordsById, newRecords);

    MOCK_REPO.never(MOCK_REPO.method.insertSObjects());
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    WaitlistHistoryServiceImpl service = new WaitlistHistoryServiceImpl();
    Assert.isNotNull(service, 'Should create instance with default constructor');
  }

  @IsTest
  private static void buildHistoryRecord_setsAllFields() {
    Id recordId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest oldRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Eligible',
      Waitlist_Position__c = null,
      Current_Priority_Group__c = 3,
      Randomized_Sort_Key__c = 77
    );

    AcademicInterest newRecord = new AcademicInterest(
      Id = recordId,
      Status = 'Waitlisted',
      Waitlist_Position__c = 5,
      Current_Priority_Group__c = 1,
      Randomized_Sort_Key__c = 77
    );

    Waitlist_Movement_History__c history = WaitlistHistoryServiceImpl.buildHistoryRecord(
      oldRecord,
      newRecord
    );

    Assert.areEqual(recordId, history.School_Application__c, 'School_Application__c should match');
    Assert.areEqual(
      null,
      history.Previous_Waitlist_Number__c,
      'Previous_Waitlist_Number__c should match'
    );
    Assert.areEqual(5, history.New_Waitlist_Number__c, 'New_Waitlist_Number__c should match');
    Assert.areEqual(
      3,
      history.Previous_Priority_Group__c,
      'Previous_Priority_Group__c should match'
    );
    Assert.areEqual(1, history.New_Priority_Group__c, 'New_Priority_Group__c should match');
    Assert.areEqual(77, history.Lottery_Number__c, 'Lottery_Number__c should match');
    Assert.isNotNull(history.Changed_On__c, 'Changed_On__c should be set');
    Assert.isTrue(history.Change_Reason__c.contains('Status'), 'Should include status change');
    Assert.isTrue(
      history.Change_Reason__c.contains('Priority Group'),
      'Should include priority change'
    );
    Assert.isTrue(history.Change_Reason__c.contains('Position'), 'Should include position change');
  }
}