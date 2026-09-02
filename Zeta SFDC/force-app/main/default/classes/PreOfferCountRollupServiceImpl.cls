/**
 * Implementation of {@link PreOfferCountRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class PreOfferCountRollupServiceImpl implements PreOfferCountRollupService {
  private final DatabaseRepo databaseRepo;

  // Track records currently being processed to prevent self-reference in cascade updates
  private static Set<Id> recordsBeingProcessed = new Set<Id>();

  /**
   * Registers record IDs that are currently being processed by a trigger.
   * Call this from the trigger handler before invoking recalculate().
   */
  public static void registerProcessingRecords(Set<Id> recordIds) {
    recordsBeingProcessed.addAll(recordIds);
  }

  /**
   * Clears the processing records set. Call after trigger completes.
   */
  public static void clearProcessingRecords() {
    recordsBeingProcessed.clear();
  }

  public PreOfferCountRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private PreOfferCountRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT IndividualApplicationId, COUNT(Id) cnt ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :individualApplicationIds ' +
      'AND Status = :preOfferStatus ' +
      'GROUP BY IndividualApplicationId';

    List<AggregateResult> results = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'individualApplicationIds' => individualApplicationIds,
        'preOfferStatus' => AcademicInterestConstants.STATUS_PRE_OFFER
      }
    );

    List<PreOfferCountAggregateResult> wrappedResults = PreOfferCountAggregateResult.fromAggregateResults(
      results
    );
    processAggregateResults(individualApplicationIds, wrappedResults);
  }

  @TestVisible
  private void processAggregateResults(
    Set<Id> individualApplicationIds,
    List<PreOfferCountAggregateResult> wrappedResults
  ) {
    Map<Id, Decimal> countsByApplicationId = new Map<Id, Decimal>();
    for (Id appId : individualApplicationIds) {
      countsByApplicationId.put(appId, 0);
    }

    for (PreOfferCountAggregateResult result : wrappedResults) {
      countsByApplicationId.put(result.individualApplicationId, result.count);
    }

    List<IndividualApplication> applicationsToUpdate = new List<IndividualApplication>();
    for (Id appId : countsByApplicationId.keySet()) {
      applicationsToUpdate.add(
        new IndividualApplication(
          Id = appId,
          Count_of_Pre_Offer_School_Applications__c = countsByApplicationId.get(appId)
        )
      );
    }

    if (!applicationsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(applicationsToUpdate);
    }

    cascadeToChildAcademicInterests(countsByApplicationId);
  }

  private void cascadeToChildAcademicInterests(Map<Id, Decimal> countsByApplicationId) {
    if (countsByApplicationId.isEmpty()) {
      return;
    }

    String query =
      'SELECT Id, IndividualApplicationId, Count_of_Pre_Offer_School_Applications__c ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :applicationIds';

    List<AcademicInterest> children = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationIds' => countsByApplicationId.keySet() }
    );

    List<AcademicInterest> childrenToUpdate = new List<AcademicInterest>();

    for (AcademicInterest child : children) {
      // Skip records currently being processed to prevent self-reference error
      if (recordsBeingProcessed.contains(child.Id)) {
        continue;
      }
      Decimal newCount = countsByApplicationId.get(child.IndividualApplicationId);
      if (child.Count_of_Pre_Offer_School_Applications__c != newCount) {
        child.Count_of_Pre_Offer_School_Applications__c = newCount;
        childrenToUpdate.add(child);
      }
    }

    if (!childrenToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(childrenToUpdate);
    }
  }
}