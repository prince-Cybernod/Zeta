/**
 * Scheduled job that recomputes the Charter-level rollup every night.
 *
 * Recomputes every Charter, not just the ones whose linked timelines crossed
 * a boundary today: a full sweep costs about 3 SOQL per 200-Charter chunk,
 * and it self-heals the next night from a missed or failed run instead of
 * leaving a permanently stale number.
 *
 * Looks up {@link CharterRollupBatch} by name and calls Database.executeBatch
 * directly, so this class holds no compile-time reference to the batch, the
 * service or the shared repo classes. An active scheduled job blocks deploying
 * any class it references.
 *
 * Scheduled once, not repeated, by
 * scripts/data/migrations/schedule-charter-rollup.apex.
 */
public without sharing class CharterRollupSchedulable implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(
      (Database.Batchable<SObject>) Type.forName('CharterRollupBatch').newInstance(),
      200
    );
  }
}