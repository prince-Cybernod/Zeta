/**
 * Tests for {@link DistrictLookupServiceImpl}. Pure read-only lookup —
 * exercises the bbox + ring-containment path with mocked SOQL and a mocked
 * point-in-polygon implementation.
 */
@IsTest(IsParallel=true)
private class DistrictLookupServiceImplTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final PointInPolygonMock POINT_IN_POLYGON_MOCK;
  private static final DistrictLookupServiceImpl SERVICE;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    POINT_IN_POLYGON_MOCK = new PointInPolygonMock();
    SERVICE = new DistrictLookupServiceImpl(DATABASE_REPO_MOCK, POINT_IN_POLYGON_MOCK);
  }

  @IsTest
  private static void constructor_publicNoArg_canBeInstantiated() {
    DistrictLookupServiceImpl service = new DistrictLookupServiceImpl();

    Assert.isNotNull(service, 'Should be instantiable via the public no-arg constructor');
  }

  @IsTest
  private static void findDistrictForPoint_nullLatitude_returnsNullWithoutQuery() {
    resetMocks();

    String district = SERVICE.findDistrictForPoint(null, -73.92);

    Assert.areEqual(null, district);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void findDistrictForPoint_nullLongitude_returnsNullWithoutQuery() {
    resetMocks();

    String district = SERVICE.findDistrictForPoint(40.85, null);

    Assert.areEqual(null, district);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.queryWithBinds());
  }

  @IsTest
  private static void findDistrictForPoint_match_returnsDistrictKey() {
    resetMocks();
    Id matchingDistrictId = SObjectIds.generateFakeId(Schema.District__c.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<District__c>{
          DistrictData.district(matchingDistrictId, 'CSD-7', -74.0, -73.8, 40.8, 40.9)
        }
      )
      .thenReturn(
        new List<District_Ring__c>{
          DistrictData.ring(
            matchingDistrictId,
            'Outer',
            -74.0,
            -73.8,
            40.8,
            40.9,
            '[[-74.0,40.8],[-73.8,40.8],[-73.8,40.9],[-74.0,40.9]]'
          )
        }
      );
    POINT_IN_POLYGON_MOCK.when(POINT_IN_POLYGON_MOCK.method.isInside()).thenReturn(true);

    String district = SERVICE.findDistrictForPoint(40.85, -73.92);

    Assert.areEqual('CSD-7', district);
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  @IsTest
  private static void findDistrictForPoint_outOfDistrict_returnsNull() {
    resetMocks();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<District__c>{
          DistrictData.district(
            SObjectIds.generateFakeId(Schema.District__c.SObjectType),
            'CSD-7',
            -74.0,
            -73.8,
            40.8,
            40.9
          )
        }
      );

    String district = SERVICE.findDistrictForPoint(0.0, 0.0);

    Assert.areEqual(null, district);
    POINT_IN_POLYGON_MOCK.never(POINT_IN_POLYGON_MOCK.method.isInside());
    DATABASE_REPO_MOCK.never(DATABASE_REPO_MOCK.method.updateSObjects());
  }

  private static void resetMocks() {
    DATABASE_REPO_MOCK.reset();
    POINT_IN_POLYGON_MOCK.reset();
  }
}