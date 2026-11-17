/**
 * Tests for {@link CharterRollupSchedulable}.
 */
@IsTest
private class CharterRollupSchedulableTest {
  @IsTest
  private static void execute_enqueuesCharterRollupBatch() {
    Test.startTest();
    new CharterRollupSchedulable().execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'CharterRollupBatch' AND JobType = 'BatchApex'
      ],
      'Should enqueue CharterRollupBatch'
    );
  }
}