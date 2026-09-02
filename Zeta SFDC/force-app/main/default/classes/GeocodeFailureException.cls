/**
 * Thrown by {@link GeocodeAddressInvocable} when geocoding fails — blank input,
 * zero results, request denied, over quota, or any other non-OK
 * {@link GeocodeStatus}. The underlying status is included in the message so
 * Flow fault paths can distinguish modes without a separate field on the
 * invocable's Result.
 */
public with sharing class GeocodeFailureException extends Exception {
}