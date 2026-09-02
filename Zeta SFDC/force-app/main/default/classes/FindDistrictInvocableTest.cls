/**
 * Tests for {@link FindDistrictInvocable}. Drives the invocable through its
 * non-static internal entrypoint with a {@link DistrictLookupServiceMock} so
 * each scenario is hermetic — no real SOQL, no real polygon math.
 *
 * The public {@link FindDistrictInvocable#findDistricts} static is exercised
 * separately to keep the Flow contract under coverage.
 */
@IsTest(IsParallel=true)
private class FindDistrictInvocableTest {
  private static final Decimal LATITUDE = 40.85;
  private static final Decimal LONGITUDE = -73.92;
  private static final String DISTRICT_KEY = 'CSD-7';

  private static final DistrictLookupServiceMock SERVICE_MOCK;

  static {
    SERVICE_MOCK = new DistrictLookupServiceMock();
  }

  @IsTest
  private static void findDistricts_singleHappyPath_returnsDistrictKey() {
    SERVICE_MOCK.reset();
    SERVICE_MOCK.when(SERVICE_MOCK.method.findDistrictForPoint()).thenReturn(DISTRICT_KEY);

    List<FindDistrictInvocable.Result> results = invoke(
      new List<FindDistrictInvocable.Request>{ requestFor(LATITUDE, LONGITUDE) }
    );

    Assert.areEqual(1, results.size(), 'one input -> one result');
    Assert.areEqual(DISTRICT_KEY, results[0].district, 'district key passed through');
    SERVICE_MOCK.verify(SERVICE_MOCK.method.findDistrictForPoint(), 1);
    Map<String, Object> call = SERVICE_MOCK.getCalls(SERVICE_MOCK.method.findDistrictForPoint())[0];
    Assert.areEqual(LATITUDE, call.get('latitude'), 'CUT must forward lat to the service');
    Assert.areEqual(LONGITUDE, call.get('longitude'), 'CUT must forward lng to the service');
  }

  @IsTest
  private static void findDistricts_bulkFivePoints_returnsDistrictForEach() {
    SERVICE_MOCK.reset();
    SERVICE_MOCK.when(SERVICE_MOCK.method.findDistrictForPoint())
      .thenReturn('CSD-1')
      .thenReturn('CSD-2')
      .thenReturn('CSD-3')
      .thenReturn('CSD-4')
      .thenReturn('CSD-5');

    List<FindDistrictInvocable.Request> requests = new List<FindDistrictInvocable.Request>{
      requestFor(40.1, -74.1),
      requestFor(40.2, -74.2),
      requestFor(40.3, -74.3),
      requestFor(40.4, -74.4),
      requestFor(40.5, -74.5)
    };

    List<FindDistrictInvocable.Result> results = invoke(requests);

    Assert.areEqual(5, results.size(), 'five inputs -> five results, in order');
    Assert.areEqual('CSD-1', results[0].district);
    Assert.areEqual('CSD-5', results[4].district);
    SERVICE_MOCK.verify(SERVICE_MOCK.method.findDistrictForPoint(), 5);

    List<Map<String, Object>> calls = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.findDistrictForPoint()
    );
    Set<Decimal> latitudesPassed = new Set<Decimal>();
    for (Map<String, Object> call : calls) {
      latitudesPassed.add((Decimal) call.get('latitude'));
    }
    Assert.areEqual(
      new Set<Decimal>{ 40.1, 40.2, 40.3, 40.4, 40.5 },
      latitudesPassed,
      'CUT must hand each latitude to the service distinctly'
    );
  }

  @IsTest
  private static void findDistricts_outOfDistrict_throws() {
    SERVICE_MOCK.reset();
    SERVICE_MOCK.when(SERVICE_MOCK.method.findDistrictForPoint()).thenReturn(null);

    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class
    );
    try {
      invoke(new List<FindDistrictInvocable.Request>{ requestFor(LATITUDE, LONGITUDE) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
      Assert.isTrue(
        e.getMessage().contains('No active District'),
        'exception message should explain the miss, got: ' + e.getMessage()
      );
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void findDistricts_blankDistrictKey_throws() {
    SERVICE_MOCK.reset();
    SERVICE_MOCK.when(SERVICE_MOCK.method.findDistrictForPoint()).thenReturn('');

    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class
    );
    try {
      invoke(new List<FindDistrictInvocable.Request>{ requestFor(LATITUDE, LONGITUDE) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void findDistricts_nullLatitude_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class,
      'latitude and longitude are both required'
    );
    try {
      invoke(new List<FindDistrictInvocable.Request>{ requestFor(null, LONGITUDE) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findDistrictForPoint());
  }

  @IsTest
  private static void findDistricts_nullLongitude_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class,
      'latitude and longitude are both required'
    );
    try {
      invoke(new List<FindDistrictInvocable.Request>{ requestFor(LATITUDE, null) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findDistrictForPoint());
  }

  @IsTest
  private static void findDistricts_nullRequest_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class
    );
    try {
      invoke(new List<FindDistrictInvocable.Request>{ null });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findDistrictForPoint());
  }

  @IsTest
  private static void findDistricts_emptyRequestList_returnsEmptyList() {
    SERVICE_MOCK.reset();

    List<FindDistrictInvocable.Result> results = invoke(
      new List<FindDistrictInvocable.Request>()
    );

    Assert.areEqual(0, results.size(), 'empty input -> empty output');
    SERVICE_MOCK.never(SERVICE_MOCK.method.findDistrictForPoint());
  }

  @IsTest
  private static void findDistricts_nullRequestList_returnsEmptyList() {
    SERVICE_MOCK.reset();

    List<FindDistrictInvocable.Result> results = invoke(null);

    Assert.areEqual(0, results.size(), 'null input -> empty output');
    SERVICE_MOCK.never(SERVICE_MOCK.method.findDistrictForPoint());
  }

  @IsTest
  private static void publicConstructor_doesNotThrow() {
    new FindDistrictInvocable();
  }

  @IsTest
  private static void publicStaticEntrypoint_coversFlowBinding() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      DistrictLookupFailureException.class
    );
    try {
      FindDistrictInvocable.findDistricts(
        new List<FindDistrictInvocable.Request>{ requestFor(null, null) }
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  private static FindDistrictInvocable buildInvocable() {
    return new FindDistrictInvocable(SERVICE_MOCK);
  }

  private static FindDistrictInvocable.Request requestFor(Decimal lat, Decimal lng) {
    FindDistrictInvocable.Request request = new FindDistrictInvocable.Request();
    request.latitude = lat;
    request.longitude = lng;
    return request;
  }

  private static List<FindDistrictInvocable.Result> invoke(
    List<FindDistrictInvocable.Request> requests
  ) {
    return buildInvocable().findAll(requests);
  }
}