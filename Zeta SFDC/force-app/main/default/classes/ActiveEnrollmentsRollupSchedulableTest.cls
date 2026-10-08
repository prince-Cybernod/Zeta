/**
 * Tests for {@link ActiveEnrollmentsRollupSchedulable}.
 */
@IsTest
private class ActiveEnrollmentsRollupSchedulableTest {
  @IsTest
  private static void execute_enqueuesActiveEnrollmentsRollupBatch() {
    Test.startTest();
    new ActiveEnrollmentsRollupSchedulable().execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'ActiveEnrollmentsRollupBatch' AND JobType = 'BatchApex'
      ],
      'Should enqueue ActiveEnrollmentsRollupBatch'
    );
  }
}