/**
 * Implementation of {@link EmployeePriorityRollupService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public without sharing class EmployeePriorityRollupServiceImpl implements EmployeePriorityRollupService {
  private final DatabaseRepo databaseRepo;

  public EmployeePriorityRollupServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private EmployeePriorityRollupServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void recalculate(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    String academicInterestQuery =
      'SELECT Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgramId, ' +
      'IndividualApplicationId ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :individualApplicationIds';

    List<AcademicInterest> academicInterests = databaseRepo.queryWithBinds(
      academicInterestQuery,
      new Map<String, Object>{ 'individualApplicationIds' => individualApplicationIds }
    );

    Map<Id, Set<Id>> applicationIdsByProgramId = new Map<Id, Set<Id>>();
    Set<Id> learningProgramIds = new Set<Id>();

    for (AcademicInterest ai : academicInterests) {
      Id programId = (Id) ai.getSObject('Lottery_Capacity__r')
        ?.getSObject('Program_Term_Application_Timeline__r')
        ?.get('LearningProgramId');
      if (programId != null) {
        learningProgramIds.add(programId);
        if (!applicationIdsByProgramId.containsKey(programId)) {
          applicationIdsByProgramId.put(programId, new Set<Id>());
        }
        if (ai.IndividualApplicationId != null) {
          applicationIdsByProgramId.get(programId).add(ai.IndividualApplicationId);
        }
      }
    }

    if (learningProgramIds.isEmpty()) {
      return;
    }

    // Re-query ALL applications for affected programs, not just the triggering ones
    String allAppsQuery =
      'SELECT Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgramId, ' +
      'IndividualApplicationId ' +
      'FROM AcademicInterest ' +
      'WHERE Lottery_Capacity__r.Program_Term_Application_Timeline__r.LearningProgramId IN :learningProgramIds';

    List<AcademicInterest> allAcademicInterests = databaseRepo.queryWithBinds(
      allAppsQuery,
      new Map<String, Object>{ 'learningProgramIds' => learningProgramIds }
    );

    applicationIdsByProgramId.clear();
    Set<Id> allApplicationIds = new Set<Id>();
    for (Id programId : learningProgramIds) {
      applicationIdsByProgramId.put(programId, new Set<Id>());
    }

    for (AcademicInterest ai : allAcademicInterests) {
      Id programId = (Id) ai.getSObject('Lottery_Capacity__r')
        ?.getSObject('Program_Term_Application_Timeline__r')
        ?.get('LearningProgramId');
      if (programId != null && ai.IndividualApplicationId != null) {
        applicationIdsByProgramId.get(programId).add(ai.IndividualApplicationId);
        allApplicationIds.add(ai.IndividualApplicationId);
      }
    }

    Map<Id, Integer> countsByApplicationId = new Map<Id, Integer>();
    if (!allApplicationIds.isEmpty()) {
      String priorityItemQuery =
        'SELECT Related_Application__c, COUNT(Id) cnt ' +
        'FROM Priority_Item__c ' +
        'WHERE Related_Application__c IN :applicationIds ' +
        'AND Priority_Type__c = :priorityType ' +
        'AND Review_Status__c = :reviewStatus ' +
        'GROUP BY Related_Application__c';

      List<AggregateResult> results = databaseRepo.queryWithBinds(
        priorityItemQuery,
        new Map<String, Object>{
          'applicationIds' => allApplicationIds,
          'priorityType' => PriorityItemConstants.PRIORITY_TYPE_PARENT_IS_ZETA_STAFF,
          'reviewStatus' => PriorityItemConstants.REVIEW_STATUS_APPROVED
        }
      );

      List<EmployeePriorityAggregateResult> wrappedResults = EmployeePriorityAggregateResult.fromAggregateResults(
        results
      );
      for (EmployeePriorityAggregateResult result : wrappedResults) {
        countsByApplicationId.put(result.relatedApplicationId, (Integer) result.count);
      }
    }

    processResults(learningProgramIds, applicationIdsByProgramId, countsByApplicationId);
  }

  @TestVisible
  private void processResults(
    Set<Id> learningProgramIds,
    Map<Id, Set<Id>> applicationIdsByProgramId,
    Map<Id, Integer> countsByApplicationId
  ) {
    List<LearningProgram> programsToUpdate = new List<LearningProgram>();
    for (Id programId : learningProgramIds) {
      Integer totalCount = 0;
      Set<Id> appIds = applicationIdsByProgramId.get(programId);
      if (appIds != null) {
        for (Id appId : appIds) {
          Integer appCount = countsByApplicationId.get(appId);
          if (appCount != null) {
            totalCount += appCount;
          }
        }
      }

      programsToUpdate.add(
        new LearningProgram(Id = programId, Count_Lottery_Employee_Priority__c = totalCount)
      );
    }

    if (!programsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(programsToUpdate);
    }
  }
}