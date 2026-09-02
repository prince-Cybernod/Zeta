/**
 * Tests for {@link GeocodeAddressInvocable}. Drives the invocable through its
 * non-static internal entrypoint with a {@link GoogleMapsApiMock} so each
 * scenario is hermetic — no real HTTP, no real client.
 *
 * The public {@link GeocodeAddressInvocable#geocodeAddresses} static is
 * exercised separately to keep the Flow contract under coverage.
 */
@IsTest(IsParallel=true)
private class GeocodeAddressInvocableTest {
  private static final String ADDRESS = '350 Fifth Ave, New York, NY';
  private static final Decimal LATITUDE = 40.7484;
  private static final Decimal LONGITUDE = -73.9857;

  private static final GoogleMapsApiMock GOOGLE_MAPS_API_MOCK;

  static {
    GOOGLE_MAPS_API_MOCK = new GoogleMapsApiMock();
  }

  @IsTest
  private static void geocodeAddresses_singleHappyPath_returnsLatLong() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode())
      .thenReturn(new GeocodeResult(LATITUDE, LONGITUDE, GeocodeStatus.OK, 'fmt', 'pid'));

    List<GeocodeAddressInvocable.Result> results = invoke(
      new List<GeocodeAddressInvocable.Request>{ requestFor(ADDRESS) }
    );

    Assert.areEqual(1, results.size(), 'one input -> one result');
    Assert.areEqual(LATITUDE, results[0].latitude, 'latitude');
    Assert.areEqual(LONGITUDE, results[0].longitude, 'longitude');
    GOOGLE_MAPS_API_MOCK.verify(GOOGLE_MAPS_API_MOCK.method.geocode(), 1);
    Assert.areEqual(
      ADDRESS,
      GOOGLE_MAPS_API_MOCK.getCalls(GOOGLE_MAPS_API_MOCK.method.geocode())[0].get('address'),
      'CUT must pass the request address straight through to the client'
    );
  }

  @IsTest
  private static void geocodeAddresses_bulkFiveAddresses_returnsLatLongForEach() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode())
      .thenReturn(new GeocodeResult(40.1, -74.1, GeocodeStatus.OK, 'a', 'p1'))
      .thenReturn(new GeocodeResult(40.2, -74.2, GeocodeStatus.OK, 'b', 'p2'))
      .thenReturn(new GeocodeResult(40.3, -74.3, GeocodeStatus.OK, 'c', 'p3'))
      .thenReturn(new GeocodeResult(40.4, -74.4, GeocodeStatus.OK, 'd', 'p4'))
      .thenReturn(new GeocodeResult(40.5, -74.5, GeocodeStatus.OK, 'e', 'p5'));

    List<GeocodeAddressInvocable.Request> requests = new List<GeocodeAddressInvocable.Request>{
      requestFor('1 Main St'),
      requestFor('2 Main St'),
      requestFor('3 Main St'),
      requestFor('4 Main St'),
      requestFor('5 Main St')
    };

    List<GeocodeAddressInvocable.Result> results = invoke(requests);

    Assert.areEqual(5, results.size(), 'five inputs -> five results, in order');
    Assert.areEqual(40.1, results[0].latitude);
    Assert.areEqual(-74.1, results[0].longitude);
    Assert.areEqual(40.5, results[4].latitude);
    Assert.areEqual(-74.5, results[4].longitude);
    GOOGLE_MAPS_API_MOCK.verify(GOOGLE_MAPS_API_MOCK.method.geocode(), 5);

    List<Map<String, Object>> calls = GOOGLE_MAPS_API_MOCK.getCalls(
      GOOGLE_MAPS_API_MOCK.method.geocode()
    );
    Set<String> addressesPassed = new Set<String>();
    for (Map<String, Object> call : calls) {
      addressesPassed.add((String) call.get('address'));
    }
    Assert.areEqual(
      new Set<String>{ '1 Main St', '2 Main St', '3 Main St', '4 Main St', '5 Main St' },
      addressesPassed,
      'CUT must hand each address to the client distinctly'
    );
  }

  @IsTest
  private static void geocodeAddresses_zeroResults_throws() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode())
      .thenReturn(new GeocodeResult(null, null, GeocodeStatus.ZERO_RESULTS, null, null));

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor(ADDRESS) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
      Assert.isTrue(
        e.getMessage().contains('ZERO_RESULTS'),
        'exception message should name the failing status, got: ' + e.getMessage()
      );
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocodeAddresses_requestDenied_throws() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode())
      .thenReturn(new GeocodeResult(null, null, GeocodeStatus.REQUEST_DENIED, null, null));

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor(ADDRESS) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
      Assert.isTrue(
        e.getMessage().contains('REQUEST_DENIED'),
        'exception message should name the failing status'
      );
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocodeAddresses_overQuota_throws() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode())
      .thenReturn(new GeocodeResult(null, null, GeocodeStatus.OVER_QUERY_LIMIT, null, null));

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor(ADDRESS) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocodeAddresses_nullResult_throws() {
    GOOGLE_MAPS_API_MOCK.reset();
    GOOGLE_MAPS_API_MOCK.when(GOOGLE_MAPS_API_MOCK.method.geocode()).thenReturn(null);

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor(ADDRESS) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void geocodeAddresses_blankAddress_throwsBeforeCallout() {
    GOOGLE_MAPS_API_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class,
      'address must not be blank'
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor('') });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    GOOGLE_MAPS_API_MOCK.never(GOOGLE_MAPS_API_MOCK.method.geocode());
  }

  @IsTest
  private static void geocodeAddresses_nullAddress_throwsBeforeCallout() {
    GOOGLE_MAPS_API_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class,
      'address must not be blank'
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ requestFor(null) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    GOOGLE_MAPS_API_MOCK.never(GOOGLE_MAPS_API_MOCK.method.geocode());
  }

  @IsTest
  private static void geocodeAddresses_nullRequest_throwsBeforeCallout() {
    GOOGLE_MAPS_API_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      invoke(new List<GeocodeAddressInvocable.Request>{ null });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    GOOGLE_MAPS_API_MOCK.never(GOOGLE_MAPS_API_MOCK.method.geocode());
  }

  @IsTest
  private static void geocodeAddresses_emptyRequestList_returnsEmptyList() {
    GOOGLE_MAPS_API_MOCK.reset();

    List<GeocodeAddressInvocable.Result> results = invoke(
      new List<GeocodeAddressInvocable.Request>()
    );

    Assert.areEqual(0, results.size(), 'empty input -> empty output');
    GOOGLE_MAPS_API_MOCK.never(GOOGLE_MAPS_API_MOCK.method.geocode());
  }

  @IsTest
  private static void geocodeAddresses_nullRequestList_returnsEmptyList() {
    GOOGLE_MAPS_API_MOCK.reset();

    List<GeocodeAddressInvocable.Result> results = invoke(null);

    Assert.areEqual(0, results.size(), 'null input -> empty output');
    GOOGLE_MAPS_API_MOCK.never(GOOGLE_MAPS_API_MOCK.method.geocode());
  }

  @IsTest
  private static void publicConstructor_doesNotThrow() {
    // Exercises the public no-arg ctor that the Flow runtime binds to —
    // every other test uses the @TestVisible private ctor with the mock.
    new GeocodeAddressInvocable();
  }

  @IsTest
  private static void publicStaticEntrypoint_coversFlowBinding() {
    // The @InvocableMethod static is what Flow actually calls. We can't
    // inject a mock through it, but we still need it under coverage. Drive
    // it with a single null-request input so it short-circuits without a
    // real HTTP callout, and assert it throws the expected exception.
    AssertThrows.Throwing throwing = AssertThrows.with(
      GeocodeFailureException.class
    );
    try {
      GeocodeAddressInvocable.geocodeAddresses(
        new List<GeocodeAddressInvocable.Request>{ requestFor(null) }
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  private static GeocodeAddressInvocable buildInvocable() {
    return new GeocodeAddressInvocable(GOOGLE_MAPS_API_MOCK);
  }

  private static GeocodeAddressInvocable.Request requestFor(String address) {
    GeocodeAddressInvocable.Request request = new GeocodeAddressInvocable.Request();
    request.address = address;
    return request;
  }

  private static List<GeocodeAddressInvocable.Result> invoke(
    List<GeocodeAddressInvocable.Request> requests
  ) {
    // The public static is what Flow actually binds to (covered by
    // publicStaticEntrypoint_coversFlowBinding). Everything else drives the
    // @TestVisible instance method so we can inject the mock client.
    return buildInvocable().geocodeAll(requests);
  }
}