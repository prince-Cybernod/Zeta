/**
 * Implementation of {@link DistrictLookupService}.
 *
 * Two-pass point-in-polygon lookup:
 *   1. Query active {@link District__c} rows (~32 expected) and pre-filter by
 *      per-district bbox containment in Apex against the input lat/lng.
 *      Typically 1-3 candidate districts per point.
 *   2. Query active {@link District_Ring__c} rows for the union of candidate
 *      district Ids, ordered so Outer rings come before Hole rings within each
 *      district. A point is inside a district iff some Outer ring contains it
 *      AND no Hole ring contains it. Per-ring bbox guards avoid JSON
 *      deserialization when a ring obviously cannot contain the point.
 *
 * Pure read-only — all SOQL routes through {@link DatabaseRepo}; no DML.
 */
public with sharing class DistrictLookupServiceImpl implements DistrictLookupService {
  private static final String RING_ROLE_OUTER = 'Outer';
  private static final String RING_ROLE_HOLE = 'Hole';

  private final DatabaseRepo databaseRepo;
  private final PointInPolygon pointInPolygon;

  public DistrictLookupServiceImpl() {
    this(new SystemModeDatabaseRepo(), new PointInPolygonImpl());
  }

  @TestVisible
  private DistrictLookupServiceImpl(DatabaseRepo databaseRepo, PointInPolygon pointInPolygon) {
    this.databaseRepo = databaseRepo;
    this.pointInPolygon = pointInPolygon;
  }

  public String findDistrictForPoint(Decimal latitude, Decimal longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    List<District__c> districts = queryActiveDistricts();
    Set<Id> candidateDistrictIds = new Set<Id>();
    List<District__c> candidates = new List<District__c>();
    for (District__c district : districts) {
      if (
        bboxContains(
          district.Min_Lng__c,
          district.Max_Lng__c,
          district.Min_Lat__c,
          district.Max_Lat__c,
          longitude,
          latitude
        )
      ) {
        candidates.add(district);
        candidateDistrictIds.add(district.Id);
      }
    }

    if (candidates.isEmpty()) {
      return null;
    }

    Map<Id, List<District_Ring__c>> ringsByDistrictId = loadRings(candidateDistrictIds);
    return findMatch(latitude, longitude, candidates, ringsByDistrictId);
  }

  /**
   * Returns the {@code District_Id__c} of the first candidate whose rings
   * contain the point, or null if none match. "Contain" means some Outer ring
   * contains the point AND no Hole ring of the same district contains it.
   */
  private String findMatch(
    Decimal lat,
    Decimal lng,
    List<District__c> candidates,
    Map<Id, List<District_Ring__c>> ringsByDistrictId
  ) {
    if (candidates == null || candidates.isEmpty()) {
      return null;
    }
    for (District__c district : candidates) {
      List<District_Ring__c> rings = ringsByDistrictId.get(district.Id);
      if (rings == null || rings.isEmpty()) {
        continue;
      }
      if (districtContains(lat, lng, rings)) {
        return district.District_Id__c;
      }
    }
    return null;
  }

  /**
   * Two explicit passes: find any Outer that contains the point; if found,
   * scan Holes and disqualify when any Hole contains the point. Insulates the
   * algorithm from picklist alpha sort order on {@code Ring_Role__c}.
   */
  private Boolean districtContains(Decimal lat, Decimal lng, List<District_Ring__c> rings) {
    Boolean insideOuter = false;
    for (District_Ring__c ring : rings) {
      if (ring.Ring_Role__c == RING_ROLE_OUTER && ringContains(lat, lng, ring)) {
        insideOuter = true;
        break;
      }
    }
    if (!insideOuter) {
      return false;
    }
    for (District_Ring__c ring : rings) {
      if (ring.Ring_Role__c == RING_ROLE_HOLE && ringContains(lat, lng, ring)) {
        return false;
      }
    }
    return true;
  }

  /**
   * Per-ring bbox guard short-circuits before JSON deserialization on rings
   * that obviously cannot contain the point.
   */
  private Boolean ringContains(Decimal lat, Decimal lng, District_Ring__c ring) {
    if (
      !bboxContains(ring.Min_Lng__c, ring.Max_Lng__c, ring.Min_Lat__c, ring.Max_Lat__c, lng, lat)
    ) {
      return false;
    }
    if (String.isBlank(ring.Polygon_Coordinates__c)) {
      return false;
    }
    List<List<Decimal>> coordinates = (List<List<Decimal>>) JSON.deserialize(
      ring.Polygon_Coordinates__c,
      List<List<Decimal>>.class
    );
    return pointInPolygon.isInside(lat, lng, coordinates);
  }

  private List<District__c> queryActiveDistricts() {
    return (List<District__c>) databaseRepo.queryWithBinds(
      'SELECT Id, District_Id__c, Min_Lng__c, Max_Lng__c, Min_Lat__c, Max_Lat__c ' +
      'FROM District__c WHERE Active__c = true',
      new Map<String, Object>()
    );
  }

  private Map<Id, List<District_Ring__c>> loadRings(Set<Id> districtIds) {
    Map<Id, List<District_Ring__c>> ringsByDistrictId = new Map<Id, List<District_Ring__c>>();
    if (districtIds == null || districtIds.isEmpty()) {
      return ringsByDistrictId;
    }
    List<District_Ring__c> rings = (List<District_Ring__c>) databaseRepo.queryWithBinds(
      'SELECT District__c, District__r.District_Id__c, Ring_Role__c, Ring_Order__c, ' +
        'Polygon_Coordinates__c, Min_Lng__c, Max_Lng__c, Min_Lat__c, Max_Lat__c ' +
        'FROM District_Ring__c WHERE District__c IN :districtIds AND Active__c = true ' +
        'ORDER BY District__c, Ring_Role__c, Ring_Order__c',
      new Map<String, Object>{ 'districtIds' => districtIds }
    );
    for (District_Ring__c ring : rings) {
      List<District_Ring__c> bucket = ringsByDistrictId.get(ring.District__c);
      if (bucket == null) {
        bucket = new List<District_Ring__c>();
        ringsByDistrictId.put(ring.District__c, bucket);
      }
      bucket.add(ring);
    }
    return ringsByDistrictId;
  }

  private static Boolean bboxContains(
    Decimal minLng,
    Decimal maxLng,
    Decimal minLat,
    Decimal maxLat,
    Decimal lng,
    Decimal lat
  ) {
    if (minLng == null || maxLng == null || minLat == null || maxLat == null) {
      return false;
    }
    return lng >= minLng && lng <= maxLng && lat >= minLat && lat <= maxLat;
  }
}