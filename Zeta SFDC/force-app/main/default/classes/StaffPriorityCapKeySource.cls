/**
 * Source of random keys used to pick which pool applications lose staff priority.
 * Injected so tests can control draw order deterministically.
 */
public interface StaffPriorityCapKeySource {
  Decimal nextKey();
}