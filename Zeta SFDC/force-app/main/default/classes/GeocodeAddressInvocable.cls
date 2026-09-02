/**
 * Flow-invocable wrapper around {@link GoogleMapsApi#geocode} that returns the
 * latitude / longitude for a free-form address. Bulk-safe: one HTTP callout
 * per Request (Google's Geocoding API is single-address-per-call). Subject to
 * the standard 100-callouts-per-transaction governor limit.
 *
 * Failure handling: any non-OK {@link GeocodeStatus}, null result, or blank
 * input throws {@link GeocodeFailureException}. This surfaces in Flow as a
 * fault path the admin can route however they like.
 */
public with sharing class GeocodeAddressInvocable {
  private final GoogleMapsApi googleMapsApi;

  public GeocodeAddressInvocable() {
    this(new GoogleMapsClient());
  }

  @TestVisible
  private GeocodeAddressInvocable(GoogleMapsApi googleMapsApi) {
    this.googleMapsApi = googleMapsApi;
  }

  @InvocableMethod(
    Label='Geocode Address'
    Description='Resolves a free-form address to latitude and longitude via Google Maps. Throws on any failure so a Flow fault path can handle it.'
    Category='Google Maps'
    CallOut=true
  )
  public static List<Result> geocodeAddresses(List<Request> requests) {
    return new GeocodeAddressInvocable().geocodeAll(requests);
  }

  @TestVisible
  private List<Result> geocodeAll(List<Request> requests) {
    List<Result> results = new List<Result>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }

    for (Request request : requests) {
      results.add(geocodeOne(request));
    }
    return results;
  }

  private Result geocodeOne(Request request) {
    String address = request?.address;
    if (String.isBlank(address)) {
      throw new GeocodeFailureException('address must not be blank');
    }

    GeocodeResult geocoded = googleMapsApi.geocode(address);
    if (geocoded == null || geocoded.status != GeocodeStatus.OK) {
      GeocodeStatus status = geocoded == null ? GeocodeStatus.UNKNOWN_ERROR : geocoded.status;
      throw new GeocodeFailureException(
        String.format(
          'Failed to geocode address "{0}": {1}',
          new List<Object>{ address, status }
        )
      );
    }

    Result result = new Result();
    result.latitude = geocoded.latitude;
    result.longitude = geocoded.longitude;
    return result;
  }

  public class Request {
    @InvocableVariable(
      Label='Address'
      Description='Free-form postal address to geocode (e.g. "350 Fifth Ave, New York, NY").'
      Required=true
    )
    public String address;
  }

  public class Result {
    @InvocableVariable(
      Label='Latitude'
      Description='Latitude returned by Google Maps. Populated only on success.'
    )
    public Decimal latitude;

    @InvocableVariable(
      Label='Longitude'
      Description='Longitude returned by Google Maps. Populated only on success.'
    )
    public Decimal longitude;
  }
}