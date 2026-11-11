/**
 * Real-DML tests for open Lead count recounting. Not parallel because these update the running
 * user's own User row.
 */
@IsTest(IsParallel=false)
private class OpenLeadCountRealDmlTest {
  @IsTest
  private static void recalculate_withRealLeadDml_stampsRealAggregateCountOnUser() {
    Id currentUserId = UserInfo.getUserId();
    update new User(Id = currentUserId, Open_Lead_Count__c = 42);
    Lead lead = new Lead(
      LastName = 'OpenLeadCountRealDmlTest',
      Company = 'OpenLeadCountRealDmlTest',
      Phone = '5551234567',
      Status = 'Open – Working',
      OwnerId = currentUserId
    );
    insert lead;
    // Lead assignment automation reassigns a new Lead to a queue regardless of the insert's
    // OwnerId, so reassign it back.
    update new Lead(Id = lead.Id, OwnerId = currentUserId);

    Test.startTest();
    new OpenLeadCountRecalculator()
      .recalculate(new Set<Id>{ currentUserId }, new Map<Id, Datetime>());
    Test.stopTest();

    User updatedUser = [SELECT Open_Lead_Count__c FROM User WHERE Id = :currentUserId];
    Assert.areEqual(
      1,
      updatedUser.Open_Lead_Count__c,
      'A real open Lead owned by this User should produce a real aggregate count of 1'
    );
  }

  @IsTest
  private static void leadInsert_publishesEventThatRecalculatesCountAndStampsLastLeadAssigned() {
    Id currentUserId = UserInfo.getUserId();
    update new User(Id = currentUserId, Open_Lead_Count__c = 42, Last_Lead_Assigned__c = null);
    Datetime before = System.now();
    Lead lead = new Lead(
      LastName = 'OpenLeadCountRealDmlTest',
      Company = 'OpenLeadCountRealDmlTest',
      Phone = '5551234567',
      Status = 'Open – Working',
      OwnerId = currentUserId
    );
    insert lead;
    // Lead assignment automation reassigns a new Lead to a queue regardless of the insert's
    // OwnerId, so reassign it back.
    update new Lead(Id = lead.Id, OwnerId = currentUserId);

    Test.getEventBus().deliver();

    User updatedUser = [
      SELECT Open_Lead_Count__c, Last_Lead_Assigned__c
      FROM User
      WHERE Id = :currentUserId
    ];
    Assert.areEqual(
      1,
      updatedUser.Open_Lead_Count__c,
      'Delivering the event published by the Lead reassignment should produce a real aggregate count of 1'
    );
    Assert.isNotNull(
      updatedUser.Last_Lead_Assigned__c,
      'Delivering the event should stamp Last_Lead_Assigned__c from the owner assignment'
    );
    Assert.isTrue(
      updatedUser.Last_Lead_Assigned__c >= before.addSeconds(-1),
      'The stamp should reflect the moment of the owner assignment, not a stale value'
    );
  }
}