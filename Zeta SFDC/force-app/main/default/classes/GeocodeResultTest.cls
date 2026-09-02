/**
 * Tests for {@link GeocodeResult}. Single test method — the DTO is just a
 * constructor and five public final fields; one assertion per field is
 * enough to lock the wiring in and clear the per-class coverage bar.
 */
@IsTest(IsParallel=true)
private class GeocodeResultTest {
  @IsTest
  private static void constructor_assignsAllFields() {
    GeocodeResult result = new GeocodeResult(
      40.7484,
      -73.9857,
      GeocodeStatus.OK,
      '350 5th Ave, New York, NY 10118, USA',
      'ChIJaXQRs6lZwokRY6VAvVlNXc8'
    );

    Assert.areEqual(40.7484, result.latitude, 'latitude');
    Assert.areEqual(-73.9857, result.longitude, 'longitude');
    Assert.areEqual(GeocodeStatus.OK, result.status, 'status');
    Assert.areEqual(
      '350 5th Ave, New York, NY 10118, USA',
      result.formattedAddress,
      'formattedAddress'
    );
    Assert.areEqual('ChIJaXQRs6lZwokRY6VAvVlNXc8', result.placeId, 'placeId');
  }
}