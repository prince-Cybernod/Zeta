/**
 * Pure nearest-neighbour lookup of School Accounts by great-circle distance.
 *
 * Read-only and side-effect-free — callers pass a lat/lng and receive the
 * closest School (or {@code null} when no School carries a geocode). No DML,
 * no enqueue, no record-update behavior.
 */
public interface NearestSchoolService {
  /**
   * @return the School Account nearest the point, or {@code null} when no
   *         School Account has a geocoded billing address.
   */
  NearestSchoolMatch findNearestSchoolForPoint(Decimal latitude, Decimal longitude);
}