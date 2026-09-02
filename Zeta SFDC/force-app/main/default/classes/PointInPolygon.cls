/**
 * Service for testing whether a geographic point falls inside a polygon ring.
 *
 * Vertex format: each inner list is {@code [lng, lat]} (GeoJSON / KML coordinate
 * order). Rings may be open or closed (the algorithm treats the last vertex as
 * implicitly connected to the first).
 */
public interface PointInPolygon {
  /**
   * Returns true when the point ({@code lat}, {@code lng}) lies strictly inside
   * the polygon ring.
   *
   * Behavior at boundaries is deterministic but asymmetric — the ray-casting
   * algorithm gives different answers for points on different horizontal edges
   * of the same polygon. Real-world coordinates from geocoding never land
   * exactly on a ring edge, so this asymmetry is acceptable in practice.
   *
   * Rings with fewer than three vertices cannot enclose area and return
   * {@code false}. Null inputs throw {@link IllegalArgumentException}.
   *
   * @param lat point latitude
   * @param lng point longitude
   * @param ring ordered list of vertices in {@code [lng, lat]} order
   * @return {@code true} when the point is inside the ring
   */
  Boolean isInside(Decimal lat, Decimal lng, List<List<Decimal>> ring);
}