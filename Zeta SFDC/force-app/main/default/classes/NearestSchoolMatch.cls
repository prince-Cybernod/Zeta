/**
 * The School Account closest to a given point, with the distance to it.
 */
public with sharing class NearestSchoolMatch {
  public Id schoolId;
  public Decimal distanceInMiles;

  public NearestSchoolMatch(Id schoolId, Decimal distanceInMiles) {
    this.schoolId = schoolId;
    this.distanceInMiles = distanceInMiles;
  }
}