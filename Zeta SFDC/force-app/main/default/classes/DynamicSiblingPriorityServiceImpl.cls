/**
 * Implementation of {@link DynamicSiblingPriorityService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public with sharing class DynamicSiblingPriorityServiceImpl implements DynamicSiblingPriorityService {
  private final DatabaseRepo databaseRepo;

  public DynamicSiblingPriorityServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private DynamicSiblingPriorityServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void handleUpgrade(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT Id, Related_Application__c, Sibling_Application__c ' +
      'FROM Priority_Item__c ' +
      'WHERE Sibling_Application__c IN :applicationIds ' +
      'AND Priority_Type__c = :priorityType ' +
      'AND Review_Status__c = :reviewStatus';

    List<Priority_Item__c> priorityItems = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'applicationIds' => individualApplicationIds,
        'priorityType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING,
        'reviewStatus' => PriorityItemConstants.REVIEW_STATUS_APPROVED
      }
    );

    if (priorityItems.isEmpty()) {
      return;
    }

    for (Priority_Item__c item : priorityItems) {
      item.Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING;
    }

    databaseRepo.updateSObjects(priorityItems);
  }

  public void handleDowngrade(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    String priorityQuery =
      'SELECT Id, Sibling_Application__c ' +
      'FROM Priority_Item__c ' +
      'WHERE Sibling_Application__c IN :individualApplicationIds ' +
      'AND Priority_Type__c = :priorityType';

    List<Priority_Item__c> priorityItems = databaseRepo.queryWithBinds(
      priorityQuery,
      new Map<String, Object>{
        'individualApplicationIds' => individualApplicationIds,
        'priorityType' => PriorityItemConstants.PRIORITY_TYPE_SIBLING_ATTENDING
      }
    );

    if (priorityItems.isEmpty()) {
      return;
    }

    Set<Id> siblingAppIds = new Set<Id>();
    for (Priority_Item__c item : priorityItems) {
      siblingAppIds.add(item.Sibling_Application__c);
    }

    Set<String> offerStatuses = new Set<String>{
      AcademicInterestConstants.STATUS_PRE_OFFER,
      AcademicInterestConstants.STATUS_SEAT_OFFERED,
      AcademicInterestConstants.STATUS_SEAT_ACCEPTED
    };

    String offersQuery =
      'SELECT IndividualApplicationId ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :siblingAppIds ' +
      'AND Status IN :offerStatuses';

    List<AcademicInterest> remainingOffers = databaseRepo.queryWithBinds(
      offersQuery,
      new Map<String, Object>{ 'siblingAppIds' => siblingAppIds, 'offerStatuses' => offerStatuses }
    );

    Set<Id> appsWithOffers = new Set<Id>();
    for (AcademicInterest interest : remainingOffers) {
      appsWithOffers.add(interest.IndividualApplicationId);
    }

    List<Priority_Item__c> itemsToUpdate = new List<Priority_Item__c>();
    for (Priority_Item__c item : priorityItems) {
      if (!appsWithOffers.contains(item.Sibling_Application__c)) {
        itemsToUpdate.add(
          new Priority_Item__c(
            Id = item.Id,
            Priority_Type__c = PriorityItemConstants.PRIORITY_TYPE_SIBLING_APPLYING
          )
        );
      }
    }

    if (!itemsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(itemsToUpdate);
    }
  }
}