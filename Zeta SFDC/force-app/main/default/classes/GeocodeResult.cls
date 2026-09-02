/**
 * Result of a {@link GoogleMapsApi#geocode} call. Immutable.
 *
 * On {@link GeocodeStatus#OK}, {@link #latitude} and {@link #longitude} are
 * populated. On every other status they are {@code null} and the caller
 * should branch on {@link #status}.
 */
public with sharing class GeocodeResult {
  public final Decimal latitude;
  public final Decimal longitude;
  public final GeocodeStatus status;
  public final String formattedAddress;
  public final String placeId;

  public GeocodeResult(
    Decimal latitude,
    Decimal longitude,
    GeocodeStatus status,
    String formattedAddress,
    String placeId
  ) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.status = status;
    this.formattedAddress = formattedAddress;
    this.placeId = placeId;
  }
}