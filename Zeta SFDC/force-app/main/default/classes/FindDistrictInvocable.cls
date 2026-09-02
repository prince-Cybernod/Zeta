/**
 * Flow-invocable wrapper around {@link DistrictLookupService#findDistrictForPoint}
 * that resolves a (latitude, longitude) pair to the matching District key by
 * point-in-polygon lookup against the active District / District_Ring rows.
 *
 * Read-only — no DML, no enqueue. Bulk-safe: the service's SOQL is constant
 * regardless of input size, so callers can pass a List and pay the same cost.
 *
 * Failure handling: missing input (null lat or null lng) or a point that falls
 * outside every active District throws {@link DistrictLookupFailureException}.
 * This surfaces in Flow as a fault path the admin can route however they like.
 */
public with sharing class FindDistrictInvocable {
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
    Description='Resolves a latitude / longitude to the matching District key via point-in-polygon lookup. Throws on null input or out-of-district so a Flow fault path can handle it.'
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
    if (String.isBlank(district)) {
      throw new DistrictLookupFailureException(
        String.format(
          'No active District contains point ({0}, {1})',
          new List<Object>{ latitude, longitude }
        )
      );
    }

    Result result = new Result();
    result.district = district;
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
      Description='District_Id__c key (e.g. "CSD-7") of the District whose rings contain the point. Populated only on success.'
    )
    public String district;
  }
}