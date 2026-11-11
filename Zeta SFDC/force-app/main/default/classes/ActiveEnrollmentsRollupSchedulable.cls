/**
 * Scheduled job that recomputes Active Enrollments counts every night.
 *
 * Recomputes every Guardian and Student Account, not just the ones an
 * enrollment DML touched today: a full sweep self-heals a term boundary that
 * flips with no enrollment edit, and a guardian changed on the learner's own
 * Account record, which the enrollment trigger can't see either way.
 *
 * Looks up {@link ActiveEnrollmentsRollupBatch} by name and calls
 * Database.executeBatch directly, so this class holds no compile-time
 * reference to the batch, the service or the shared repo classes. An active
 * scheduled job blocks deploying any class it references.
 *
 * Scheduled once, not repeated, by
 * scripts/data/migrations/schedule-active-enrollments-rollup.apex.
 */
public without sharing class ActiveEnrollmentsRollupSchedulable implements Schedulable {
  public void execute(SchedulableContext context) {
    Database.executeBatch(
      (Database.Batchable<SObject>) Type.forName('ActiveEnrollmentsRollupBatch').newInstance(),
      200
    );
  }
}