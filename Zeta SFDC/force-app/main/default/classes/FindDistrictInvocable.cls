/**
 * Flow-invocable wrapper around {@link DistrictLookupService#findDistrictForPoint}
 * that resolves a (latitude, longitude) pair to the matching District key by
 * point-in-polygon lookup against the active District / District_Ring rows.
 *
 * Read-only — no DML, no enqueue. Bulk-safe: the service's SOQL is constant
 * regardless of input size, so callers can pass a List and pay the same cost.
 *
 * Failure handling: missing input (null lat or null lng) throws
 * {@link DistrictLookupFailureException}, and errors raised by the lookup
 * itself propagate — both reach Flow as a fault. A point that simply falls
 * outside every active District is not a failure: it returns
 * {@link #NO_DISTRICT} on the success path, so no fault-path error
 * notification fires for what is a routine outcome.
 */
public with sharing class FindDistrictInvocable {
  /**
   * District key returned when the point falls outside every active District.
   * Stored as-is in the District Id text fields the callers stamp.
   */
  public static final String NO_DISTRICT = 'N/A';

  private final DistrictLookupService districtLookupService;

  public FindDistrictInvocable() {
    this(new DistrictLookupServiceImpl());
  }

  @TestVisible
  private FindDistrictInvocable(DistrictLookupService districtLookupService) {
    this.districtLookupService = districtLookupService;
  }

  @InvocableMethod(
    Label='Find District'
    Description='Resolves a latitude / longitude to the matching District key via point-in-polygon lookup. Returns "N/A" when the point is outside every active District; throws on null input or a lookup error so a Flow fault path can handle those.'
    Category='District'
  )
  public static List<Result> findDistricts(List<Request> requests) {
    return new FindDistrictInvocable().findAll(requests);
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
      throw new DistrictLookupFailureException(
        'latitude and longitude are both required'
      );
    }

    String district = districtLookupService.findDistrictForPoint(latitude, longitude);

    Result result = new Result();
    result.district = String.isBlank(district) ? NO_DISTRICT : district;
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
      Label='District'
      Description='District_Id__c key (e.g. "CSD-7") of the District whose rings contain the point, or "N/A" when the point is outside every active District.'
    )
    public String district;
  }
}