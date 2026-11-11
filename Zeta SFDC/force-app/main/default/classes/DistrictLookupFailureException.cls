/**
 * Thrown by {@link FindDistrictInvocable} when the lookup cannot be performed —
 * null lat/lng input, or an error raised by the lookup itself. A point that
 * falls outside every active District is a normal result, not a failure.
 */
public with sharing class DistrictLookupFailureException extends Exception {
}