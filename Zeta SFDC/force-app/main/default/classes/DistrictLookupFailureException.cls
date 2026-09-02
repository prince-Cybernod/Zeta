/**
 * Thrown by {@link FindDistrictInvocable} when the lookup fails — null lat/lng
 * input or a point that falls outside every active District. Lets Flow fault
 * paths distinguish "out of district" from a normal result.
 */
public with sharing class DistrictLookupFailureException extends Exception {
}