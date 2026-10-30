public without sharing class SchoolApplicationDecisionController {
  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();
  @TestVisible
  private static EventBusRepo eventBusRepo = new EventBusRepoImpl();

  private static final Set<String> OFFER_STATUSES = new Set<String>{
    'Seat Offered',
    'Offer Rescinded due to Seat Optimization'
  };
  private static final Set<String> LOWER_RANK_HOLD_STATUSES = new Set<String>{
    'Seat Offered',
    'Offer Rescinded due to Seat Optimization',
    'Waitlisted',
    'Submitted'
  };
  private static final String AUTO_CLOSED_REASON = 'Applicant accepted another offered seat';
  private static final String WELCOME_PHASE = '1. Welcome Phase';

  /**
   * Accepts an offer: the chosen AcademicInterest becomes Seat Accepted, every
   * other live offer on the application is declined (regardless of rank —
   * only one decision can stand), and lower-ranked waitlisted/submitted rows
   * are declined too, while higher-ranked ones are preserved so a parent can
   * still switch up later. Replicates Seat_Acceptance_Review_Autolaunched's
   * decline filter in Apex because that flow writes no picklist value and
   * would fail the live Require_Withdraw_Rescind_Reason rule.
   */
  @AuraEnabled
  public static void acceptOffer(Id applicationId, Id academicInterestId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotNull(academicInterestId, 'School application Id is required');

    AcademicInterest target = requireOwnedInterest(applicationId, academicInterestId);
    Preconditions.checkArgument(
      OFFER_STATUSES.contains(target.Status),
      'This offer is no longer available to accept.'
    );

    List<AcademicInterest> siblings = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Status, School_Rank__c' +
        ' FROM AcademicInterest' +
        ' WHERE IndividualApplicationId = :applicationId AND Id != :academicInterestId',
      new Map<String, Object>{
        'applicationId' => applicationId,
        'academicInterestId' => academicInterestId
      }
    );

    List<AcademicInterest> toDecline = new List<AcademicInterest>();
    AcademicInterest priorAccepted = null;
    for (AcademicInterest sibling : siblings) {
      if (sibling.Status == 'Seat Accepted') {
        priorAccepted = sibling;
        continue;
      }
      if (OFFER_STATUSES.contains(sibling.Status)) {
        toDecline.add(sibling);
      } else if (
        LOWER_RANK_HOLD_STATUSES.contains(sibling.Status) &&
        sibling.School_Rank__c > target.School_Rank__c
      ) {
        toDecline.add(sibling);
      }
    }

    if (priorAccepted != null) {
      requireWelcomePhaseSwitch(priorAccepted.Id);
      toDecline.add(priorAccepted);
    }

    Set<Id> closedIds = new Set<Id>();
    List<SObject> toUpdate = new List<SObject>();
    for (AcademicInterest sibling : toDecline) {
      sibling.Status = 'Withdrawn/Declined';
      sibling.Withdrawn_Declined_Reason_Picklist__c = 'Other';
      sibling.Declined_Withdrawn_Reason__c = AUTO_CLOSED_REASON;
      toUpdate.add(sibling);
      closedIds.add(sibling.Id);
    }

    target.Status = 'Seat Accepted';
    toUpdate.add(target);

    if (closedIds.contains(target.IndividualApplication.Current_School_Offer__c)) {
      toUpdate.add(
        new IndividualApplication(Id = applicationId, Current_School_Offer__c = academicInterestId)
      );
    }

    databaseRepo.updateSObjects(toUpdate);
    publishRegenerationEvent(applicationId);
  }

  /**
   * Declines an offer via the schema picklist. The optional comment is kept for
   * any reason and is required for 'Other'. Declining the application's current
   * offer moves Current_School_Offer__c to the best-ranked remaining offer, or
   * to the accepted seat when no offer remains.
   */
  @AuraEnabled
  public static void declineOffer(
    Id applicationId,
    Id academicInterestId,
    String picklistReason,
    String reason
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotNull(academicInterestId, 'School application Id is required');
    Preconditions.checkNotBlank(picklistReason, 'A decline reason is required');
    String comment = String.isBlank(reason) ? null : reason.trim();
    Preconditions.checkArgument(
      picklistReason != 'Other' || comment != null,
      System.Label.AppUI_DeclineCommentRequired
    );

    AcademicInterest target = requireOwnedInterest(applicationId, academicInterestId);
    Preconditions.checkArgument(
      OFFER_STATUSES.contains(target.Status),
      'This offer is no longer available to decline.'
    );

    target.Status = 'Withdrawn/Declined';
    target.Withdrawn_Declined_Reason_Picklist__c = picklistReason;
    target.Declined_Withdrawn_Reason__c = comment;

    List<SObject> toUpdate = new List<SObject>{ target };
    if (target.IndividualApplication.Current_School_Offer__c == academicInterestId) {
      toUpdate.add(
        new IndividualApplication(
          Id = applicationId,
          Current_School_Offer__c = nextBestOfferId(applicationId, academicInterestId)
        )
      );
    }
    databaseRepo.updateSObjects(toUpdate);
    publishRegenerationEvent(applicationId);
  }

  /**
   * Returns the student's first name for the accept-offer warning, falling back
   * to the full name when the first name is blank. Applies the same ownership
   * rule as acceptOffer.
   */
  @AuraEnabled(cacheable=true)
  public static String getStudentFirstName(Id applicationId) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');

    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      'SELECT Id, SubmittedByContactId, Account.FirstName, Account.Name' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(!apps.isEmpty(), 'Application not found: ' + applicationId);
    requireCallerOwns(applicationId, apps[0].SubmittedByContactId);

    Account student = apps[0].Account;
    if (student == null) {
      return null;
    }
    return String.isBlank(student.FirstName) ? student.Name : student.FirstName;
  }

  // Best-ranked (lowest School_Rank__c) of the other live offers. An unranked
  // offer only wins when no ranked one is left, and on equal rank Seat Offered
  // beats a rescinded offer. With no offer left, the Seat Accepted row; null
  // when neither exists.
  private static Id nextBestOfferId(Id applicationId, Id excludedId) {
    List<AcademicInterest> siblings = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Status, School_Rank__c' +
        ' FROM AcademicInterest' +
        ' WHERE IndividualApplicationId = :applicationId AND Id != :excludedId' +
        ' ORDER BY School_Rank__c ASC NULLS LAST, CreatedDate ASC',
      new Map<String, Object>{ 'applicationId' => applicationId, 'excludedId' => excludedId }
    );
    AcademicInterest best = null;
    AcademicInterest accepted = null;
    for (AcademicInterest sibling : siblings) {
      if (sibling.Status == 'Seat Accepted' && accepted == null) {
        accepted = sibling;
      }
      if (!OFFER_STATUSES.contains(sibling.Status)) {
        continue;
      }
      if (outranks(sibling, best)) {
        best = sibling;
      }
    }
    return best?.Id ?? accepted?.Id;
  }

  private static Boolean outranks(AcademicInterest candidate, AcademicInterest best) {
    if (best == null) {
      return true;
    }
    if (candidate.School_Rank__c == best.School_Rank__c) {
      return candidate.Status == 'Seat Offered' && best.Status != 'Seat Offered';
    }
    return candidate.School_Rank__c != null &&
      (best.School_Rank__c == null ||
      candidate.School_Rank__c < best.School_Rank__c);
  }

  // Loads the target AcademicInterest and enforces ownership. A portal caller
  // (one with a session Contact) must own the application via
  // SubmittedByContactId, matching withdrawSchoolApplication's existing
  // check. An internal/no-session caller skips that equality: many real
  // applications have no SubmittedByContactId, so the internal view is
  // gated by its own permission set's class access instead.
  private static AcademicInterest requireOwnedInterest(Id applicationId, Id academicInterestId) {
    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      'SELECT Id, Status, School_Rank__c, IndividualApplicationId,' +
        ' IndividualApplication.SubmittedByContactId,' +
        ' IndividualApplication.Current_School_Offer__c' +
        ' FROM AcademicInterest' +
        ' WHERE Id = :academicInterestId AND IndividualApplicationId = :applicationId' +
        ' LIMIT 1',
      new Map<String, Object>{
        'academicInterestId' => academicInterestId,
        'applicationId' => applicationId
      }
    );
    Preconditions.checkArgument(
      !interests.isEmpty(),
      'School application not found: ' + academicInterestId
    );
    AcademicInterest target = interests[0];
    requireCallerOwns(applicationId, target.IndividualApplication.SubmittedByContactId);
    return target;
  }

  private static void requireCallerOwns(Id applicationId, Id submittedByContactId) {
    if (isPortalCaller()) {
      Id callerContactId = ApplicationContext.resolveGuardianContactId(databaseRepo, applicationId);
      Preconditions.checkArgument(
        callerContactId != null && callerContactId == submittedByContactId,
        'You can only respond to your own offers.'
      );
    }
  }

  // True when the running user has a Contact on their User record (a portal
  // session). Internal/system users have none, so this is also how
  // requireCallerOwns tells a staff caller apart from a parent's.
  private static Boolean isPortalCaller() {
    Id userId = UserInfo.getUserId();
    List<User> users = (List<User>) databaseRepo.queryWithBinds(
      'SELECT ContactId FROM User WHERE Id = :userId LIMIT 1',
      new Map<String, Object>{ 'userId' => userId }
    );
    return !users.isEmpty() && users[0].ContactId != null;
  }

  // A parent may only switch away from an already-accepted seat while its
  // enrollment is in Welcome Phase. No ATE row yet means nothing is
  // enrolled to protect, so the switch is allowed.
  private static void requireWelcomePhaseSwitch(Id priorAcceptedId) {
    List<AcademicTermEnrollment> enrollments = (List<AcademicTermEnrollment>) databaseRepo.queryWithBinds(
      'SELECT Id, EnrollmentStatus FROM AcademicTermEnrollment' +
      ' WHERE School_Application__c = :priorAcceptedId LIMIT 1',
      new Map<String, Object>{ 'priorAcceptedId' => priorAcceptedId }
    );
    if (enrollments.isEmpty()) {
      return;
    }
    Preconditions.checkArgument(
      enrollments[0].EnrollmentStatus == WELCOME_PHASE,
      'This enrollment can no longer be switched; contact Zeta to transfer.'
    );
  }

  // Keeps the File PDF current for the decision, mirroring
  // SchoolRankingController.saveRankings/withdrawSchoolApplication (drafts
  // have no PDF yet; every real accept/decline here is post-offer, so
  // AppliedDate is always set, but the guard is kept for parity).
  private static void publishRegenerationEvent(Id applicationId) {
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      'SELECT AppliedDate FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (!apps.isEmpty() && apps[0].AppliedDate != null) {
      eventBusRepo.publish(new Application_Submitted_Event__e(Application_Id__c = applicationId));
    }
  }
}