/**
 * Outcome of a {@link GoogleMapsApi#geocode} call. v3 of the Geocoding API
 * carried a top-level {@code status} string; v4 omits it. Callers don't need
 * to care — the client derives this enum from HTTP status + result-array
 * emptiness so the contract stays stable across API versions.
 */
public enum GeocodeStatus {
  OK,
  ZERO_RESULTS,
  OVER_QUERY_LIMIT,
  REQUEST_DENIED,
  INVALID_REQUEST,
  UNKNOWN_ERROR
}