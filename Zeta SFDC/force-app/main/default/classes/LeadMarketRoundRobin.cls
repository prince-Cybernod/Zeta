/**
 * SFR-314: gives leads to one market's lead owners in turn (the flow passes "Queens").
 * Salesforce sends every lead in a batch in one call, so leads arriving together are shared out.
 * Same rules as the flow's normal rotation; reads users only, in system context like the flow.
 */
public without sharing class LeadMarketRoundRobin {
  public class Request {
    @InvocableVariable(label='Market name contains' required=true)
    public String market;
    @InvocableVariable(label='Open lead limit' required=true)
    public Decimal leadCap;
  }

  public class Result {
    @InvocableVariable(label='Owner Id')
    public Id ownerId;
  }

  @InvocableMethod(label='Pick Lead Owner in Market')
  public static List<Result> pickOwners(List<Request> requests) {
    // All requests come from the same flow step, so they share one market and one limit.
    List<User> line = leadOwnersInMarket(requests[0].market);
    List<Result> results = new List<Result>();
    for (Request request : requests) {
      Result result = new Result();
      result.ownerId = takeTurn(line, request.leadCap);
      results.add(result);
    }
    return results;
  }

  // Longest since their last lead first, then fewest open leads (the flow's own sort).
  @TestVisible
  private static List<User> leadOwnersInMarket(String market) {
    List<User> team = new List<User>();
    for (User owner : [
      SELECT Id, Schools_Market_Owned__c, Open_Lead_Count__c
      FROM User
      WHERE IsActive = TRUE AND Lead_Owner__c = TRUE
      ORDER BY Last_Lead_Assigned__c ASC NULLS FIRST, Open_Lead_Count__c ASC NULLS FIRST
    ]) {
      if (owner.Schools_Market_Owned__c?.contains(market) == true) {
        team.add(owner);
      }
    }
    return team;
  }

  // The first person in line within the limit gets the lead and moves to the back of the line.
  @TestVisible
  private static Id takeTurn(List<User> line, Decimal leadCap) {
    for (Integer i = 0; i < line.size(); i++) {
      User owner = line[i];
      Decimal openLeads = owner.Open_Lead_Count__c ?? 0;
      if (openLeads <= leadCap) {
        owner.Open_Lead_Count__c = openLeads + 1; // in memory only: counts this batch
        line.add(line.remove(i));
        return owner.Id;
      }
    }
    return null;
  }
}
