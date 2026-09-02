/**
 * Tests for {@link LotteryRollbackResult}.
 */
@IsTest(IsParallel=true)
private class LotteryRollbackResultTest {
  @IsTest
  private static void constructor_default_initializesWithZeros() {
    LotteryRollbackResult result = new LotteryRollbackResult();

    Assert.areEqual(0, result.capacitiesUnlinked, 'capacitiesUnlinked should default to 0');
    Assert.areEqual(0, result.academicInterestsReset, 'academicInterestsReset should default to 0');
    Assert.areEqual(0, result.waitlistHistoryDeleted, 'waitlistHistoryDeleted should default to 0');
    Assert.areEqual(0, result.runResultsDeleted, 'runResultsDeleted should default to 0');
  }

  @IsTest
  private static void getTotalRecordsAffected_withValues_returnsSumOfAllFields() {
    LotteryRollbackResult result = new LotteryRollbackResult();
    result.capacitiesUnlinked = 2;
    result.academicInterestsReset = 10;
    result.waitlistHistoryDeleted = 3;
    result.runResultsDeleted = 5;

    Integer total = result.getTotalRecordsAffected();

    Assert.areEqual(20, total, 'Should return sum of all fields');
  }

  @IsTest
  private static void getTotalRecordsAffected_withDefaults_returnsZero() {
    LotteryRollbackResult result = new LotteryRollbackResult();

    Integer total = result.getTotalRecordsAffected();

    Assert.areEqual(0, total, 'Should return 0 for default values');
  }
}