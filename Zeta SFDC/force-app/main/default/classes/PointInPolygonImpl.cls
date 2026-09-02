/**
 * Ray-casting implementation of {@link PointInPolygon}. Pure computation —
 * no SOQL, DML, or callouts.
 */
public with sharing class PointInPolygonImpl implements PointInPolygon {
  public PointInPolygonImpl() {
  }

  public Boolean isInside(Decimal lat, Decimal lng, List<List<Decimal>> ring) {
    Preconditions.checkNotNull(lat, 'lat must not be null');
    Preconditions.checkNotNull(lng, 'lng must not be null');
    Preconditions.checkNotNull(ring, 'ring must not be null');

    Integer n = ring.size();
    if (n < 3) {
      return false;
    }

    Boolean inside = false;
    Integer j = n - 1;
    for (Integer i = 0; i < n; i++) {
      List<Decimal> vi = ring[i];
      List<Decimal> vj = ring[j];
      Decimal xi = vi[0];
      Decimal yi = vi[1];
      Decimal xj = vj[0];
      Decimal yj = vj[1];

      if ((yi > lat) != (yj > lat)) {
        Decimal xIntersect = ((xj - xi) * (lat - yi)) / (yj - yi) + xi;
        if (lng < xIntersect) {
          inside = !inside;
        }
      }
      j = i;
    }
    return inside;
  }
}