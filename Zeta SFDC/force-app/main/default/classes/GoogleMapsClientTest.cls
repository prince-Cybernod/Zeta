/**
 * Tests for {@link GoogleMapsClient}. All paths exercised through the
 * {@link HttpRequestSenderMock}, so no Test.startTest/stopTest is needed —
 * nothing async, nothing governor-bounded, nothing real to flush.
 *
 * Response bodies use the v4 shape (location.latitude / location.longitude /
 * formattedAddress / placeId at {@code results[0]}) so any future migration
 * back to v3 — or accidental v3 leak — surfaces here, not in production.
 */
@IsTest(IsParallel=true)
private class GoogleMapsClientTest {
  private static final String ADDRESS = '350 Fifth Ave, New York, NY';
  private static final String FORMATTED_ADDRESS = '350 5th Ave, New York, NY 10118, USA';
  private static final String PLACE_ID = 'ChIJaXQRs6lZwokRY6VAvVlNXc8';
  private static final Decimal LATITUDE = 40.7484;
  private static final Decimal LONGITUDE = -73.9857;

  private static final String OK_BODY;
  private static final String EMPTY_RESULTS_BODY = '{"results":[]}';

  private static final HttpRequestSenderMock HTTP_REQUEST_SENDER_MOCK;
  private static final GoogleMapsClient CLIENT;

  static {
    OK_BODY = JSON.serialize(
      new Map<String, Object>{
        'results' => new List<Object>{
          new Map<String, Object>{
            'location' => new Map<String, Object>{
              'latitude' => LATITUDE,
              'longitude' => LONGITUDE
            },
            'formattedAddress' => FORMATTED_ADDRESS,
            'placeId' => PLACE_ID
          }
        }
      }
    );
    HTTP_REQUEST_SENDER_MOCK = new HttpRequestSenderMock();
    CLIENT = new GoogleMapsClient(HTTP_REQUEST_SENDER_MOCK);
  }

  @IsTest
  private static void geocode_okWithResults_returnsOkStatus() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok(OK_BODY));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.OK, result.status, 'status');
    Assert.areEqual(LATITUDE, result.latitude, 'latitude');
    Assert.areEqual(LONGITUDE, result.longitude, 'longitude');
    Assert.areEqual(FORMATTED_ADDRESS, result.formattedAddress, 'formattedAddress');
    Assert.areEqual(PLACE_ID, result.placeId, 'placeId');
    HTTP_REQUEST_SENDER_MOCK.verify(HTTP_REQUEST_SENDER_MOCK.method.send(), 1);
  }

  @IsTest
  private static void geocode_okWithEmptyResults_returnsZeroResults() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok(EMPTY_RESULTS_BODY));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.ZERO_RESULTS, result.status, 'status');
    Assert.isNull(result.latitude, 'latitude');
    Assert.isNull(result.longitude, 'longitude');
  }

  @IsTest
  private static void geocode_badRequest_returnsInvalidRequest() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.badRequest('{}'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.INVALID_REQUEST, result.status, 'status');
  }

  @IsTest
  private static void geocode_unauthorized_returnsRequestDenied() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(responseWithStatus(401, 'Unauthorized'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.REQUEST_DENIED, result.status, 'status');
  }

  @IsTest
  private static void geocode_forbidden_returnsRequestDenied() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(responseWithStatus(403, 'Forbidden'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.REQUEST_DENIED, result.status, 'status');
  }

  @IsTest
  private static void geocode_tooManyRequests_returnsOverQueryLimit() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(responseWithStatus(429, 'Too Many Requests'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.OVER_QUERY_LIMIT, result.status, 'status');
  }

  @IsTest
  private static void geocode_notFound_returnsUnknownError() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.notFound('{}'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.UNKNOWN_ERROR, result.status, 'status');
  }

  @IsTest
  private static void geocode_internalServerError_throwsCalloutException() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenThrow(new CalloutException('upstream 500'));

    AssertThrows.Throwing throwing = AssertThrows.with(CalloutException.class, 'upstream 500');
    try {
      CLIENT.geocode(ADDRESS);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocode_malformedJson_returnsUnknownError() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok('not json {{{'));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.UNKNOWN_ERROR, result.status, 'status');
  }

  @IsTest
  private static void geocode_resultMissingLocation_returnsUnknownError() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    String body = JSON.serialize(
      new Map<String, Object>{
        'results' => new List<Object>{
          new Map<String, Object>{ 'formattedAddress' => 'x', 'placeId' => 'y' }
        }
      }
    );
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok(body));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.UNKNOWN_ERROR, result.status, 'status');
  }

  @IsTest
  private static void geocode_okMissingFormattedAddressAndPlaceId_keepsNulls() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    String body = JSON.serialize(
      new Map<String, Object>{
        'results' => new List<Object>{
          new Map<String, Object>{
            'location' => new Map<String, Object>{
              'latitude' => LATITUDE,
              'longitude' => LONGITUDE
            }
          }
        }
      }
    );
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok(body));

    GeocodeResult result = CLIENT.geocode(ADDRESS);

    Assert.areEqual(GeocodeStatus.OK, result.status, 'status');
    Assert.areEqual(LATITUDE, result.latitude, 'latitude');
    Assert.areEqual(LONGITUDE, result.longitude, 'longitude');
    Assert.isNull(result.formattedAddress, 'formattedAddress should stay null when key is absent');
    Assert.isNull(result.placeId, 'placeId should stay null when key is absent');
  }

  @IsTest
  private static void geocode_blankAddress_throwsIllegalArgumentException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'address must not be blank'
    );
    try {
      CLIENT.geocode('');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocode_sendsApiKeyHeaderAndV4Endpoint() {
    HTTP_REQUEST_SENDER_MOCK.reset();
    HTTP_REQUEST_SENDER_MOCK.when(HTTP_REQUEST_SENDER_MOCK.method.send())
      .thenReturn(HttpResponses.ok(OK_BODY));

    CLIENT.geocode(ADDRESS);

    HttpRequest sent = (HttpRequest) HTTP_REQUEST_SENDER_MOCK
        .getCalls(HTTP_REQUEST_SENDER_MOCK.method.send())[0]
      .get('httpRequest');
    Assert.areEqual(
      '{!$Credential.Google_Maps_Geocoding.ApiKey}',
      sent.getHeader('X-Goog-Api-Key'),
      'X-Goog-Api-Key header should carry the credential merge field'
    );
    Assert.areEqual('GET', sent.getMethod(), 'method');
    Assert.isTrue(
      sent.getEndpoint().startsWith('callout:Google_Maps_Geocoding/v4/geocode/address/'),
      'endpoint should target v4 path-segment geocoding under the named credential'
    );
    Assert.isTrue(
      sent.getEndpoint().contains('350+Fifth+Ave') ||
      sent.getEndpoint().contains('350%20Fifth%20Ave'),
      'endpoint should include the URL-encoded address'
    );
  }

  @IsTest
  private static void publicConstructor_doesNotThrow() {
    // Exercises the public no-arg ctor (used by production callers) for coverage —
    // the @TestVisible private ctor is what every other test in this class drives.
    new GoogleMapsClient();
  }

  private static HttpResponse responseWithStatus(Integer statusCode, String status) {
    return HttpResponses.newBuilder()
      .setStatusCode(statusCode)
      .setStatus(status)
      .setBody('{}')
      .build();
  }
}