/**
 * Thrown by {@link FindNearestSchoolInvocable} when the lookup fails — null
 * lat/lng input, or no School Account with a geocoded billing address to match
 * against. Distinguishes those from a normal result.
 */
public with sharing class NearestSchoolLookupFailureException extends Exception {
}