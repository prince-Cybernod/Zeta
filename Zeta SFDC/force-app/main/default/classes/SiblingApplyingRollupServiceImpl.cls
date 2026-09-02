/**
 * Implementation of {@link SiblingApplyingRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class SiblingApplyingRollupServiceImpl implements SiblingApplyingRollupService {
  private final DatabaseRepo databaseRepo;

  public SiblingApplyingRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private SiblingApplyingRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    // "Count of Sibling Applying" is the number of approved sibling-applying
    // Priority Items whose APPLICANT is this application. The applicant is the
    // Related_Application__c (Sibling_Application__c points at the sibling's
    // application), so the count must be grouped by Related_Application__c.
    String query =
      'SELECT Related_Application__c, COUNT(Id) cnt ' +
      'FROM Priority_Item__c ' +
      'WHERE Related_Application__c IN :individualApplicationIds ' +
      'AND Priority_Type__c = :priorityType ' +
      'AND Review_Status__c = :reviewStatus ' +
      'GROUP BY Related_Application__c';

    List<AggregateResult> results = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'individualApplicationIds' => individualApplicationIds,
        'priorityType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        'reviewStatus' => PriorityItemConstants.REVIEW_STATUS_APPROVED
      }
    );

    List<SiblingApplyingAggregateResult> wrappedResults = SiblingApplyingAggregateResult.fromAggregateResults(
      results
    );
    processAggregateResults(individualApplicationIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> individualApplicationIds,
    List<SiblingApplyingAggregateResult> wrappedResults
  ) {
    Map<Id, Decimal> countsByApplicationId = new Map<Id, Decimal>();
    for (Id appId : individualApplicationIds) {
      countsByApplicationId.put(appId, 0);
    }

    for (SiblingApplyingAggregateResult result : wrappedResults) {
      countsByApplicationId.put(result.applicationId, result.count);
    }

    List<IndividualApplication> applicationsToUpdate = new List<IndividualApplication>();
    for (Id appId : countsByApplicationId.keySet()) {
      applicationsToUpdate.add(
        new IndividualApplication(
          Id = appId,
          Count_of_Sibling_Applying__c = countsByApplicationId.get(appId)
        )
      );
    }

    if (!applicationsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(applicationsToUpdate);
    }
  }
}