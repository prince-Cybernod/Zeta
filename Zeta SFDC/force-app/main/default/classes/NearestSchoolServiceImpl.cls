/**
 * Implementation of {@link NearestSchoolService}.
 *
 * Scans geocoded School Accounts and keeps the smallest great-circle distance,
 * using the platform's own {@link Location#getDistance}. Deliberately not SOQL
 * ORDER BY DISTANCE: that costs a query per point, whereas the scan loads the
 * Schools once per instance and answers any number of points from it.
 *
 * Requires School Accounts to carry a standard billing address geocode.
 * Schools without one are invisible to the match.
 *
 * Pure read-only — all SOQL routes through {@link DatabaseRepo}; no DML.
 */
public with sharing class NearestSchoolServiceImpl implements NearestSchoolService {
  private static final String SCHOOL_RECORD_TYPE = 'School';
  private static final String UNIT_MILES = 'mi';

  private final DatabaseRepo databaseRepo;
  private List<Account> schools;

  public NearestSchoolServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private NearestSchoolServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public NearestSchoolMatch findNearestSchoolForPoint(Decimal latitude, Decimal longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    Location origin = Location.newInstance(latitude, longitude);
    NearestSchoolMatch nearest;
    for (Account school : getSchools()) {
      Decimal distance = Location.getDistance(
        origin,
        Location.newInstance(school.BillingLatitude, school.BillingLongitude),
        UNIT_MILES
      );
      if (nearest == null || distance < nearest.distanceInMiles) {
        nearest = new NearestSchoolMatch(school.Id, distance);
      }
    }
    return nearest;
  }

  /**
   * Cached for the life of the instance so a bulk caller pays for one query
   * rather than one per point.
   */
  private List<Account> getSchools() {
    if (schools == null) {
      schools = (List<Account>) databaseRepo.queryWithBinds(
        'SELECT Id, BillingLatitude, BillingLongitude FROM Account ' +
          'WHERE RecordType.DeveloperName = :recordType ' +
          'AND BillingLatitude != NULL AND BillingLongitude != NULL',
        new Map<String, Object>{ 'recordType' => SCHOOL_RECORD_TYPE }
      );
    }
    return schools;
  }
}