/**
 * Tests for {@link CheckUniqueRankings}.
 */
@IsTest(IsParallel=true)
private class CheckUniqueRankingsTest {
  @IsTest
  private static void checkUnique_withNullRankings_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = null;

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withEmptyRankings_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>();

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withUniqueValues_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 1, 2, 3 };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withDuplicateValues_returnsTrue() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 1, 2, 1 };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(true, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withNullsSkipped_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 1, null, 2, null };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withNullsAndDuplicates_returnsTrue() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 1, null, 1 };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(true, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withSingleValue_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 1 };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withMixedDecimalScales_returnsTrue() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ 2.00, 2, 3, 4 };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(true, results[0].hasDuplicates);
  }

  @IsTest
  private static void checkUnique_withAllNulls_returnsFalse() {
    CheckUniqueRankings.Request request = new CheckUniqueRankings.Request();
    request.rankings = new List<Decimal>{ null, null };

    List<CheckUniqueRankings.Result> results = CheckUniqueRankings.checkUnique(
      new List<CheckUniqueRankings.Request>{ request }
    );

    Assert.areEqual(false, results[0].hasDuplicates);
  }
}