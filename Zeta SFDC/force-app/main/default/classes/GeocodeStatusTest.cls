/**
 * Tests for {@link GeocodeStatus}. Single test — the enum has no behavior,
 * so we just lock the value set in place. Adding or renaming a value should
 * force the producer (GoogleMapsClient) and consumers to update intentionally.
 */
@IsTest(IsParallel=true)
private class GeocodeStatusTest {
  @IsTest
  private static void values_areTheExpectedSet() {
    Set<String> actual = new Set<String>();
    for (GeocodeStatus value : GeocodeStatus.values()) {
      actual.add(value.name());
    }

    Assert.areEqual(
      new Set<String>{
        'OK',
        'ZERO_RESULTS',
        'OVER_QUERY_LIMIT',
        'REQUEST_DENIED',
        'INVALID_REQUEST',
        'UNKNOWN_ERROR'
      },
      actual,
      'GeocodeStatus value set'
    );
  }
}