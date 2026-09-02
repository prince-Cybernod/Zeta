/**
 * Tests for {@link NearestSchoolServiceImpl}. Pure read-only lookup —
 * exercises the nearest-neighbour scan with mocked SOQL, so the distances
 * asserted here come from the platform's own great-circle math rather than
 * from org data.
 */
@IsTest(IsParallel=true)
private class NearestSchoolServiceImplTest {
  private static final Decimal BRONX_LATITUDE = 40.8300;
  private static final Decimal BRONX_LONGITUDE = -73.9100;

  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final NearestSchoolServiceImpl SERVICE;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    SERVICE = new NearestSchoolServiceImpl(DATABASE_REPO_MOCK);
  }

  @IsTest
  private static void constructor_publicNoArg_canBeInstantiated() {
    NearestSchoolServiceImpl service = new NearestSchoolServiceImpl();

    Assert.isNotNull(service, 'Should be instantiable via the public no-arg constructor');
  }

  @IsTest
  private static void findNearestSchoolForPoint_nullLatitude_returnsNullWithoutQuery() {
    DATABASE_REPO_MOCK.reset();

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(null, BRONX_LONGITUDE);

    Assert.areEqual(null, match);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void findNearestSchoolForPoint_nullLongitude_returnsNullWithoutQuery() {
    DATABASE_REPO_MOCK.reset();

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(BRONX_LATITUDE, null);

    Assert.areEqual(null, match);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void findNearestSchoolForPoint_noGeocodedSchools_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>());

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(BRONX_LATITUDE, BRONX_LONGITUDE);

    Assert.areEqual(null, match, 'no candidates -> no match');
  }

  @IsTest
  private static void findNearestSchoolForPoint_severalSchools_returnsTheClosest() {
    DATABASE_REPO_MOCK.reset();
    Id manhattanId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id bronxId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id queensId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{
          school(manhattanId, 40.7500, -73.9800),
          school(bronxId, 40.8400, -73.9200),
          school(queensId, 40.7000, -73.8000)
        }
      );

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(BRONX_LATITUDE, BRONX_LONGITUDE);

    Assert.areEqual(bronxId, match.schoolId, 'the Bronx school is the closest to a Bronx point');
    Assert.areEqual(
      Location.getDistance(
        Location.newInstance(BRONX_LATITUDE, BRONX_LONGITUDE),
        Location.newInstance(40.8400, -73.9200),
        'mi'
      ),
      match.distanceInMiles,
      'distance must be the great-circle miles to that school'
    );
  }

  @IsTest
  private static void findNearestSchoolForPoint_closestListedLast_stillWins() {
    DATABASE_REPO_MOCK.reset();
    Id farId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id nearId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<Account>{ school(farId, 40.7000, -73.8000), school(nearId, 40.8310, -73.9110) }
      );

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(BRONX_LATITUDE, BRONX_LONGITUDE);

    Assert.areEqual(nearId, match.schoolId, 'query order must not decide the winner');
  }

  @IsTest
  private static void findNearestSchoolForPoint_exactSchoolLocation_returnsZeroDistance() {
    DATABASE_REPO_MOCK.reset();
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ school(schoolId, BRONX_LATITUDE, BRONX_LONGITUDE) });

    NearestSchoolMatch match = SERVICE.findNearestSchoolForPoint(BRONX_LATITUDE, BRONX_LONGITUDE);

    Assert.areEqual(schoolId, match.schoolId);
    Assert.areEqual(0, match.distanceInMiles, 'a point on the school is zero miles away');
  }

  @IsTest
  private static void findNearestSchoolForPoint_repeatedCalls_queryOnlyOnce() {
    DATABASE_REPO_MOCK.reset();
    Id schoolId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    NearestSchoolServiceImpl service = new NearestSchoolServiceImpl(DATABASE_REPO_MOCK);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Account>{ school(schoolId, 40.8400, -73.9200) });

    for (Integer i = 0; i < 5; i++) {
      service.findNearestSchoolForPoint(BRONX_LATITUDE + (i * 0.001), BRONX_LONGITUDE);
    }

    DATABASE_REPO_MOCK.verify(DATABASE_REPO_MOCK.method.queryWithBinds(), 1);
  }

  private static Account school(Id schoolId, Decimal latitude, Decimal longitude) {
    return new Account(Id = schoolId, BillingLatitude = latitude, BillingLongitude = longitude);
  }
}