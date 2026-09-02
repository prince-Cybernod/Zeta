/**
 * Flow-invocable wrapper around {@link NearestSchoolService#findNearestSchoolForPoint}
 * that resolves a (latitude, longitude) pair to the closest School Account and
 * the distance to it in miles.
 *
 * Read-only — no DML, no enqueue. Returns the match rather than writing it, so
 * the caller decides what to stamp and where.
 *
 * Failure handling: missing input (null lat or null lng) or no geocoded School
 * Account to match against throws {@link NearestSchoolLookupFailureException}.
 * This surfaces in Flow as a fault path the admin can route however they like.
 */
public with sharing class FindNearestSchoolInvocable {
  private final NearestSchoolService nearestSchoolService;

  public FindNearestSchoolInvocable() {
    this(new NearestSchoolServiceImpl());
  }

  @TestVisible
  private FindNearestSchoolInvocable(NearestSchoolService nearestSchoolService) {
    this.nearestSchoolService = nearestSchoolService;
  }

  @InvocableMethod(
    Label='Find Nearest School'
    Description='Resolves a latitude / longitude to the closest School Account and the distance to it in miles. Throws on null input or an org with no geocoded Schools so a Flow fault path can handle it.'
    Category='School'
  )
  public static List<Result> findNearestSchools(List<Request> requests) {
    return new FindNearestSchoolInvocable().findAll(requests);
  }

  @TestVisible
  private List<Result> findAll(List<Request> requests) {
    List<Result> results = new List<Result>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }

    for (Request request : requests) {
      results.add(findOne(request));
    }
    return results;
  }

  private Result findOne(Request request) {
    Decimal latitude = request?.latitude;
    Decimal longitude = request?.longitude;
    if (latitude == null || longitude == null) {
      throw new NearestSchoolLookupFailureException('latitude and longitude are both required');
    }

    NearestSchoolMatch match = nearestSchoolService.findNearestSchoolForPoint(latitude, longitude);
    if (match == null) {
      throw new NearestSchoolLookupFailureException(
        String.format(
          'No School Account with a geocoded billing address to match point ({0}, {1})',
          new List<Object>{ latitude, longitude }
        )
      );
    }

    Result result = new Result();
    result.schoolId = match.schoolId;
    result.distanceInMiles = match.distanceInMiles;
    return result;
  }

  public class Request {
    @InvocableVariable(
      Label='Latitude'
      Description='Latitude of the point to resolve (e.g. 40.7484).'
      Required=true
    )
    public Decimal latitude;

    @InvocableVariable(
      Label='Longitude'
      Description='Longitude of the point to resolve (e.g. -73.9857).'
      Required=true
    )
    public Decimal longitude;
  }

  public class Result {
    @InvocableVariable(
      Label='School Id'
      Description='Id of the closest School Account. Populated only on success.'
    )
    public Id schoolId;

    @InvocableVariable(
      Label='Distance In Miles'
      Description='Great-circle distance from the point to that School, in miles. Populated only on success.'
    )
    public Decimal distanceInMiles;
  }
}