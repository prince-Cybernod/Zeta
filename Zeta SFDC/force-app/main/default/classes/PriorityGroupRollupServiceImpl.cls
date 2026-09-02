/**
 * Implementation of {@link PriorityGroupRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class PriorityGroupRollupServiceImpl implements PriorityGroupRollupService {
  private final DatabaseRepo databaseRepo;

  public PriorityGroupRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private PriorityGroupRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT Related_Application__c, MIN(Priority_Group__c) minGroup ' +
      'FROM Priority_Item__c ' +
      'WHERE Related_Application__c IN :individualApplicationIds ' +
      'AND Review_Status__c = :reviewStatus ' +
      'GROUP BY Related_Application__c';

    List<AggregateResult> results = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'individualApplicationIds' => individualApplicationIds,
        'reviewStatus' => PriorityItemConstants.REVIEW_STATUS_APPROVED
      }
    );

    List<PriorityGroupAggregateResult> wrappedResults = PriorityGroupAggregateResult.fromAggregateResults(
      results
    );
    processAggregateResults(individualApplicationIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> individualApplicationIds,
    List<PriorityGroupAggregateResult> wrappedResults
  ) {
    Map<Id, Decimal> minGroupByApplicationId = new Map<Id, Decimal>();
    for (Id appId : individualApplicationIds) {
      minGroupByApplicationId.put(appId, null);
    }

    for (PriorityGroupAggregateResult result : wrappedResults) {
      minGroupByApplicationId.put(result.relatedApplicationId, result.minPriorityGroup);
    }

    List<IndividualApplication> applicationsToUpdate = new List<IndividualApplication>();
    for (Id appId : minGroupByApplicationId.keySet()) {
      applicationsToUpdate.add(
        new IndividualApplication(
          Id = appId,
          Relationship_Priority_Group__c = minGroupByApplicationId.get(appId)
        )
      );
    }

    if (!applicationsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(applicationsToUpdate);
    }
  }
}