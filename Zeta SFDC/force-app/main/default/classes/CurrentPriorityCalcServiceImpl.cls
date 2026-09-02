/**
 * Implementation of {@link CurrentPriorityCalcService}.
 *
 * Uses SystemModeDatabaseRepo for trigger-context operations where sharing
 * rules must be bypassed to ensure data integrity across all records.
 */
public with sharing class CurrentPriorityCalcServiceImpl implements CurrentPriorityCalcService {
  private static final Integer PRIORITY_GROUP_SIBLING = 1;
  private static final Integer PRIORITY_GROUP_STAFF = 2;
  private static final Integer PRIORITY_GROUP_IN_DISTRICT = 3;
  private static final Integer PRIORITY_GROUP_GENERAL = 4;

  private final DatabaseRepo databaseRepo;

  public CurrentPriorityCalcServiceImpl() {
    this(new SystemModeDatabaseRepo());
  }

  @TestVisible
  private CurrentPriorityCalcServiceImpl(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public void calculateForRecords(List<AcademicInterest> academicInterests) {
    if (academicInterests == null || academicInterests.isEmpty()) {
      return;
    }

    Set<Id> individualApplicationIds = new Set<Id>();
    for (AcademicInterest academicInterest : academicInterests) {
      if (String.isNotBlank(academicInterest.IndividualApplicationId)) {
        individualApplicationIds.add(academicInterest.IndividualApplicationId);
      }
    }

    if (individualApplicationIds.isEmpty()) {
      for (AcademicInterest academicInterest : academicInterests) {
        academicInterest.Current_Priority_Group__c = PRIORITY_GROUP_GENERAL;
      }
      return;
    }

    Map<Id, IndividualApplication> applicationMap = queryApplications(individualApplicationIds);

    for (AcademicInterest academicInterest : academicInterests) {
      IndividualApplication individualApplication = applicationMap.get(
        academicInterest.IndividualApplicationId
      );
      Integer priorityGroup = calculatePriorityGroup(
        individualApplication,
        academicInterest.In_District_Priority__c
      );

      academicInterest.Current_Priority_Group__c = priorityGroup;
    }
  }

  public void recalculateForApplications(Set<Id> individualApplicationIds) {
    if (individualApplicationIds == null || individualApplicationIds.isEmpty()) {
      return;
    }

    Map<Id, IndividualApplication> applicationMap = queryApplications(individualApplicationIds);
    List<AcademicInterest> childAcademicInterests = queryChildAcademicInterests(
      individualApplicationIds
    );

    List<AcademicInterest> academicInterestsToUpdate = new List<AcademicInterest>();

    for (AcademicInterest academicInterest : childAcademicInterests) {
      IndividualApplication individualApplication = applicationMap.get(
        academicInterest.IndividualApplicationId
      );
      Integer newPriorityGroup = calculatePriorityGroup(
        individualApplication,
        academicInterest.In_District_Priority__c
      );

      if (academicInterest.Current_Priority_Group__c != newPriorityGroup) {
        academicInterest.Current_Priority_Group__c = newPriorityGroup;

        // Only stamp date when lottery has run (Original != null) AND priority changed from original.
        // This ensures pre-lottery changes don't penalize students in waitlist sorting.
        Decimal originalPriority = academicInterest.Original_Priority_Group__c;
        if (originalPriority != null && originalPriority != newPriorityGroup) {
          academicInterest.Date_of_Current_Priority_Change__c = Datetime.now();
        }

        academicInterestsToUpdate.add(academicInterest);
      }
    }

    if (!academicInterestsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(academicInterestsToUpdate);
    }
  }

  private static Integer calculatePriorityGroup(
    IndividualApplication individualApplication,
    Boolean inDistrictPriority
  ) {
    if (individualApplication == null) {
      return PRIORITY_GROUP_GENERAL;
    }

    Decimal relationshipPriority = individualApplication.Relationship_Priority_Group__c;

    if (relationshipPriority == PRIORITY_GROUP_SIBLING) {
      return PRIORITY_GROUP_SIBLING;
    }
    if (relationshipPriority == PRIORITY_GROUP_STAFF) {
      return PRIORITY_GROUP_STAFF;
    }
    if (inDistrictPriority == true) {
      return PRIORITY_GROUP_IN_DISTRICT;
    }

    return PRIORITY_GROUP_GENERAL;
  }

  private Map<Id, IndividualApplication> queryApplications(Set<Id> applicationIds) {
    String query =
      'SELECT Id, Relationship_Priority_Group__c ' +
      'FROM IndividualApplication ' +
      'WHERE Id IN :applicationIds';

    List<IndividualApplication> applications = databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationIds' => applicationIds }
    );

    Map<Id, IndividualApplication> applicationMap = new Map<Id, IndividualApplication>();
    for (IndividualApplication individualApplication : applications) {
      applicationMap.put(individualApplication.Id, individualApplication);
    }

    return applicationMap;
  }

  private List<AcademicInterest> queryChildAcademicInterests(Set<Id> applicationIds) {
    String query =
      'SELECT Id, IndividualApplicationId, In_District_Priority__c, Current_Priority_Group__c, ' +
      'Original_Priority_Group__c ' +
      'FROM AcademicInterest ' +
      'WHERE IndividualApplicationId IN :applicationIds';

    return databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationIds' => applicationIds }
    );
  }
}