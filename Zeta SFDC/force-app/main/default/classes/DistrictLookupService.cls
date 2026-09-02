/**
 * Pure point-in-polygon lookup against {@link District__c} / {@link District_Ring__c}.
 *
 * Read-only and side-effect-free — callers pass a lat/lng and receive the
 * District key (or {@code null} when no active District contains the point).
 * No DML, no enqueue, no record-update behavior. Flow drives the orchestration
 * via {@link FindDistrictInvocable}.
 */
public interface DistrictLookupService {
  /**
   * @return the {@code District_Id__c} of the active District whose rings
   *         contain the point, or {@code null} if the point falls outside
   *         every active District.
   */
  String findDistrictForPoint(Decimal latitude, Decimal longitude);
}