/**
 * Tests for {@link FindNearestSchoolInvocable}. Drives the invocable through
 * its non-static internal entrypoint with a {@link NearestSchoolServiceMock}
 * so each scenario is hermetic — no real SOQL, no real distance math.
 *
 * The public {@link FindNearestSchoolInvocable#findNearestSchools} static is
 * exercised separately to keep the invocable entrypoint under coverage.
 */
@IsTest(IsParallel=true)
private class FindNearestSchoolInvocableTest {
  private static final Decimal LATITUDE = 40.83;
  private static final Decimal LONGITUDE = -73.91;

  private static final NearestSchoolServiceMock SERVICE_MOCK;

  static {
    SERVICE_MOCK = new NearestSchoolServiceMock();
  }

  @IsTest
  private static void findNearestSchools_singleHappyPath_returnsSchoolAndDistance() {
    SERVICE_MOCK.reset();
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    SERVICE_MOCK.when(SERVICE_MOCK.method.findNearestSchoolForPoint())
      .thenReturn(new NearestSchoolMatch(schoolId, 1.25));

    List<FindNearestSchoolInvocable.Result> results = invoke(
      new List<FindNearestSchoolInvocable.Request>{ requestFor(LATITUDE, LONGITUDE) }
    );

    Assert.areEqual(1, results.size(), 'one input -> one result');
    Assert.areEqual(schoolId, results[0].schoolId, 'school id passed through');
    Assert.areEqual(1.25, results[0].distanceInMiles, 'distance passed through');
    SERVICE_MOCK.verify(SERVICE_MOCK.method.findNearestSchoolForPoint(), 1);
    Map<String, Object> call = SERVICE_MOCK.getCalls(
      SERVICE_MOCK.method.findNearestSchoolForPoint()
    )[0];
    Assert.areEqual(LATITUDE, call.get('latitude'), 'CUT must forward lat to the service');
    Assert.areEqual(LONGITUDE, call.get('longitude'), 'CUT must forward lng to the service');
  }

  @IsTest
  private static void findNearestSchools_bulkThreePoints_returnsResultForEachInOrder() {
    SERVICE_MOCK.reset();
    Id first = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id second = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id third = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    SERVICE_MOCK.when(SERVICE_MOCK.method.findNearestSchoolForPoint())
      .thenReturn(new NearestSchoolMatch(first, 0.5))
      .thenReturn(new NearestSchoolMatch(second, 1.5))
      .thenReturn(new NearestSchoolMatch(third, 2.5));

    List<FindNearestSchoolInvocable.Result> results = invoke(
      new List<FindNearestSchoolInvocable.Request>{
        requestFor(40.1, -74.1),
        requestFor(40.2, -74.2),
        requestFor(40.3, -74.3)
      }
    );

    Assert.areEqual(3, results.size(), 'three inputs -> three results, in order');
    Assert.areEqual(first, results[0].schoolId);
    Assert.areEqual(third, results[2].schoolId);
    Assert.areEqual(2.5, results[2].distanceInMiles);
    SERVICE_MOCK.verify(SERVICE_MOCK.method.findNearestSchoolForPoint(), 3);
  }

  @IsTest
  private static void findNearestSchools_noSchoolMatched_throws() {
    SERVICE_MOCK.reset();
    SERVICE_MOCK.when(SERVICE_MOCK.method.findNearestSchoolForPoint()).thenReturn(null);

    AssertThrows.Throwing throwing = AssertThrows.with(NearestSchoolLookupFailureException.class);
    try {
      invoke(new List<FindNearestSchoolInvocable.Request>{ requestFor(LATITUDE, LONGITUDE) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
      Assert.isTrue(
        e.getMessage().contains('No School Account'),
        'exception message should explain the miss, got: ' + e.getMessage()
      );
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void findNearestSchools_nullLatitude_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      NearestSchoolLookupFailureException.class,
      'latitude and longitude are both required'
    );
    try {
      invoke(new List<FindNearestSchoolInvocable.Request>{ requestFor(null, LONGITUDE) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findNearestSchoolForPoint());
  }

  @IsTest
  private static void findNearestSchools_nullLongitude_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(
      NearestSchoolLookupFailureException.class,
      'latitude and longitude are both required'
    );
    try {
      invoke(new List<FindNearestSchoolInvocable.Request>{ requestFor(LATITUDE, null) });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findNearestSchoolForPoint());
  }

  @IsTest
  private static void findNearestSchools_nullRequest_throwsBeforeLookup() {
    SERVICE_MOCK.reset();

    AssertThrows.Throwing throwing = AssertThrows.with(NearestSchoolLookupFailureException.class);
    try {
      invoke(new List<FindNearestSchoolInvocable.Request>{ null });
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
    SERVICE_MOCK.never(SERVICE_MOCK.method.findNearestSchoolForPoint());
  }

  @IsTest
  private static void findNearestSchools_emptyRequestList_returnsEmptyList() {
    SERVICE_MOCK.reset();

    List<FindNearestSchoolInvocable.Result> results = invoke(
      new List<FindNearestSchoolInvocable.Request>()
    );

    Assert.areEqual(0, results.size(), 'empty input -> empty output');
    SERVICE_MOCK.never(SERVICE_MOCK.method.findNearestSchoolForPoint());
  }

  @IsTest
  private static void findNearestSchools_nullRequestList_returnsEmptyList() {
    SERVICE_MOCK.reset();

    List<FindNearestSchoolInvocable.Result> results = invoke(null);

    Assert.areEqual(0, results.size(), 'null input -> empty output');
    SERVICE_MOCK.never(SERVICE_MOCK.method.findNearestSchoolForPoint());
  }

  @IsTest
  private static void publicConstructor_doesNotThrow() {
    new FindNearestSchoolInvocable();
  }

  @IsTest
  private static void publicStaticEntrypoint_coversFlowBinding() {
    AssertThrows.Throwing throwing = AssertThrows.with(NearestSchoolLookupFailureException.class);
    try {
      FindNearestSchoolInvocable.findNearestSchools(
        new List<FindNearestSchoolInvocable.Request>{ requestFor(null, null) }
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  private static FindNearestSchoolInvocable buildInvocable() {
    return new FindNearestSchoolInvocable(SERVICE_MOCK);
  }

  private static FindNearestSchoolInvocable.Request requestFor(Decimal lat, Decimal lng) {
    FindNearestSchoolInvocable.Request request = new FindNearestSchoolInvocable.Request();
    request.latitude = lat;
    request.longitude = lng;
    return request;
  }

  private static List<FindNearestSchoolInvocable.Result> invoke(
    List<FindNearestSchoolInvocable.Request> requests
  ) {
    return buildInvocable().findAll(requests);
  }
}