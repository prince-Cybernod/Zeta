/**
 * Flow-invocable action that checks if provided ranking values are unique.
 * Used in screen flows to validate School_Rank__c entries before saving.
 */
public with sharing class CheckUniqueRankings {
  public class Request {
    @InvocableVariable(
      Label='Ranking Values'
      Description='Collection of ranking numbers to check for uniqueness'
      Required=true
    )
    public List<Decimal> rankings;
  }

  public class Result {
    @InvocableVariable(
      Label='Has Duplicates'
      Description='True if duplicate ranking values were found'
    )
    public Boolean hasDuplicates;
  }

  @InvocableMethod(
    Label='Check Unique Rankings'
    Description='Checks if the provided ranking values are unique. Returns true if duplicates exist.'
    Category='Validation'
  )
  public static List<Result> checkUnique(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request request : requests) {
      Result result = new Result();
      result.hasDuplicates = hasDuplicates(request.rankings);
      results.add(result);
    }
    return results;
  }

  private static Boolean hasDuplicates(List<Decimal> rankings) {
    if (rankings == null || rankings.isEmpty()) {
      return false;
    }

    // Use Set<Integer> to avoid Decimal scale-sensitivity in Set hashing.
    // Decimal 2.00 and Decimal 2 are equal with == but hash differently
    // in Set<Decimal>, so duplicates go undetected when scales vary.
    Set<Integer> seen = new Set<Integer>();
    for (Decimal rank : rankings) {
      if (rank == null) {
        continue;
      }
      if (!seen.add(rank.intValue())) {
        return true;
      }
    }

    return false;
  }
}