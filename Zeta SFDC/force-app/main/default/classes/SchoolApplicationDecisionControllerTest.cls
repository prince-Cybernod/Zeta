@IsTest(IsParallel=true)
private class SchoolApplicationDecisionControllerTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;
  private static final EventBusRepoMock EVENT_BUS_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
    EVENT_BUS_REPO_MOCK = new EventBusRepoMock();
    SchoolApplicationDecisionController.databaseRepo = DATABASE_REPO_MOCK;
    SchoolApplicationDecisionController.eventBusRepo = EVENT_BUS_REPO_MOCK;
  }

  // The parent IndividualApplication/AcademicInterest relationship fields the
  // SObject constructor can't set are built via JSON.deserialize, the module
  // convention (see SchoolRankingControllerTest.buildInterest).
  private static AcademicInterest buildAi(
    Id aiId,
    Id appId,
    String status,
    Decimal rank,
    Id submittedBy
  ) {
    return buildAi(aiId, appId, status, rank, submittedBy, null);
  }

  private static AcademicInterest buildAi(
    Id aiId,
    Id appId,
    String status,
    Decimal rank,
    Id submittedBy,
    Id currentSchoolOfferId
  ) {
    String submittedByJson = submittedBy == null ? 'null' : '"' + submittedBy + '"';
    String currentSchoolOfferJson = currentSchoolOfferId == null
      ? 'null'
      : '"' + currentSchoolOfferId + '"';
    return (AcademicInterest) JSON.deserialize(
      '{' +
        '"Id":"' +
        aiId +
        '","Status":"' +
        status +
        '","School_Rank__c":' +
        (rank == null ? 'null' : String.valueOf(rank)) +
        ',"IndividualApplicationId":"' +
        appId +
        '","IndividualApplication":{"Id":"' +
        appId +
        '","SubmittedByContactId":' +
        submittedByJson +
        ',"Current_School_Offer__c":' +
        currentSchoolOfferJson +
        '}}',
      AcademicInterest.class
    );
  }

  private static User internalUser() {
    return new User(Id = UserInfo.getUserId(), ContactId = null);
  }

  private static User portalUser(Id contactId) {
    return new User(Id = UserInfo.getUserId(), ContactId = contactId);
  }

  private static IndividualApplication appWithAppliedDate(Boolean applied) {
    return new IndividualApplication(AppliedDate = applied ? Datetime.now() : null);
  }

  private static IndividualApplication buildAppWithStudent(
    Id appId,
    Id submittedBy,
    String firstName,
    String fullName
  ) {
    String submittedByJson = submittedBy == null ? 'null' : '"' + submittedBy + '"';
    String firstNameJson = firstName == null ? 'null' : '"' + firstName + '"';
    return (IndividualApplication) JSON.deserialize(
      '{"Id":"' +
        appId +
        '","SubmittedByContactId":' +
        submittedByJson +
        ',"Account":{"FirstName":' +
        firstNameJson +
        ',"Name":"' +
        fullName +
        '"}}',
      IndividualApplication.class
    );
  }

  private static List<SObject> updateCallSObjects() {
    List<Map<String, Object>> calls = DATABASE_REPO_MOCK.getCalls(
      DATABASE_REPO_MOCK.method.updateSObjects()
    );
    Assert.areEqual(1, calls.size(), 'Expected exactly one updateSObjects call');
    return (List<SObject>) calls[0].get('sobjects');
  }

  private static IndividualApplication updatedApplication(List<SObject> updated) {
    for (SObject sObj : updated) {
      if (sObj.getSObjectType() == IndividualApplication.SObjectType) {
        return (IndividualApplication) sObj;
      }
    }
    return null;
  }

  // --- acceptOffer: the decline cascade ---------------------------------
  // Reversing the School_Rank__c > target.School_Rank__c comparison in the
  // Waitlisted/Submitted branch makes the higher-ranked Waitlisted sibling
  // (sA) read as declined instead of surviving.
  @IsTest
  private static void acceptOffer_cascade_keepsHigherRankedWaitlist_declinesOthers() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id aId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id bId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id cId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id dId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id eId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 3, null);
    // sA: higher-ranked (rank 1) Waitlisted — must survive (the canary).
    AcademicInterest sA = buildAi(aId, appId, 'Waitlisted', 1, null);
    // sB: higher-ranked (rank 2) Seat Offered — declined anyway: only one
    // live offer decision can stand (ticket's lower-ranked-offer rule).
    AcademicInterest sB = buildAi(bId, appId, 'Seat Offered', 2, null);
    // sC: lower-ranked (rank 5) Seat Offered — declined.
    AcademicInterest sC = buildAi(cId, appId, 'Offer Rescinded due to Seat Optimization', 5, null);
    // sD: lower-ranked (rank 6) Waitlisted — declined.
    AcademicInterest sD = buildAi(dId, appId, 'Waitlisted', 6, null);
    // sE: already withdrawn — untouched (neither bucket).
    AcademicInterest sE = buildAi(eId, appId, 'Withdrawn/Declined', 7, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target }) // requireOwnedInterest
      .thenReturn(new List<User>{ internalUser() }) // isPortalCaller -> internal
      .thenReturn(new List<AcademicInterest>{ sA, sB, sC, sD, sE }) // siblings
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) }); // publish check
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Map<Id, SObject> byId = new Map<Id, SObject>();
    for (SObject s : updated) {
      byId.put((Id) s.get('Id'), s);
    }
    Assert.isFalse(byId.containsKey(aId), 'Higher-ranked Waitlisted sibling must survive');
    Assert.areEqual(
      'Withdrawn/Declined',
      (String) byId.get(bId).get('Status'),
      'Higher-ranked live offer is declined too — only one offer decision stands'
    );
    Assert.areEqual('Withdrawn/Declined', (String) byId.get(cId).get('Status'));
    Assert.areEqual('Withdrawn/Declined', (String) byId.get(dId).get('Status'));
    Assert.isFalse(byId.containsKey(eId), 'Already-withdrawn sibling is untouched');
    Assert.areEqual('Other', (String) byId.get(bId).get('Withdrawn_Declined_Reason_Picklist__c'));
    Assert.areEqual(
      'Applicant accepted another offered seat',
      (String) byId.get(bId).get('Declined_Withdrawn_Reason__c')
    );
    Assert.areEqual('Seat Accepted', (String) byId.get(targetId).get('Status'));
    EVENT_BUS_REPO_MOCK.never(EVENT_BUS_REPO_MOCK.method.publishSingle());
  }

  // Null School_Rank__c on the target: the rank comparison is null > 5 (not
  // true), so a lower-ranked Waitlisted sibling is NOT closed by the rank
  // branch — only OFFER_STATUSES siblings are closed regardless of rank.
  @IsTest
  private static void acceptOffer_targetWithNullRank_doesNotCloseWaitlistedSibling() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id waitlistedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', null, null);
    AcademicInterest waitlisted = buildAi(waitlistedId, appId, 'Waitlisted', 5, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ waitlisted })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual(
      1,
      updated.size(),
      'Only the target should update; the waitlisted row survives'
    );
    Assert.areEqual(targetId, (Id) updated[0].get('Id'));
  }

  // Current_School_Offer__c points at a sibling acceptOffer auto-closes —
  // the pointer must repoint to the newly accepted row in the same call.
  @IsTest
  private static void acceptOffer_currentSchoolOfferPointsAtClosedSibling_repointsToAccepted() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id siblingId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, siblingId);
    AcademicInterest sibling = buildAi(siblingId, appId, 'Seat Offered', 2, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target }) // requireOwnedInterest
      .thenReturn(new List<User>{ internalUser() }) // isPortalCaller -> internal
      .thenReturn(new List<AcademicInterest>{ sibling }) // siblings
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) }); // publish check
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    IndividualApplication updatedApp = null;
    for (SObject sObj : updated) {
      if (sObj.getSObjectType() == IndividualApplication.SObjectType) {
        updatedApp = (IndividualApplication) sObj;
      }
    }
    Assert.isNotNull(updatedApp, 'Expected the application to be repointed in the same call');
    Assert.areEqual(appId, updatedApp.Id);
    Assert.areEqual(targetId, updatedApp.Current_School_Offer__c);
  }

  // Current_School_Offer__c already points at the accepted row — no-op.
  @IsTest
  private static void acceptOffer_currentSchoolOfferAlreadyAccepted_leavesItUnchanged() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id siblingId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);
    AcademicInterest sibling = buildAi(siblingId, appId, 'Seat Offered', 2, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ sibling })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual(
      2,
      updated.size(),
      'Only the declined sibling and the target should update; the pointer is already correct'
    );
    for (SObject sObj : updated) {
      Assert.areNotEqual(
        IndividualApplication.SObjectType,
        sObj.getSObjectType(),
        'The application must not be touched when the pointer is already correct'
      );
    }
  }

  // Current_School_Offer__c points at a row acceptOffer does not touch —
  // unchanged.
  @IsTest
  private static void acceptOffer_currentSchoolOfferPointsAtUntouchedRow_leavesItUnchanged() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id survivingId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id otherAiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 3, null, otherAiId);
    // Higher-ranked Waitlisted sibling — survives the cascade untouched.
    AcademicInterest surviving = buildAi(survivingId, appId, 'Waitlisted', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ surviving })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual(1, updated.size(), 'Only the target should update');
    Assert.areEqual(targetId, updated[0].Id);
  }

  // --- Accept blocked outside the offer-eligible statuses ------------------
  @IsTest
  private static void acceptOffer_notOfferEligible_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Waitlisted', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolApplicationDecisionController.acceptOffer(appId, targetId);
      Assert.fail('Expected an exception for a non-offer-eligible status');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('no longer available to accept'), e.getMessage());
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size()
    );
  }

  // --- Welcome-phase switch guard -------------------------------------------
  @IsTest
  private static void acceptOffer_switchBlockedOutsideWelcomePhase_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id priorAcceptedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);
    AcademicInterest priorAccepted = buildAi(priorAcceptedId, appId, 'Seat Accepted', 2, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ priorAccepted })
      .thenReturn(
        new List<AcademicTermEnrollment>{
          new AcademicTermEnrollment(EnrollmentStatus = '2. Registration Phase')
        }
      );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolApplicationDecisionController.acceptOffer(appId, targetId);
      Assert.fail('Expected an exception outside Welcome Phase');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('transfer'), e.getMessage());
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size(),
      'A blocked switch must not update any record'
    );
  }

  @IsTest
  private static void acceptOffer_switchAllowedInWelcomePhase_declinesPriorAccepted() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id priorAcceptedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);
    AcademicInterest priorAccepted = buildAi(priorAcceptedId, appId, 'Seat Accepted', 2, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ priorAccepted })
      .thenReturn(
        new List<AcademicTermEnrollment>{
          new AcademicTermEnrollment(EnrollmentStatus = '1. Welcome Phase')
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(true) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Map<Id, SObject> byId = new Map<Id, SObject>();
    for (SObject s : updated) {
      byId.put((Id) s.get('Id'), s);
    }
    Assert.areEqual('Withdrawn/Declined', (String) byId.get(priorAcceptedId).get('Status'));
    Assert.areEqual('Seat Accepted', (String) byId.get(targetId).get('Status'));
  }

  // The no-ATE case allows the switch, and the prior Seat Accepted row is in
  // the single update with exactly these three field values.
  @IsTest
  private static void acceptOffer_switchAllowedWithNoAteRow_declinesPriorAcceptedWithAutoClosedReason() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id priorAcceptedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);
    AcademicInterest priorAccepted = buildAi(priorAcceptedId, appId, 'Seat Accepted', 2, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>{ priorAccepted })
      .thenReturn(new List<AcademicTermEnrollment>()) // no ATE row
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(true) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();
    EVENT_BUS_REPO_MOCK.when(EVENT_BUS_REPO_MOCK.method.publishSingle()).thenReturn(null);

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    SObject declined;
    if ((Id) updated[0].get('Id') == priorAcceptedId) {
      declined = updated[0];
    } else {
      declined = updated[1];
    }
    Assert.areEqual('Withdrawn/Declined', (String) declined.get('Status'));
    Assert.areEqual('Other', (String) declined.get('Withdrawn_Declined_Reason_Picklist__c'));
    Assert.areEqual(
      'Applicant accepted another offered seat',
      (String) declined.get('Declined_Withdrawn_Reason__c')
    );
  }

  // --- ownership ------------------------------------------------------------
  @IsTest
  private static void acceptOffer_portalCaller_wrongOwner_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id loggedInContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id otherContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, otherContactId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target }) // requireOwnedInterest target
      .thenReturn(new List<User>{ portalUser(loggedInContactId) }) // isPortalCaller
      .thenReturn(new List<User>{ portalUser(loggedInContactId) }); // resolveGuardianContactId's session lookup
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolApplicationDecisionController.acceptOffer(appId, targetId);
      Assert.fail('Expected an exception for a non-owning portal caller');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('your own'), e.getMessage());
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size()
    );
  }

  @IsTest
  private static void acceptOffer_internalCaller_nullSubmittedByContactId_succeeds() {
    // Covered end-to-end by acceptOffer_cascade_keepsHigherRankedWaitlist_declinesOthers,
    // whose target carries a null SubmittedByContactId and an internal (no
    // session Contact) caller — asserted again here in isolation.
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<AcademicInterest>())
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.acceptOffer(appId, targetId);

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual('Seat Accepted', (String) updated[0].get('Status'));
  }

  @IsTest
  private static void acceptOffer_nullIds_throw() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();
    try {
      SchoolApplicationDecisionController.acceptOffer(null, null);
      Assert.fail('Expected an exception for a null application Id');
    } catch (Exception e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  private static void getStudentFirstName_returnsFirstName() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{ buildAppWithStudent(appId, null, 'Ada', 'Ada Lovelace') }
      )
      .thenReturn(new List<User>{ internalUser() });

    Assert.areEqual('Ada', SchoolApplicationDecisionController.getStudentFirstName(appId));
  }

  @IsTest
  private static void getStudentFirstName_blankFirstName_fallsBackToName() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{ buildAppWithStudent(appId, null, null, 'Lovelace') }
      )
      .thenReturn(new List<User>{ internalUser() });

    Assert.areEqual('Lovelace', SchoolApplicationDecisionController.getStudentFirstName(appId));
  }

  @IsTest
  private static void getStudentFirstName_noAccount_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) })
      .thenReturn(new List<User>{ internalUser() });

    Assert.isNull(SchoolApplicationDecisionController.getStudentFirstName(appId));
  }

  @IsTest
  private static void getStudentFirstName_portalCaller_wrongOwner_throws() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id loggedInContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id otherContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          buildAppWithStudent(appId, otherContactId, 'Ada', 'Ada Lovelace')
        }
      )
      .thenReturn(new List<User>{ portalUser(loggedInContactId) }) // isPortalCaller
      .thenReturn(new List<User>{ portalUser(loggedInContactId) }); // resolveGuardianContactId's session lookup

    try {
      SchoolApplicationDecisionController.getStudentFirstName(appId);
      Assert.fail('Expected an exception for a non-owning portal caller');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('your own'), e.getMessage());
    }
  }

  @IsTest
  private static void getStudentFirstName_portalCaller_owner_returnsFirstName() {
    DATABASE_REPO_MOCK.reset();
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          buildAppWithStudent(appId, contactId, 'Ada', 'Ada Lovelace')
        }
      )
      .thenReturn(new List<User>{ portalUser(contactId) })
      .thenReturn(new List<User>{ portalUser(contactId) });

    Assert.areEqual('Ada', SchoolApplicationDecisionController.getStudentFirstName(appId));
  }

  // --- declineOffer ----------------------------------------------------------
  @IsTest
  private static void declineOffer_otherReason_capturesFreeText() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(
      appId,
      targetId,
      'Other',
      'we found another school'
    );

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual('Withdrawn/Declined', (String) updated[0].get('Status'));
    Assert.areEqual('Other', (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'));
    Assert.areEqual(
      'we found another school',
      (String) updated[0].get('Declined_Withdrawn_Reason__c')
    );
  }

  @IsTest
  private static void declineOffer_otherReasonWithoutText_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    for (String blank : new List<String>{ null, '', '   ' }) {
      try {
        SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Other', blank);
        Assert.fail('Expected an exception for Other without text');
      } catch (Exception e) {
        Assert.isTrue(e.getMessage().contains('describe'), e.getMessage());
      }
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size()
    );
  }

  @IsTest
  private static void declineOffer_standardReason_savesTrimmedComment() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(
      appId,
      targetId,
      'Relocation',
      '  moving in March  '
    );

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual('Relocation', (String) updated[0].get('Withdrawn_Declined_Reason_Picklist__c'));
    Assert.areEqual('moving in March', (String) updated[0].get('Declined_Withdrawn_Reason__c'));
  }

  @IsTest
  private static void declineOffer_standardReason_blankCommentSavesNull() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', '   ');

    List<SObject> updated = updateCallSObjects();
    Assert.isNull(updated[0].get('Declined_Withdrawn_Reason__c'));
  }

  // Declining the current offer moves Current_School_Offer__c to the
  // lowest-ranked remaining offer; Waitlisted and already-closed rows never
  // qualify, even at a better rank.
  @IsTest
  private static void declineOffer_currentOffer_repointsToNextBestRankedOffer() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id waitlistedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id rank4OfferId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id rescindedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id rank5OfferId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(
        new List<AcademicInterest>{
          buildAi(rank4OfferId, appId, 'Seat Offered', 4, null),
          buildAi(waitlistedId, appId, 'Waitlisted', 2, null),
          buildAi(rescindedId, appId, 'Offer Rescinded due to Seat Optimization', 3, null),
          buildAi(rank5OfferId, appId, 'Seat Offered', 5, null)
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    IndividualApplication updatedApp = updatedApplication(updateCallSObjects());
    Assert.isNotNull(updatedApp, 'Expected the application to be updated in the same call');
    Assert.areEqual(appId, updatedApp.Id);
    Assert.areEqual(rescindedId, updatedApp.Current_School_Offer__c);
    Assert.isFalse(
      updatedApp.isSet('Offer_Expiration_Date__c'),
      'The respond-by date must be left alone'
    );
  }

  @IsTest
  private static void declineOffer_currentOffer_equalRank_prefersSeatOfferedOverRescinded() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id rescindedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id offeredId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(
        new List<AcademicInterest>{
          buildAi(rescindedId, appId, 'Offer Rescinded due to Seat Optimization', 2, null),
          buildAi(offeredId, appId, 'Seat Offered', 2, null)
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    Assert.areEqual(offeredId, updatedApplication(updateCallSObjects()).Current_School_Offer__c);
  }

  @IsTest
  private static void declineOffer_currentOffer_noOtherOffer_clearsIt() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id waitlistedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id closedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(
        new List<AcademicInterest>{
          buildAi(waitlistedId, appId, 'Waitlisted', 2, null),
          buildAi(closedId, appId, 'Withdrawn/Declined', 3, null)
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    IndividualApplication updatedApp = updatedApplication(updateCallSObjects());
    Assert.isNotNull(updatedApp, 'Expected the application to be updated in the same call');
    Assert.isNull(updatedApp.Current_School_Offer__c);
  }

  @IsTest
  private static void declineOffer_currentOffer_noOtherOffer_fallsBackToAcceptedSeat() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id waitlistedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id acceptedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(
        new List<AcademicInterest>{
          buildAi(waitlistedId, appId, 'Waitlisted', 2, null),
          buildAi(acceptedId, appId, 'Seat Accepted', 3, null)
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    Assert.areEqual(acceptedId, updatedApplication(updateCallSObjects()).Current_School_Offer__c);
  }

  @IsTest
  private static void declineOffer_currentOffer_unrankedOfferLosesToRankedOne() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id unrankedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id rankedId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, targetId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(
        new List<AcademicInterest>{
          buildAi(unrankedId, appId, 'Seat Offered', null, null),
          buildAi(rankedId, appId, 'Seat Offered', 6, null)
        }
      )
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    Assert.areEqual(rankedId, updatedApplication(updateCallSObjects()).Current_School_Offer__c);
  }

  @IsTest
  private static void declineOffer_currentSchoolOfferPointsElsewhere_leavesItUntouched() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    Id otherAiId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Seat Offered', 1, null, otherAiId);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() })
      .thenReturn(new List<IndividualApplication>{ appWithAppliedDate(false) });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);

    List<SObject> updated = updateCallSObjects();
    Assert.areEqual(
      1,
      updated.size(),
      'The application must not be touched when it points elsewhere'
    );
    Assert.areEqual(targetId, updated[0].Id);
  }

  @IsTest
  private static void declineOffer_notOfferEligible_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);
    AcademicInterest target = buildAi(targetId, appId, 'Withdrawn/Declined', 1, null);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<AcademicInterest>{ target })
      .thenReturn(new List<User>{ internalUser() });
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.updateSObjects()).thenReturnVoid();

    try {
      SchoolApplicationDecisionController.declineOffer(appId, targetId, 'Relocation', null);
      Assert.fail('Expected an exception for a non-offer-eligible status');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('no longer available to decline'), e.getMessage());
    }
    Assert.areEqual(
      0,
      DATABASE_REPO_MOCK.getCalls(DATABASE_REPO_MOCK.method.updateSObjects()).size()
    );
  }

  @IsTest
  private static void declineOffer_blankReason_throws() {
    DATABASE_REPO_MOCK.reset();
    EVENT_BUS_REPO_MOCK.reset();

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id targetId = SObjectIds.generateFakeId(Schema.AcademicInterest.SObjectType);

    try {
      SchoolApplicationDecisionController.declineOffer(appId, targetId, '', null);
      Assert.fail('Expected an exception for a blank decline reason');
    } catch (Exception e) {
      Assert.isTrue(e.getMessage().contains('required'), e.getMessage());
    }
  }
}