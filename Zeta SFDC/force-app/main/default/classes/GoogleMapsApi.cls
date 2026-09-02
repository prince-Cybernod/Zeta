/**
 * Forward-geocoding via the Google Maps Geocoding API.
 *
 * Expected outcomes (zero results, invalid request, denied, over quota) come
 * back as a {@link GeocodeResult} with the matching {@link GeocodeStatus} —
 * never throw. Transient HTTP 5xx or otherwise unexpected status codes
 * surface as {@code CalloutException} so callers can distinguish "tried and
 * Google said no" from "couldn't reach Google."
 */
public interface GoogleMapsApi {
  /**
   * Forward-geocodes a free-form address.
   *
   * @param address unstructured postal address (e.g. {@code "350 Fifth Ave, New York, NY"})
   * @return a {@link GeocodeResult} carrying coordinates on success or an
   *         informative {@link GeocodeStatus} on a known failure mode
   */
  GeocodeResult geocode(String address);
}