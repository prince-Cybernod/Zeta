/**
 * SFR-314: tests for LeadMarketRoundRobin. Turn-taking uses unsaved users (no licences needed);
 * the market search runs against the org's real lead owners.
 */
@IsTest
private class LeadMarketRoundRobinTest {
  private static final Decimal LEAD_CAP = 30;

  private static User unsavedUser(Integer n, Decimal openLeads) {
    return new User(Id = Id.valueOf('005' + String.valueOf(n).leftPad(12, '0')), Open_Lead_Count__c = openLeads);
  }

  @IsTest
  static void takeTurn_sharesLeadsThatArriveTogether() {
    User a = unsavedUser(1, 0);
    User b = unsavedUser(2, 0);
    User c = unsavedUser(3, 0);
    List<User> line = new List<User>{ a, b, c };

    List<Id> picks = new List<Id>();
    for (Integer i = 0; i < 6; i++) {
      picks.add(LeadMarketRoundRobin.takeTurn(line, LEAD_CAP));
    }

    Assert.areEqual(new List<Id>{ a.Id, b.Id, c.Id, a.Id, b.Id, c.Id }, picks, 'Leads go round in line order');
  }

  @IsTest
  static void takeTurn_skipsPeopleOverTheOpenLeadLimit() {
    User over = unsavedUser(1, 31);
    User atLimit = unsavedUser(2, 30);
    User free = unsavedUser(3, 5);
    List<User> line = new List<User>{ over, atLimit, free };

    Assert.areEqual(atLimit.Id, LeadMarketRoundRobin.takeTurn(line, LEAD_CAP), 'Exactly at the limit still gets a lead');
    Assert.areEqual(free.Id, LeadMarketRoundRobin.takeTurn(line, LEAD_CAP), 'Over the limit is skipped');
    Assert.areEqual(free.Id, LeadMarketRoundRobin.takeTurn(line, LEAD_CAP), 'Someone who just went over is skipped');
  }

  @IsTest
  static void takeTurn_returnsNullWhenEveryoneIsOverTheLimit() {
    List<User> line = new List<User>{ unsavedUser(1, 31), unsavedUser(2, 40) };

    Assert.isNull(LeadMarketRoundRobin.takeTurn(line, LEAD_CAP), 'Nobody is free, so the flow uses the normal rotation');
  }

  @IsTest
  static void pickOwners_givesLeadsArrivingTogetherToDifferentQueensOwners() {
    List<User> team = LeadMarketRoundRobin.leadOwnersInMarket('Queens');
    for (User owner : team) {
      Assert.isTrue(owner.Schools_Market_Owned__c.contains('Queens'), 'Only Queens lead owners');
    }
    LeadMarketRoundRobin.Request request = new LeadMarketRoundRobin.Request();
    request.market = 'Queens';
    request.leadCap = 1000000; // the team's real open-lead counts must not decide this test

    List<LeadMarketRoundRobin.Result> results = LeadMarketRoundRobin.pickOwners(
      new List<LeadMarketRoundRobin.Request>{ request, request }
    );

    Set<Id> teamIds = new Map<Id, User>(team).keySet();
    Assert.areEqual(2, results.size(), 'One result per lead, in order');
    for (LeadMarketRoundRobin.Result result : results) {
      Assert.areEqual(!team.isEmpty(), teamIds.contains(result.ownerId), 'Picks come from the Queens team');
    }
    Assert.areEqual(team.size() > 1, results[0].ownerId != results[1].ownerId, 'Two leads at once go to two people');
  }
}
