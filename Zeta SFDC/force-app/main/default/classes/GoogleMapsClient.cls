/**
 * Apex client for Google Maps Geocoding API v4. Authenticates via header
 * merge field ({@code X-Goog-Api-Key}) resolved at callout time from the
 * {@code Google_Maps_Geocoding} named credential's principal authentication
 * parameters — the API key value is never present in source.
 */
public with sharing class GoogleMapsClient implements GoogleMapsApi {
  private static final String ENDPOINT_BASE = 'callout:Google_Maps_Geocoding/v4/geocode/address/';
  private static final String API_KEY_HEADER = 'X-Goog-Api-Key';
  private static final String API_KEY_MERGE_FIELD = '{!$Credential.Google_Maps_Geocoding.ApiKey}';
  private static final Set<Integer> ACCEPTED_STATUS_CODES = new Set<Integer>{
    200,
    400,
    401,
    403,
    404,
    429
  };

  private final HttpRequestSender httpRequestSender;

  public GoogleMapsClient() {
    this(new HttpRequestSenderImpl());
  }

  @TestVisible
  private GoogleMapsClient(HttpRequestSender httpRequestSender) {
    this.httpRequestSender = httpRequestSender;
  }

  public GeocodeResult geocode(String address) {
    Preconditions.checkArgument(String.isNotBlank(address), 'address must not be blank');

    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setMethod(HttpMethod.HTTP_GET)
      .setEndpoint(ENDPOINT_BASE + EncodingUtil.urlEncode(address, 'UTF-8'))
      .addHeader(API_KEY_HEADER, API_KEY_MERGE_FIELD)
      .build();

    HttpResponse response = httpRequestSender.send(request, ACCEPTED_STATUS_CODES);
    return toGeocodeResult(response);
  }

  private static GeocodeResult toGeocodeResult(HttpResponse response) {
    Integer statusCode = response.getStatusCode();
    if (statusCode == 200) {
      return parseOkResponse(response.getBody());
    } else if (statusCode == 400) {
      return failedResult(GeocodeStatus.INVALID_REQUEST);
    } else if (statusCode == 401 || statusCode == 403) {
      return failedResult(GeocodeStatus.REQUEST_DENIED);
    } else if (statusCode == 429) {
      return failedResult(GeocodeStatus.OVER_QUERY_LIMIT);
    }
    return failedResult(GeocodeStatus.UNKNOWN_ERROR);
  }

  private static GeocodeResult parseOkResponse(String body) {
    Map<String, Object> root;
    try {
      root = (Map<String, Object>) JSON.deserializeUntyped(body);
    } catch (Exception e) {
      return failedResult(GeocodeStatus.UNKNOWN_ERROR);
    }

    List<Object> results = (List<Object>) root.get('results');
    if (results == null || results.isEmpty()) {
      return failedResult(GeocodeStatus.ZERO_RESULTS);
    }

    Map<String, Object> first = (Map<String, Object>) results[0];
    Map<String, Object> location = (Map<String, Object>) first.get('location');
    if (location == null) {
      return failedResult(GeocodeStatus.UNKNOWN_ERROR);
    }

    return new GeocodeResult(
      ObjectUtil.safeValueOfDecimal(location.get('latitude')),
      ObjectUtil.safeValueOfDecimal(location.get('longitude')),
      GeocodeStatus.OK,
      ObjectUtil.safeValueOfString(first.get('formattedAddress')),
      ObjectUtil.safeValueOfString(first.get('placeId'))
    );
  }

  private static GeocodeResult failedResult(GeocodeStatus status) {
    return new GeocodeResult(null, null, status, null, null);
  }
}