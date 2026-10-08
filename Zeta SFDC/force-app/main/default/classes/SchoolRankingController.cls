public without sharing class SchoolRankingController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @TestVisible
  private static EventBusRepo eventBusRepo = new EventBusRepoImpl();

  @AuraEnabled
  public static List<Map<String, Object>> getRankedSchools(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    String query =
      'SELECT Id, LearningProgramId,' +
      ' LearningProgram.School__c, LearningProgram.School__r.Name,' +
      ' LearningProgram.School__r.Zeta_School_Name__c, School_Rank__c, Status' +
      ' FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId' +
      ' ORDER BY School_Rank__c ASC NULLS LAST';
    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    List<Map<String, Object>> schools = new List<Map<String, Object>>();
    for (AcademicInterest ai : interests) {
      Account school = ai.LearningProgram?.School__r;
      Map<String, Object> schoolData = new Map<String, Object>();
      schoolData.put('academicInterestId', ai.Id);
      schoolData.put('schoolAccountId', ai.LearningProgram?.School__c);
      schoolData.put(
        'name',
        school?.Zeta_School_Name__c != null ? school.Zeta_School_Name__c : school?.Name
      );
      schoolData.put('rank', ai.School_Rank__c);
      schoolData.put('status', ai.Status);
      schools.add(schoolData);
    }
    return schools;
  }

  @AuraEnabled
  public static void saveRankings(Id applicationId, String rankingsJson) {
    Preconditions.checkNotNull(applicationId, System.Label.AppUI_ApplicationIdRequired);
    Preconditions.checkNotBlank(rankingsJson, System.Label.AppUI_RankingsJsonRequired);

    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      'SELECT Status, AppliedDate FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(
      !apps.isEmpty(),
      String.format(System.Label.AppUI_ApplicationNotFoundWithId, new List<Object>{ applicationId })
    );
    Preconditions.checkArgument(
      apps[0].Status != 'Withdrawn/Declined',
      System.Label.AppUI_CannotRankWithdrawnApplication
    );

    List<Object> rankings = (List<Object>) JSON.deserializeUntyped(rankingsJson);
    List<AcademicInterest> toUpdate = new List<AcademicInterest>();

    for (Object entry : rankings) {
      Map<String, Object> r = (Map<String, Object>) entry;

      Map<String, Object> fields = new Map<String, Object>();
      fields.put('Id', r.get('academicInterestId'));
      fields.put('School_Rank__c', r.get('rank'));

      toUpdate.add(
        (AcademicInterest) JSON.deserialize(JSON.serialize(fields), AcademicInterest.class)
      );
    }

    if (!toUpdate.isEmpty()) {
      databaseRepo.updateSObjects(toUpdate);
    }

    // Rankings is the only post-submit edit the portal exposes. When the app is
    // already submitted (AppliedDate set), regenerate the File PDF so it stays
    // current; drafts have no PDF yet (generated at submit) and are skipped.
    // Regeneration goes through the same platform event submission publishes so
    // the PDF is always written by the automated process user: a parent has no
    // network context in async Apex and cannot create the File themselves.
    if (apps[0].AppliedDate != null) {
      eventBusRepo.publish(new Application_Submitted_Event__e(Application_Id__c = applicationId));
    }
  }

  /**
   * Withdraws a single ranked school choice (one AcademicInterest) without
   * touching the rest of the application — the per-school counterpart to
   * ApplicationDashboardController.withdrawApplication. Sets the interest to
   * 'Withdrawn/Declined' and records the reason; the AcademicInterest trigger
   * then frees the seat (sibling-priority downgrade + lottery-capacity rollups).
   *
   * @param academicInterestId the school choice to withdraw
   * @param picklistReason     the selected Withdrawn/Declined reason
   * @param reason             free-text detail (only when the reason is 'Other')
   */
  @AuraEnabled
  public static void withdrawSchoolApplication(
    Id academicInterestId,
    String picklistReason,
    String reason
  ) {
    Preconditions.checkNotNull(academicInterestId, System.Label.AppUI_SchoolApplicationIdRequired);
    Preconditions.checkNotBlank(picklistReason, System.Label.AppUI_WithdrawalReasonRequired);

    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Status, IndividualApplicationId,' +
        ' IndividualApplication.AppliedDate, IndividualApplication.SubmittedByContactId' +
        ' FROM AcademicInterest WHERE Id = :academicInterestId LIMIT 1',
      new Map<String, Object>{ 'academicInterestId' => academicInterestId }
    );
    Preconditions.checkArgument(
      !interests.isEmpty(),
      String.format(System.Label.AppUI_SchoolApplicationNotFound, new List<Object>{ academicInterestId })
    );
    AcademicInterest ai = interests[0];

    // Ownership: a parent may only withdraw schools on their own application.
    Id contactId = getLoggedInContactId();
    Preconditions.checkArgument(
      contactId != null && ai.IndividualApplication.SubmittedByContactId == contactId,
      System.Label.AppUI_WithdrawOwnSchoolsOnly
    );

    // Idempotency guard — a withdrawn school can't be withdrawn again.
    Preconditions.checkArgument(
      ai.Status != 'Withdrawn/Declined',
      System.Label.AppUI_SchoolAlreadyWithdrawn
    );

    ai.Status = 'Withdrawn/Declined';
    ai.Withdrawn_Declined_Reason_Picklist__c = picklistReason;
    // Mirror ApplicationDashboardController: the free-text detail is only
    // meaningful for 'Other'; blank it otherwise so a stale detail can't linger.
    ai.Declined_Withdrawn_Reason__c = picklistReason == 'Other' ? reason : null;
    databaseRepo.updateSObjects(new List<SObject>{ ai });

    // Keep the File PDF current for already-submitted applications, mirroring
    // saveRankings (drafts have no PDF yet).
    if (ai.IndividualApplication.AppliedDate != null) {
      eventBusRepo.publish(
        new Application_Submitted_Event__e(Application_Id__c = ai.IndividualApplicationId)
      );
    }
  }

  private static Id getLoggedInContactId() {
    return ApplicationContext.resolveGuardianContactId(databaseRepo, null);
  }
}