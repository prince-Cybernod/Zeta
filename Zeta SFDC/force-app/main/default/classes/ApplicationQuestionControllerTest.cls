/**
 * Tests for {@link ApplicationQuestionController}.
 *
 * These tests rely on the CMDT records deployed with the Application Question Framework:
 * - Application_Page.Application_Details
 * - Application_Section.Guardian_Information, Application_Section.Application_Info
 * - Application_Question.Guardian_1_First_Name, Guardian_1_Last_Name, Guardian_1_Email,
 *   Guardian_1_Phone, Guardian_1_Relationship, Grade_Applying_To
 * - SObject_Field.IndApp_Guardian_1_First_Name, etc.
 */
@IsTest(IsParallel=true)
private class ApplicationQuestionControllerTest {
  private static final String PAGE_DEV_NAME = 'Application_Details';
  private static final String GUARDIAN_SECTION = 'Guardian_Information';
  private static final String APP_INFO_SECTION = 'Application_Info';

  @IsTest
  private static void getFormStructure_returnsPageWithSectionsAndQuestions() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    Assert.isNotNull(result, 'FormStructure should not be null');
    Assert.isNotNull(result.page, 'Page should not be null');
    Assert.areEqual(PAGE_DEV_NAME, result.page.developerName);
    Assert.areEqual('Application Details', result.page.label);
    Assert.areEqual('Form', result.page.pageType);
    Assert.areEqual(1, result.page.sortOrder);

    Assert.isNotNull(result.sections, 'Sections should not be null');
    Assert.isTrue(result.sections.size() >= 2, 'Should have at least 2 sections');

    AppQuestionSection guardianSection = findSection(result.sections, GUARDIAN_SECTION);
    Assert.isNotNull(guardianSection, 'Guardian section should exist');
    Assert.areEqual(2, guardianSection.columns);
    Assert.areEqual(1, guardianSection.sortOrder);
    Assert.isTrue(
      guardianSection.questions.size() >= 5,
      'Guardian section should have at least 5 questions'
    );

    AppQuestionSection appInfoSection = findSection(result.sections, APP_INFO_SECTION);
    Assert.isNotNull(appInfoSection, 'App Info section should exist');
    Assert.areEqual(2, appInfoSection.columns);
    Assert.areEqual(2, appInfoSection.sortOrder);
    Assert.isTrue(
      appInfoSection.questions.size() >= 1,
      'App Info section should have at least 1 question'
    );
  }

  @IsTest
  private static void getFormStructure_questionsHaveCorrectProperties() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionSection guardianSection = findSection(result.sections, GUARDIAN_SECTION);
    AppQuestionInput firstNameQuestion = guardianSection.questions[0];
    Assert.areEqual('Guardian_1_First_Name', firstNameQuestion.developerName);
    Assert.areEqual('First Name', firstNameQuestion.label);
    Assert.areEqual('Text', firstNameQuestion.inputType);
    Assert.areEqual(true, firstNameQuestion.isRequired);
    Assert.areEqual('Enter first name', firstNameQuestion.placeholder);
    Assert.areEqual(80, firstNameQuestion.maxLength);
    Assert.areEqual(1, firstNameQuestion.sortOrder);
    Assert.isNotNull(firstNameQuestion.targetObject);
    Assert.isNotNull(firstNameQuestion.targetField);
    Assert.isTrue(firstNameQuestion.options.isEmpty(), 'Text input should have empty options');
  }

  @IsTest
  private static void getFormStructure_dropdownQuestionsHavePicklistOptions() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionInput relationshipQuestion = null;
    AppQuestionSection guardianSection = findSection(result.sections, GUARDIAN_SECTION);
    for (AppQuestionInput q : guardianSection.questions) {
      if (q.developerName == 'Guardian_1_Relationship') {
        relationshipQuestion = q;
        break;
      }
    }

    Assert.isNotNull(relationshipQuestion, 'Relationship question should exist');
    Assert.areEqual('Dropdown', relationshipQuestion.inputType);
    Assert.isFalse(relationshipQuestion.options.isEmpty(), 'Dropdown should have picklist options');

    for (AppQuestionOption option : relationshipQuestion.options) {
      Assert.isNotNull(option.label, 'Option label should not be null');
      Assert.isNotNull(option.value, 'Option value should not be null');
    }
  }

  @IsTest
  private static void getFormStructure_questionsAreSortedCorrectly() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionSection guardianSection = findSection(result.sections, GUARDIAN_SECTION);
    List<AppQuestionInput> questions = guardianSection.questions;
    Integer previousSortOrder = 0;
    for (AppQuestionInput q : questions) {
      Assert.isTrue(
        q.sortOrder >= previousSortOrder,
        'Questions should be sorted by Sort_Order__c'
      );
      previousSortOrder = q.sortOrder;
    }
  }

  @IsTest
  private static void getFormStructure_withNullVariant_returnsAllRecords() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    Assert.isTrue(result.sections.size() >= 2, 'Should return all sections when variant is null');
  }

  @IsTest
  private static void getFormStructure_withNullRecordId_skipsVisibility() {
    // When recordId is null, all sections/questions should be returned
    // regardless of any visibility criteria on the CMDT records
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    Assert.isTrue(result.sections.size() >= 2, 'Should return all sections when recordId is null');
  }

  @IsTest
  private static void getFormStructure_withInvalidPage_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page not found: NonExistent_Page'
    );

    try {
      ApplicationQuestionController.getFormStructure('NonExistent_Page', null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getFormStructure_withNullPageDevName_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page developer name is required'
    );

    try {
      ApplicationQuestionController.getFormStructure(null, null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getFormStructure_withBlankPageDevName_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page developer name is required'
    );

    try {
      ApplicationQuestionController.getFormStructure('', null, null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void matchesVariant_withNullFilter_returnsTrue() {
    Assert.isTrue(ApplicationQuestionController.matchesVariant('Elementary', null));
  }

  @IsTest
  private static void matchesVariant_withNullRecord_returnsTrue() {
    Assert.isTrue(ApplicationQuestionController.matchesVariant(null, 'Elementary'));
  }

  @IsTest
  private static void matchesVariant_withMatchingValue_returnsTrue() {
    Assert.isTrue(ApplicationQuestionController.matchesVariant('Elementary;Middle;High', 'Middle'));
  }

  @IsTest
  private static void matchesVariant_withNonMatchingValue_returnsFalse() {
    Assert.isFalse(ApplicationQuestionController.matchesVariant('Elementary', 'High'));
  }

  @IsTest
  private static void saveFormAnswers_withNullApplicationId_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      ApplicationQuestionController.saveFormAnswers(null, '{}');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void saveFormAnswers_withNullAnswersJson_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Answers JSON is required'
    );

    try {
      ApplicationQuestionController.saveFormAnswers(UserInfo.getUserId(), null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void saveFormAnswers_withEmptyAnswers_returnsWithoutDml() {
    // Empty answers map should return early without DML
    ApplicationQuestionController.saveFormAnswers(UserInfo.getUserId(), '{}');
    // No exception means success — empty map returns early
  }

  @IsTest
  private static void saveFormAnswers_blankRequiredAnswer_throwsException() {
    // Guardian_2_Email is configured as Is_Required__c = true. The required-check
    // runs before DML, so no real IndividualApplication record is needed.
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Required: Email'
    );

    try {
      ApplicationQuestionController.saveFormAnswers(fakeAppId, '{"Guardian_2_Email":""}');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void saveFormAnswers_nullRequiredAnswer_throwsException() {
    // JSON null is treated as blank by the required-check.
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Required: Email'
    );

    try {
      ApplicationQuestionController.saveFormAnswers(fakeAppId, '{"Guardian_2_Email":null}');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void saveFormAnswers_multipleBlankRequired_listsAllMissing() {
    // Two required questions blank → message accumulates both. Also exercises
    // Display_Label__c resolution (proves the SOQL extension picks it up).
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    try {
      ApplicationQuestionController.saveFormAnswers(
        fakeAppId,
        '{"Guardian_2_Email":"","Guardian_2_Phone":""}'
      );
      Assert.fail('Expected IllegalArgumentException listing both required fields');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(
        e.getMessage().contains('Email') && e.getMessage().contains('Phone'),
        'Message should name both missing required fields: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void getExistingAnswers_withNullRecordId_returnsEmptyMap() {
    Map<String, Object> result = ApplicationQuestionController.getExistingAnswers(
      null,
      PAGE_DEV_NAME
    );

    Assert.isNotNull(result, 'Result should not be null');
    Assert.isTrue(result.isEmpty(), 'Result should be empty for null recordId');
  }

  @IsTest
  private static void getExistingAnswers_withBlankPageDevName_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page developer name is required'
    );

    try {
      ApplicationQuestionController.getExistingAnswers(UserInfo.getUserId(), '');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getExistingAnswers_withNonExistentRecord_returnsEmptyMap() {
    Id fakeId = IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    Map<String, Object> result = ApplicationQuestionController.getExistingAnswers(
      fakeId,
      PAGE_DEV_NAME
    );

    Assert.isNotNull(result, 'Result should not be null');
    Assert.isTrue(result.isEmpty(), 'Result should be empty for non-existent record');
  }

  @IsTest
  private static void coerceValue_boolean_coercesStringToBoolean() {
    SObjectField field = IndividualApplication.Sibling_Attending_Priority__c;

    Object result = ApplicationQuestionController.coerceValue(field, 'true');

    Assert.areEqual(true, result);
  }

  @IsTest
  private static void coerceValue_number_coercesStringToDecimal() {
    SObjectField field = IndividualApplication.Count_of_Sibling_Applying__c;

    Object result = ApplicationQuestionController.coerceValue(field, '42.5');

    Assert.areEqual(42.5, (Decimal) result);
  }

  @IsTest
  private static void coerceValue_date_coercesStringToDateFromDatetime() {
    SObjectField field = IndividualApplication.Date_of_First_Offer__c;

    Object result = ApplicationQuestionController.coerceValue(field, '2026-03-03 00:00:00');

    Assert.areEqual(Datetime.valueOf('2026-03-03 00:00:00'), result);
  }

  @IsTest
  private static void coerceValue_string_passesThrough() {
    SObjectField field = IndividualApplication.Parent_Guardian_1_First_Name__c;

    Object result = ApplicationQuestionController.coerceValue(field, 'John');

    Assert.areEqual('John', result);
  }

  @IsTest
  private static void coerceValue_null_returnsNull() {
    SObjectField field = IndividualApplication.Parent_Guardian_1_First_Name__c;

    Object result = ApplicationQuestionController.coerceValue(field, null);

    Assert.isNull(result);
  }

  @IsTest
  private static void getFormStructure_resolvesLabelsInQuestions() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionSection guardianSection = findSection(result.sections, GUARDIAN_SECTION);
    AppQuestionInput firstNameQuestion = guardianSection.questions[0];
    // CMDT stores label name 'AppQ_Guardian1FirstName_Placeholder' which resolves to 'Enter first name'
    Assert.areEqual('Enter first name', firstNameQuestion.placeholder);
  }

  @IsTest
  private static void getFormStructure_resolvesLabelsInPage() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    // CMDT stores label name 'AppP_ApplicationDetails_Description' which resolves
    Assert.areEqual('Please fill out the following information.', result.page.description);
  }

  @IsTest
  private static void evaluateCriteria_nullCriteria_returnsTrue() {
    Account testAccount = new Account(Name = 'Test');

    Boolean result = ApplicationQuestionController.evaluateCriteria(null, testAccount);

    Assert.isTrue(result, 'Null criteria should return true (visible)');
  }

  @IsTest
  private static void evaluateCriteria_blankFormula_returnsTrue() {
    SObject_Field_Criteria__mdt criteria = new SObject_Field_Criteria__mdt(
      Formula_Expression__c = ''
    );
    Account testAccount = new Account(Name = 'Test');

    Boolean result = ApplicationQuestionController.evaluateCriteria(criteria, testAccount);

    Assert.isTrue(result, 'Blank formula should return true (visible)');
  }

  @IsTest
  private static void evaluateCriteria_nullRecord_returnsTrue() {
    SObject_Field_Criteria__mdt criteria = new SObject_Field_Criteria__mdt(
      Formula_Expression__c = 'Name = "Test"'
    );

    Boolean result = ApplicationQuestionController.evaluateCriteria(criteria, null);

    Assert.isTrue(result, 'Null record should return true (visible)');
  }

  @IsTest
  private static void evaluateVisibility_returnsVisibilityMap() {
    Map<String, Boolean> result = ApplicationQuestionController.evaluateVisibility(
      null,
      PAGE_DEV_NAME,
      null,
      '{}'
    );

    Assert.isNotNull(result, 'Visibility map should not be null');
    Assert.isFalse(result.isEmpty(), 'Visibility map should contain entries');
  }

  @IsTest
  private static void evaluateVisibility_withBlankPageDevName_throwsException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page developer name is required'
    );

    try {
      ApplicationQuestionController.evaluateVisibility(null, '', null, '{}');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void evaluateVisibility_withNullAnswers_returnsMap() {
    Map<String, Boolean> result = ApplicationQuestionController.evaluateVisibility(
      null,
      PAGE_DEV_NAME,
      null,
      null
    );

    Assert.isNotNull(result, 'Visibility map should not be null even with null answers');
  }

  @IsTest
  private static void evaluateVisibility_withFalseCriteria_returnsNotVisible() {
    // Inject a mock evaluator that always returns false
    SObjectFieldCriteriaEvaluatorMock mockEvaluator = new SObjectFieldCriteriaEvaluatorMock();
    ApplicationQuestionController.criteriaEvaluator = mockEvaluator;

    // Application_Details has 6 sections with criteria:
    //   Employee_Information, Guardian_2, Guardian_2_Address,
    //   Guardian_2_Information, Sibling_Applying_Details, Sibling_Attending_Details
    // and 2 questions with criteria:
    //   Referral_Name, Guardian_2_Address_Compound
    // Each calls evaluate() once = 8 total calls. We pre-queue extras so the
    // test stays green if a new criteria-bearing CMDT record is added.
    mockEvaluator
      .when(mockEvaluator.method.evaluate())
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false)
      .thenReturn(false);

    Map<String, Boolean> result = ApplicationQuestionController.evaluateVisibility(
      null,
      PAGE_DEV_NAME,
      null,
      '{}'
    );

    Assert.isNotNull(result, 'Visibility map should not be null');

    // Sections/questions with criteria should be false (not visible)
    Set<String> criteriaControlled = new Set<String>{
      'Employee_Information',
      'Guardian_2',
      'Guardian_2_Address_Compound',
      'Sibling_Applying_Details',
      'Sibling_Attending_Details',
      'Referral_Name'
    };
    for (String devName : criteriaControlled) {
      if (result.containsKey(devName)) {
        Assert.isFalse(
          result.get(devName),
          devName + ' should be not visible when criteria evaluates to false'
        );
      }
    }

    // Sections/questions without criteria should still be true (visible)
    if (result.containsKey('Guardian_Information')) {
      Assert.isTrue(
        result.get('Guardian_Information'),
        'Guardian_Information has no criteria so should remain visible'
      );
    }
  }

  @IsTest
  private static void coerceValue_blankString_returnsNull() {
    SObjectField field = IndividualApplication.Parent_Guardian_1_First_Name__c;

    Assert.isNull(ApplicationQuestionController.coerceValue(field, ''));
    Assert.isNull(ApplicationQuestionController.coerceValue(field, '   '));
  }

  @IsTest
  private static void coerceValue_date_coercesStringToDate() {
    SObjectField field = IndividualApplication.Signature_Date__c;

    Object result = ApplicationQuestionController.coerceValue(field, '2026-03-03');

    Assert.areEqual(Date.valueOf('2026-03-03'), result);
  }

  @IsTest
  private static void coerceValue_datetime_isoFormat_coercesCorrectly() {
    SObjectField field = IndividualApplication.Date_of_First_Offer__c;

    Object result = ApplicationQuestionController.coerceValue(field, '2026-03-03T12:00:00.000Z');

    Assert.isNotNull(result);
    Assert.isTrue(result instanceof Datetime, 'Should be a Datetime');
  }

  @IsTest
  private static void coerceValue_datetime_standardFormat_coercesCorrectly() {
    SObjectField field = IndividualApplication.Date_of_First_Offer__c;

    Object result = ApplicationQuestionController.coerceValue(field, '2026-03-03 12:00:00');

    Assert.areEqual(Datetime.valueOf('2026-03-03 12:00:00'), result);
  }

  @IsTest
  private static void matchesVariant_bothBlank_returnsTrue() {
    Assert.isTrue(ApplicationQuestionController.matchesVariant('', ''));
  }

  @IsTest
  private static void matchesVariant_bothNull_returnsTrue() {
    Assert.isTrue(ApplicationQuestionController.matchesVariant(null, null));
  }

  private static void getApplicationFormBundle_withNullRecordId_returnsFormStructureAndEmptyAnswers() {
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Assert.isNotNull(bundle, 'Bundle should not be null');
    Assert.isNotNull(bundle.formStructure, 'Bundle should include the form structure');
    Assert.areEqual(PAGE_DEV_NAME, bundle.formStructure.page.developerName);
    Assert.isTrue(
      bundle.formStructure.sections.size() >= 2,
      'Form structure should include all sections from the page'
    );
    Assert.isNotNull(bundle.existingAnswers, 'existingAnswers should always be initialised');
    Assert.isTrue(
      bundle.existingAnswers.isEmpty(),
      'existingAnswers should be empty when no recordId is provided'
    );
    Assert.isNotNull(bundle.submissionWarnings, 'submissionWarnings should always be initialised');
    Assert.isFalse(
      (Boolean) bundle.submissionWarnings.get('hasAgeWarning'),
      'hasAgeWarning should default to false for null recordId'
    );
    Assert.isFalse(
      (Boolean) bundle.submissionWarnings.get('hasResidencyWarning'),
      'hasResidencyWarning should default to false for null recordId'
    );
  }

  @IsTest
  private static void getFormStructure_includesAddressSection() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    // The student-address section ("Address" / "Student Address") now holds ONLY
    // the Address_Compound question. The Lives_With_Guardian_1 checkbox moved to
    // the Guardian_1_Address section (Guardian 1 address captured first; the
    // student-address section is conditional on Lives_With_Guardian_1 = false).
    AppQuestionSection address = findSection(result.sections, 'Address');
    Assert.isNotNull(address, 'Address (Student Address) section should exist');
    Assert.areEqual(
      1,
      address.questions.size(),
      'Student Address section should contain only the Address_Compound question'
    );

    AppQuestionInput addressQuestion = findQuestion(address.questions, 'Address_Compound');
    Assert.isNotNull(addressQuestion, 'Address_Compound question should exist');
    Assert.areEqual('Address', addressQuestion.inputType);
    Assert.isNotNull(
      addressQuestion.fieldBindings,
      'Address question should expose its field bindings'
    );
    Assert.areEqual(
      'Student.PersonMailingStreet',
      addressQuestion.fieldBindings.get('street'),
      'Address bindings should map the street slot to Student.PersonMailingStreet'
    );
    Assert.areEqual(
      'Student.Apartment_Number__c',
      addressQuestion.fieldBindings.get('subpremise'),
      'Address bindings should map the subpremise slot to Account.Apartment_Number__c'
    );
    // The student Address_Compound no longer names a companion — the writeback
    // relationship is now guardian -> student, so the companion lives on
    // Guardian_1_Address_Compound (asserted below).
    Assert.isTrue(
      String.isBlank(addressQuestion.companionQuestionDevName),
      'Student Address question should NOT name a companion'
    );

    // Lives_With_Guardian_1 now lives in its own non-collapsible
    // Student_Living_Status section so the checkbox stays visible even after the
    // Guardian 1 address collapses on completion, and it is shown inverted as
    // "Student lives at a different address".
    AppQuestionSection livingStatus = findSection(result.sections, 'Student_Living_Status');
    Assert.isNotNull(livingStatus, 'Student_Living_Status section should exist');
    AppQuestionInput livesWith = findQuestion(livingStatus.questions, 'Lives_With_Guardian_1');
    Assert.isNotNull(
      livesWith,
      'Student_Living_Status section should contain the Lives_With_Guardian_1 checkbox'
    );
    Assert.isTrue(livesWith.invertDisplay, 'Lives_With_Guardian_1 should be flagged invertDisplay');

    AppQuestionSection guardian1Address = findSection(result.sections, 'Guardian_1_Address');
    Assert.isNotNull(guardian1Address, 'Guardian_1_Address section should exist');
    Assert.isNull(
      findQuestion(guardian1Address.questions, 'Lives_With_Guardian_1'),
      'Lives_With_Guardian_1 should no longer live in the Guardian_1_Address section'
    );

    // The guardian Address question names the student Address question as its
    // companion: when "Student also lives with Guardian 1" is checked, the
    // guardian address is written back to the student record.
    AppQuestionInput guardian1AddressQuestion = findQuestion(
      guardian1Address.questions,
      'Guardian_1_Address_Compound'
    );
    Assert.isNotNull(guardian1AddressQuestion, 'Guardian_1_Address_Compound question should exist');
    Assert.areEqual(
      'Address_Compound',
      guardian1AddressQuestion.companionQuestionDevName,
      'Guardian 1 Address question should name the student Address as its companion'
    );
  }

  @IsTest
  private static void getFormStructure_employeePriorityInOwnSection() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    // The "are you a Zeta employee?" toggle was reframed out of the lone
    // "Priorities" (Priority_Toggles) section — which is now retired — into its
    // own always-visible Employee_Status section. The dependent Employee
    // Information detail section is unchanged (still gated on the toggle).
    AppQuestionSection employeeStatus = findSection(result.sections, 'Employee_Status');
    Assert.isNotNull(employeeStatus, 'Employee_Status section should exist');
    Assert.isNotNull(
      findQuestion(employeeStatus.questions, 'Employee_Priority'),
      'Employee_Status section should contain the Employee_Priority toggle'
    );

    Assert.isNull(
      findSection(result.sections, 'Priority_Toggles'),
      'Retired Priority_Toggles section should no longer render'
    );
    Assert.isNotNull(
      findSection(result.sections, 'Employee_Information'),
      'Employee_Information detail section should still exist'
    );
  }

  private static void getApplicationFormBundle_applicationDetailsPage_populatesGuardianDefaults() {
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Assert.isNotNull(bundle.guardianDefaults, 'guardianDefaults should be initialised');
    // We can't guarantee the running user has Contact data populated in a parallel
    // test context — assert only that the map exists and that it's keyed by the
    // expected Guardian_1_* developer names when entries are present.
    for (String key : bundle.guardianDefaults.keySet()) {
      Assert.isTrue(
        key.startsWith('Guardian_1_'),
        'guardianDefaults keys must use the Guardian_1_* prefix, was ' + key
      );
    }
  }

  @IsTest
  private static void getApplicationFormBundle_nonApplicationDetailsPage_skipsGuardianDefaults() {
    // Any page name other than 'Application_Details' should short-circuit the
    // guardian-defaults lookup. We expect either a missing page exception
    // (preferred — proves the short-circuit fires before the contact query)
    // or — if a config-only page named 'Other_Page' happens to exist — an
    // empty defaults map. Either is a correct outcome for this contract.
    try {
      AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
        null,
        'Other_Page',
        null
      );
      Assert.isNotNull(bundle.guardianDefaults);
      Assert.isTrue(
        bundle.guardianDefaults.isEmpty(),
        'guardianDefaults must be empty for non-Application_Details pages'
      );
    } catch (IllegalArgumentException e) {
      Assert.isTrue(
        e.getMessage().contains('Page not found'),
        'Expected page-not-found short-circuit, got: ' + e.getMessage()
      );
    }
  }

  @IsTest
  private static void getApplicationFormBundle_withVariant_filtersSectionsAndQuestions() {
    AppFormBundle full = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );
    AppFormBundle filtered = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      'Variant_That_Will_Never_Match'
    );

    // Sections with a non-matching variant should be filtered out, while
    // sections without an explicit variant value remain visible. The filtered
    // bundle therefore cannot have more sections than the unfiltered one.
    Assert.isTrue(
      filtered.formStructure.sections.size() <= full.formStructure.sections.size(),
      'Variant-filtered bundle should not return more sections than the unfiltered bundle'
    );
  }

  @IsTest
  private static void getAddressQuestionValues_unknownQuestion_returnsEmpty() {
    Id fakeId = IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      fakeId,
      'No_Such_Question_Dev_Name'
    );

    Assert.isNotNull(result, 'Result should not be null');
    Assert.isTrue(result.isEmpty(), 'Result should be empty when question is unknown');
  }

  @IsTest
  private static void getAddressQuestionValues_nullInputs_returnsEmpty() {
    Map<String, String> r1 = ApplicationQuestionController.getAddressQuestionValues(
      null,
      'Address_Compound'
    );
    Map<String, String> r2 = ApplicationQuestionController.getAddressQuestionValues(
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA',
      null
    );

    Assert.isTrue(r1.isEmpty(), 'Null application id should yield empty result');
    Assert.isTrue(r2.isEmpty(), 'Null question developer name should yield empty result');
  }

  @IsTest
  private static void getAddressQuestionValues_unknownApplication_returnsEmpty() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      fakeAppId,
      'Address_Compound'
    );

    Assert.isNotNull(result, 'Result should not be null');
    Assert.isTrue(
      result.isEmpty(),
      'Result should be empty when the IndividualApplication does not exist'
    );
  }

  @IsTest
  private static void saveAddressQuestion_unknownApplication_throws() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
    String payload = JSON.serialize(new Map<String, Object>{ 'street' => '1 Anywhere St' });

    Boolean threwExpected = false;
    try {
      ApplicationQuestionController.saveAddressQuestion(fakeAppId, 'Address_Compound', payload);
    } catch (IllegalArgumentException e) {
      threwExpected = e.getMessage().startsWith('IndividualApplication not found');
    }

    Assert.isTrue(threwExpected, 'Should throw IndividualApplication not found error');
  }

  @IsTest
  private static void saveAddressQuestion_emptyPayload_writesNothing() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
    // Payload with no bindings-matching keys is a no-op; no DML so no exception.
    ApplicationQuestionController.saveAddressQuestion(
      fakeAppId,
      'Address_Compound',
      '{"unrelated_key":"x"}'
    );
  }

  @IsTest
  private static void applyCompanionWriteback_unknownApplication_throws() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    Boolean threwExpected = false;
    try {
      ApplicationQuestionController.applyCompanionWriteback(
        fakeAppId,
        '{"street":"1 Test St"}',
        'Guardian_1_Address_Compound'
      );
    } catch (IllegalArgumentException e) {
      threwExpected = e.getMessage().startsWith('IndividualApplication not found');
    }
    Assert.isTrue(threwExpected, 'Should throw IndividualApplication not found error');
  }

  @IsTest
  private static void applyCompanionCopyFrom_unknownApplication_returnsQuietly() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    // No matching IndividualApplication → source values are empty → no-op
    ApplicationQuestionController.applyCompanionCopyFrom(
      fakeAppId,
      'Guardian_1_Address_Compound',
      'Guardian_2_Address_Compound'
    );
  }

  private static void getApplicationFormBundle_withBlankPageDevName_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Page developer name is required'
    );

    try {
      ApplicationQuestionController.getApplicationFormBundle(null, '', null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void applyCompanionWriteback_nullId_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );
    try {
      ApplicationQuestionController.applyCompanionWriteback(
        null,
        '{}',
        'Guardian_1_Address_Compound'
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void applyCompanionCopyFrom_nullId_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );
    try {
      ApplicationQuestionController.applyCompanionCopyFrom(
        null,
        'Guardian_1_Address_Compound',
        'Guardian_2_Address_Compound'
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void applyCompanionWriteback_blankDevName_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Companion question developer name is required'
    );
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';
    try {
      ApplicationQuestionController.applyCompanionWriteback(fakeAppId, '{"street":"x"}', '');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void getFormStructure_includesGuardian2AddressCompound() {
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionSection g2Section = findSection(result.sections, 'Guardian_2');
    Assert.isNotNull(g2Section, 'Guardian_2 (merged) section should still exist');

    AppQuestionInput g2Address = findQuestion(g2Section.questions, 'Guardian_2_Address_Compound');
    Assert.isNotNull(g2Address, 'Guardian_2_Address_Compound question should exist');
    Assert.areEqual('Address', g2Address.inputType);
    Assert.isNotNull(g2Address.fieldBindings, 'Guardian 2 question should expose field bindings');
    Assert.areEqual(
      'Secondary_Guardian__r.PersonMailingStreet',
      g2Address.fieldBindings.get('street')
    );
  }

  @IsTest
  private static void getFormStructure_g2LegacyTextQuestionsAreInactive() {
    // Guardian_2_Street/City/State/Zip CMDT records have been deactivated in favor
    // of the new Guardian_2_Address_Compound Address question. Verify they no longer
    // appear in the form structure.
    AppQuestionFormStructure result = ApplicationQuestionController.getFormStructure(
      PAGE_DEV_NAME,
      null,
      null
    );

    AppQuestionSection g2Section = findSection(result.sections, 'Guardian_2');
    Assert.isNotNull(g2Section, 'Merged Guardian_2 section should exist');
    Assert.isNull(findQuestion(g2Section.questions, 'Guardian_2_Street'));
    Assert.isNull(findQuestion(g2Section.questions, 'Guardian_2_City'));
    Assert.isNull(findQuestion(g2Section.questions, 'Guardian_2_State'));
    Assert.isNull(findQuestion(g2Section.questions, 'Guardian_2_Zip'));
  }

  private static Id personAccountRtId(String developerName) {
    Map<String, Schema.RecordTypeInfo> infos = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    Schema.RecordTypeInfo info = infos.get(developerName);
    return info == null ? null : info.getRecordTypeId();
  }

  /**
   * Creates a valid Student Person Account satisfying the Birthdate validation
   * rule. Address fields and the apartment value are taken straight from kwargs.
   */
  private static Account buildStudent(String first, String last, Map<String, Object> kwargs) {
    Account a = new Account(
      FirstName = first,
      LastName = last,
      RecordTypeId = personAccountRtId('Student'),
      PersonBirthdate = Date.newInstance(2015, 1, 1)
    );
    if (kwargs != null) {
      for (String k : kwargs.keySet()) {
        a.put(k, kwargs.get(k));
      }
    }
    return a;
  }

  /**
   * Creates a valid Guardian Person Account satisfying the validation rule that
   * Guardians must have Email and Phone (when no Schoolmint id is set).
   */
  private static Account buildGuardian(String first, String last, Map<String, Object> kwargs) {
    Account a = new Account(
      FirstName = first,
      LastName = last,
      RecordTypeId = personAccountRtId('Guardian'),
      PersonEmail = (first + last + '@example.invalid').toLowerCase(),
      PersonMobilePhone = '5555550100'
    );
    if (kwargs != null) {
      for (String k : kwargs.keySet()) {
        a.put(k, kwargs.get(k));
      }
    }
    return a;
  }

  @IsTest
  private static void saveAddressQuestion_blankInputs_throwException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );

    try {
      ApplicationQuestionController.saveAddressQuestion(null, 'Address_Compound', '{}');
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  private static void getApplicationFormBundle_withFakeRecordId_returnsEmptyExistingAnswers() {
    // Fake Id passes the not-null check but queries return nothing — should
    // gracefully produce an empty existingAnswers map.
    Id fakeId = IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      fakeId,
      PAGE_DEV_NAME,
      null
    );

    Assert.isNotNull(bundle.existingAnswers);
    Assert.isTrue(
      bundle.existingAnswers.isEmpty(),
      'existingAnswers should be empty for a fake (non-existent) recordId'
    );
    Assert.isFalse(
      (Boolean) bundle.submissionWarnings.get('hasResidencyWarning'),
      'hasResidencyWarning should default to false when the record is not found'
    );
  }

  @IsTest
  private static void getApplicationFormBundle_returnsControllingQuestionDevNames() {
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Assert.isNotNull(
      bundle.formStructure.controllingQuestionDevNames,
      'controllingQuestionDevNames should be present so the LWC can fall back when JS parsing fails'
    );
  }

  @IsTest
  private static void getApplicationFormBundle_sectionsExposeVisibilityFormula() {
    // The LWC evaluates visibility client-side using the formulaExpression
    // serialised onto each section/question. Verify at least one section on
    // Application_Details exposes its formula (Employee_Information,
    // Guardian_2_Information, Sibling_*_Details all have criteria).
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Boolean foundFormula = false;
    for (AppQuestionSection section : bundle.formStructure.sections) {
      if (
        section.visibilityCriteria != null &&
        String.isNotBlank(section.visibilityCriteria.formulaExpression)
      ) {
        foundFormula = true;
        break;
      }
    }

    Assert.isTrue(
      foundFormula,
      'At least one Application_Details section should expose visibilityCriteria.formulaExpression'
    );
  }

  @IsTest
  private static void buildGuardianDefaults_nullContact_returnsEmptyMap() {
    Map<String, String> defaults = ApplicationQuestionController.buildGuardianDefaults(null);
    Assert.isNotNull(defaults);
    Assert.isTrue(defaults.isEmpty(), 'Null contact must yield an empty defaults map');
  }

  @IsTest
  private static void buildGuardianDefaults_populatedContact_mapsAllGuardianFields() {
    Contact c = new Contact(
      FirstName = 'Pat',
      LastName = 'Guardian',
      Email = 'pat@example.com',
      MobilePhone = '+15555550100'
    );

    Map<String, String> defaults = ApplicationQuestionController.buildGuardianDefaults(c);

    Assert.areEqual('Pat', defaults.get('Guardian_1_First_Name'));
    Assert.areEqual('Guardian', defaults.get('Guardian_1_Last_Name'));
    Assert.areEqual('pat@example.com', defaults.get('Guardian_1_Email'));
    Assert.areEqual('+15555550100', defaults.get('Guardian_1_Phone'));
  }

  @IsTest
  private static void buildGuardianDefaults_partialContact_onlyMapsPopulatedFields() {
    Contact c = new Contact(FirstName = 'Pat', LastName = 'Guardian');

    Map<String, String> defaults = ApplicationQuestionController.buildGuardianDefaults(c);

    Assert.areEqual('Pat', defaults.get('Guardian_1_First_Name'));
    Assert.areEqual('Guardian', defaults.get('Guardian_1_Last_Name'));
    Assert.isFalse(defaults.containsKey('Guardian_1_Email'));
    Assert.isFalse(defaults.containsKey('Guardian_1_Phone'));
  }

  @IsTest
  private static void buildGuardianDefaults_zetaEmployee_prefillsPriorityIndicator() {
    Contact c = new Contact(FirstName = 'Pat', LastName = 'Guardian');

    Map<String, String> defaults = ApplicationQuestionController.buildGuardianDefaults(c, true);

    Assert.areEqual(
      'true',
      defaults.get('Employee_Priority'),
      'A self-reported Zeta-employee parent must pre-check the indicator'
    );
    Assert.areEqual(
      'Primary',
      defaults.get('Employee_Priority_Guardian'),
      'The running applicant is Guardian 1, so the picker defaults to Primary'
    );
  }

  @IsTest
  private static void buildGuardianDefaults_notZetaEmployee_omitsPriorityIndicator() {
    Contact c = new Contact(FirstName = 'Pat', LastName = 'Guardian');

    Map<String, String> defaults = ApplicationQuestionController.buildGuardianDefaults(c, false);

    Assert.isFalse(
      defaults.containsKey('Employee_Priority'),
      'Non-employee parents must not pre-check the indicator'
    );
    Assert.isFalse(defaults.containsKey('Employee_Priority_Guardian'));
  }

  @IsTest
  private static void addressBinding_parsesStudentPrefix() {
    ApplicationQuestionController.AddressBinding b = ApplicationQuestionController.parseAddressBinding(
      'Student.PersonMailingStreet'
    );
    Assert.areEqual('Student', b.targetKey);
    Assert.areEqual('PersonMailingStreet', b.fieldName);
  }

  @IsTest
  private static void addressBinding_parsesGuardian1Prefix() {
    ApplicationQuestionController.AddressBinding b = ApplicationQuestionController.parseAddressBinding(
      'Primary_Guardian__r.Apartment_Number__c'
    );
    Assert.areEqual('Guardian1', b.targetKey);
    Assert.areEqual('Apartment_Number__c', b.fieldName);
  }

  @IsTest
  private static void addressBinding_parsesGuardian2Prefix() {
    ApplicationQuestionController.AddressBinding b = ApplicationQuestionController.parseAddressBinding(
      'Secondary_Guardian__r.PersonMailingStreet'
    );
    Assert.areEqual('Guardian2', b.targetKey);
    Assert.areEqual('PersonMailingStreet', b.fieldName);
  }

  @IsTest
  private static void addressBinding_parsesIndividualApplicationPrefix() {
    ApplicationQuestionController.AddressBinding b = ApplicationQuestionController.parseAddressBinding(
      'IndividualApplication.Parent_Guardian_2_Street__c'
    );
    Assert.areEqual('Application', b.targetKey);
    Assert.areEqual('Parent_Guardian_2_Street__c', b.fieldName);
  }

  @IsTest
  private static void addressBinding_defaultsToApplicationTarget() {
    ApplicationQuestionController.AddressBinding b = ApplicationQuestionController.parseAddressBinding(
      'Parent_Guardian_2_City__c'
    );
    Assert.areEqual('Application', b.targetKey);
    Assert.areEqual('Parent_Guardian_2_City__c', b.fieldName);
  }

  private static AppQuestionSection findSection(
    List<AppQuestionSection> sections,
    String developerName
  ) {
    for (AppQuestionSection s : sections) {
      if (s.developerName == developerName) {
        return s;
      }
    }
    return null;
  }

  // ---------- Platform Cache experiments (WI-3248) ----------

  @IsTest
  private static void loadCachedFormStructure_secondCallHitsCache() {
    ApplicationQuestionController.resetCacheCounters();
    ApplicationQuestionController.clearFormStructureCache(PAGE_DEV_NAME, null);

    Test.startTest();
    AppQuestionFormStructure first = ApplicationQuestionController.loadCachedFormStructure(
      PAGE_DEV_NAME,
      null
    );
    AppQuestionFormStructure second = ApplicationQuestionController.loadCachedFormStructure(
      PAGE_DEV_NAME,
      null
    );
    Test.stopTest();

    Assert.isNotNull(first, 'First call must return a structure');
    Assert.isNotNull(second, 'Second call must return a structure');
    // First call always misses. Second call should hit if the partition is
    // available in this org; in scratch/sandbox without an allocated partition
    // the get/put both silently fail and we'd see two misses. Either way the
    // results must be equivalent.
    Assert.areEqual(
      first.sections.size(),
      second.sections.size(),
      'Cached structure must have the same section count as the fresh build'
    );
    Assert.isTrue(
      ApplicationQuestionController.cacheMissCount >= 1,
      'At least one miss must be recorded'
    );
  }

  @IsTest
  private static void loadCachedFormStructure_clearForcesRebuild() {
    ApplicationQuestionController.resetCacheCounters();
    ApplicationQuestionController.clearFormStructureCache(PAGE_DEV_NAME, null);

    ApplicationQuestionController.loadCachedFormStructure(PAGE_DEV_NAME, null);
    Integer missesAfterFirst = ApplicationQuestionController.cacheMissCount;

    ApplicationQuestionController.clearFormStructureCache(PAGE_DEV_NAME, null);
    ApplicationQuestionController.loadCachedFormStructure(PAGE_DEV_NAME, null);

    Assert.isTrue(
      ApplicationQuestionController.cacheMissCount > missesAfterFirst,
      'Clearing the cache must force a rebuild (additional miss)'
    );
  }

  @IsTest
  private static void loadCachedFormStructure_cacheDisabled_fallsBackToBuild() {
    ApplicationQuestionController.cacheDisabledForTest = true;
    ApplicationQuestionController.resetCacheCounters();
    try {
      AppQuestionFormStructure result = ApplicationQuestionController.loadCachedFormStructure(
        PAGE_DEV_NAME,
        null
      );
      Assert.isNotNull(result, 'Disabled cache must still return a structure');
      Assert.isTrue(result.sections.size() >= 2, 'Sections must be populated from CMDT');
      Assert.areEqual(
        0,
        ApplicationQuestionController.cacheHitCount,
        'No hits should be recorded when cache is disabled'
      );
    } finally {
      ApplicationQuestionController.cacheDisabledForTest = false;
    }
  }

  @IsTest
  private static void buildCacheKey_sanitizesAndIncludesVariant() {
    String nullVariantKey = ApplicationQuestionController.buildCacheKey(
      'Application_Details',
      null
    );
    String blankVariantKey = ApplicationQuestionController.buildCacheKey('Application_Details', '');
    String variantKey = ApplicationQuestionController.buildCacheKey(
      'Application_Details',
      'Elementary'
    );

    Assert.areEqual(
      nullVariantKey,
      blankVariantKey,
      'Null and blank variant must produce the same key'
    );
    Assert.areNotEqual(nullVariantKey, variantKey, 'Variant value must alter the cache key');
    Assert.isTrue(
      variantKey.length() <= 50,
      'Cache keys must stay within the platform 50-char limit'
    );
    Assert.isTrue(
      variantKey.contains('Elementary'),
      'Variant must appear in the key for human debuggability'
    );
  }

  @IsTest
  private static void getApplicationFormBundle_secondCallReturnsEquivalentBundle() {
    // Behavior contract: caching must not change observable output.
    ApplicationQuestionController.clearFormStructureCache(PAGE_DEV_NAME, null);

    AppFormBundle first = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );
    AppFormBundle second = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Assert.areEqual(
      first.formStructure.sections.size(),
      second.formStructure.sections.size(),
      'Section count must match across calls'
    );
    Assert.areEqual(
      first.formStructure.controllingQuestionDevNames.size(),
      second.formStructure.controllingQuestionDevNames.size(),
      'Controlling question list must match across calls'
    );
    Assert.areEqual(
      first.formStructure.page.developerName,
      second.formStructure.page.developerName
    );
  }

  private static AppQuestionInput findQuestion(
    List<AppQuestionInput> questions,
    String developerName
  ) {
    for (AppQuestionInput q : questions) {
      if (q.developerName == developerName) {
        return q;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Mock-based tests for the Address-question pathways (saveAddressQuestion,
  // getAddressQuestionValues, applyGuardianOneWriteback, applyGuardianTwoSameAsPrimary).
  // These cover the binding-resolution, multi-target write, and write-back logic
  // without depending on real DML against Person Accounts / IndividualApplication
  // (which would require timeline + category setup beyond this WI's scope).
  // ---------------------------------------------------------------------------

  @IsTest
  private static void saveAddressQuestion_studentBinding_writesToStudentAccount() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAcctId,
            Primary_Guardian__c = guardianAcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '100 Student Way',
        'city' => 'Brooklyn',
        'province' => 'NY',
        'postalCode' => '11201',
        'country' => 'US',
        'subpremise' => 'Apt 4B'
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, ADDRESS_QUESTION, payload);
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should update exactly the student Account');
    Account student = (Account) updated[0];
    Assert.areEqual(studentAcctId, student.Id);
    // Street is stored concatenated with the apartment so Salesforce's native
    // multi-line Street display shows them together; the standalone
    // Apartment_Number__c column stays populated for lossless round-trip.
    Assert.areEqual('100 Student Way\nApt 4B', student.PersonMailingStreet);
    Assert.areEqual('Brooklyn', student.PersonMailingCity);
    Assert.areEqual('NY', student.PersonMailingState);
    Assert.areEqual('11201', student.PersonMailingPostalCode);
    Assert.areEqual('US', student.PersonMailingCountry);
    Assert.areEqual('Apt 4B', student.Apartment_Number__c);
  }

  @IsTest
  private static void saveAddressQuestion_guardian2Binding_writesToGuardianAccount() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardian2AcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAcctId,
            Secondary_Guardian__c = guardian2AcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '200 Guardian Two Pkwy',
        'city' => 'Queens',
        'province' => 'NY',
        'postalCode' => '11375',
        'country' => 'US',
        'subpremise' => 'Unit 7'
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, GUARDIAN_2_QUESTION, payload);
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should update the Secondary Guardian Account once');
    Account guardian = (Account) updated[0];
    Assert.areEqual(guardian2AcctId, guardian.Id);
    // Street is stored concatenated with the apartment so Salesforce's native
    // multi-line Street display shows them together; the standalone
    // Apartment_Number__c column stays populated for round-trip.
    Assert.areEqual('200 Guardian Two Pkwy\nApt Unit 7', guardian.PersonMailingStreet);
    Assert.areEqual('Queens', guardian.PersonMailingCity);
    Assert.areEqual('NY', guardian.PersonMailingState);
    Assert.areEqual('11375', guardian.PersonMailingPostalCode);
    Assert.areEqual('US', guardian.PersonMailingCountry);
    Assert.areEqual('Unit 7', guardian.Apartment_Number__c);
  }

  @IsTest
  private static void saveAddressQuestion_guardian2Binding_lookupNull_stagesOnApplication() {
    // The user saved a Guardian 2 address before the upsert-guardians flow has
    // stamped Secondary_Guardian__c (the flow runs async after the first save
    // that introduces Guardian 2 data). The write must fall back to the
    // application's Parent_Guardian_2_* staging fields so the flow copies real
    // values (not blanks) onto the Account when it creates or matches it.
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Secondary_Guardian__c = null)
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '1 Test St',
        'city' => 'Brooklyn',
        'province' => 'NY',
        'postalCode' => '11201',
        'country' => 'US',
        'subpremise' => '9'
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, GUARDIAN_2_QUESTION, payload);
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should update exactly the application');
    IndividualApplication staged = (IndividualApplication) updated[0];
    Assert.areEqual(appId, staged.Id);
    // Street is stored concatenated with the apartment (same convention as the
    // direct-to-Account write path).
    Assert.areEqual('1 Test St\nApt 9', staged.Parent_Guardian_2_Street__c);
    Assert.areEqual('Brooklyn', staged.Parent_Guardian_2_City__c);
    Assert.areEqual('NY', staged.Parent_Guardian_2_State__c);
    Assert.areEqual('11201', staged.Parent_Guardian_2_Zip__c);
    Assert.areEqual('9', staged.Parent_Guardian_2_Apartment__c);
    // No staging field exists for country — it must be dropped, not error.
    Assert.isFalse(
      staged.getPopulatedFieldsAsMap().containsKey('PersonMailingCountry'),
      'Country has no staging field and should not be written'
    );
  }

  @IsTest
  private static void saveAddressQuestion_guardian2Binding_lookupNull_noOpWhenNoMappableFields() {
    // Country is the only slot with no staging equivalent. A payload containing
    // ONLY country (lookup not stamped) should produce no DML at all.
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Secondary_Guardian__c = null)
        }
      );

    String payload = JSON.serialize(new Map<String, Object>{ 'country' => 'US' });

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, GUARDIAN_2_QUESTION, payload);
    Test.stopTest();

    mockDb.never(mockDb.method.updateSObjects());
  }

  @IsTest
  private static void saveAddressQuestion_guardian1Binding_writesToGuardianAccount() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAcctId,
            Primary_Guardian__c = guardianAcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '300 Guardian Ln',
        'city' => 'Bronx',
        'province' => 'NY',
        'postalCode' => '10451',
        'country' => 'US',
        'subpremise' => 'Apt 1'
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(
      appId,
      'Guardian_1_Address_Compound',
      payload
    );
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size());
    Account guardian = (Account) updated[0];
    Assert.areEqual(guardianAcctId, guardian.Id);
    // Street is stored concatenated with the apartment so Salesforce's native
    // multi-line Street display shows them together; the standalone
    // Apartment_Number__c column stays populated for round-trip.
    Assert.areEqual('300 Guardian Ln\nApt 1', guardian.PersonMailingStreet);
    Assert.areEqual('Bronx', guardian.PersonMailingCity);
    Assert.areEqual('NY', guardian.PersonMailingState);
    Assert.areEqual('10451', guardian.PersonMailingPostalCode);
    Assert.areEqual('Apt 1', guardian.Apartment_Number__c);
  }

  @IsTest
  private static void clearAddressQuestion_studentBinding_nullsStudentAccountFields() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAcctId,
            Primary_Guardian__c = guardianAcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    Test.startTest();
    ApplicationQuestionController.clearAddressQuestion(appId, ADDRESS_QUESTION);
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size(), 'Should null the student Account only');
    Account student = (Account) updated[0];
    Assert.areEqual(studentAcctId, student.Id);
    Assert.isNull(student.PersonMailingStreet);
    Assert.isNull(student.PersonMailingCity);
    Assert.isNull(student.PersonMailingState);
    Assert.isNull(student.PersonMailingPostalCode);
    Assert.isNull(student.PersonMailingCountry);
    Assert.isNull(student.Apartment_Number__c);
  }

  @IsTest
  private static void clearAddressQuestion_unknownApplication_throws() {
    Id fakeAppId =
      IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    Boolean threwExpected = false;
    try {
      ApplicationQuestionController.clearAddressQuestion(fakeAppId, ADDRESS_QUESTION);
    } catch (IllegalArgumentException e) {
      threwExpected = e.getMessage().startsWith('IndividualApplication not found');
    }
    Assert.isTrue(threwExpected, 'Should throw IndividualApplication not found error');
  }

  @IsTest
  private static void clearAddressQuestion_nullId_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Application Id is required'
    );
    try {
      ApplicationQuestionController.clearAddressQuestion(null, ADDRESS_QUESTION);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    throwing.assertHasThrown();
  }

  @IsTest
  private static void getAddressQuestionValues_returnsStudentAddressValues() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = studentAcctId,
            PersonMailingStreet = '300 Existing Ln',
            PersonMailingCity = 'Bronx',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '10451',
            PersonMailingCountry = 'US',
            Apartment_Number__c = 'Apt 1'
          )
        }
      );

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      appId,
      ADDRESS_QUESTION
    );

    Assert.areEqual('300 Existing Ln', result.get('street'));
    Assert.areEqual('Bronx', result.get('city'));
    Assert.areEqual('NY', result.get('province'));
    Assert.areEqual('10451', result.get('postalCode'));
    Assert.areEqual('US', result.get('country'));
    Assert.areEqual('Apt 1', result.get('subpremise'));
  }

  @IsTest
  private static void getAddressQuestionValues_guardian2Binding_readsFromGuardianAccount() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardian2AcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, Secondary_Guardian__c = guardian2AcctId)
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = guardian2AcctId,
            PersonMailingStreet = '99 Existing Ave',
            PersonMailingCity = 'Manhattan',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '10001',
            PersonMailingCountry = 'US',
            Apartment_Number__c = 'PH 1'
          )
        }
      );

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      appId,
      GUARDIAN_2_QUESTION
    );

    Assert.areEqual('99 Existing Ave', result.get('street'));
    Assert.areEqual('Manhattan', result.get('city'));
    Assert.areEqual('NY', result.get('province'));
    Assert.areEqual('10001', result.get('postalCode'));
    Assert.areEqual('US', result.get('country'));
    Assert.areEqual('PH 1', result.get('subpremise'));
  }

  @IsTest
  private static void getAddressQuestionValues_guardian2Binding_lookupNull_readsFromStagingFields() {
    // While Secondary_Guardian__c isn't stamped, saved Guardian 2 addresses live
    // on the application's Parent_Guardian_2_* staging fields (see the save-side
    // fallback). The read path must mirror that so the form round-trips what the
    // user entered instead of rendering blank fields.
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Secondary_Guardian__c = null,
            Parent_Guardian_2_Street__c = '1 Test St\nApt 9',
            Parent_Guardian_2_City__c = 'Brooklyn',
            Parent_Guardian_2_State__c = 'NY',
            Parent_Guardian_2_Zip__c = '11201',
            Parent_Guardian_2_Apartment__c = '9'
          )
        }
      );

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      appId,
      GUARDIAN_2_QUESTION
    );

    // Street comes back stripped of the "\nApt ..." suffix (the apartment input
    // renders from the subpremise slot).
    Assert.areEqual('1 Test St', result.get('street'));
    Assert.areEqual('Brooklyn', result.get('city'));
    Assert.areEqual('NY', result.get('province'));
    Assert.areEqual('11201', result.get('postalCode'));
    Assert.areEqual('9', result.get('subpremise'));
    // No staging field for country exists, so the slot stays absent.
    Assert.isFalse(result.containsKey('country'), 'Country slot should be absent');
  }

  @IsTest
  private static void applyCompanionWriteback_writesToCompanionBindings() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            AccountId = studentAcctId,
            Primary_Guardian__c = guardianAcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '400 Copy St',
        'city' => 'Staten Island',
        'province' => 'NY',
        'postalCode' => '10301',
        'country' => 'US',
        'subpremise' => 'Apt Z'
      }
    );

    Test.startTest();
    ApplicationQuestionController.applyCompanionWriteback(
      appId,
      payload,
      'Guardian_1_Address_Compound'
    );
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size());
    Account guardian = (Account) updated[0];
    Assert.areEqual(guardianAcctId, guardian.Id);
    // Street is merged with the apartment ("Apt " prefix preserved, not doubled).
    Assert.areEqual('400 Copy St\nApt Z', guardian.PersonMailingStreet);
    Assert.areEqual('Staten Island', guardian.PersonMailingCity);
    Assert.areEqual('NY', guardian.PersonMailingState);
    Assert.areEqual('10301', guardian.PersonMailingPostalCode);
    Assert.areEqual('US', guardian.PersonMailingCountry);
    Assert.areEqual('Apt Z', guardian.Apartment_Number__c);
  }

  @IsTest
  private static void applyCompanionCopyFrom_copiesGuardian1ToGuardian2Account() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardian1AcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardian2AcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    // Four queryWithBinds calls happen during copy under the new bindings:
    //  1. getAddressQuestionValues → IndividualApplication (resolves Primary + Secondary lookups)
    //  2. getAddressQuestionValues → Guardian 1 Account (needsGuardian1)
    //  3. saveAddressQuestion     → IndividualApplication (resolves Secondary_Guardian__c for the write target)
    // Stubs reuse the last value for any extra calls.
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardian1AcctId,
            Secondary_Guardian__c = guardian2AcctId
          )
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = guardian1AcctId,
            PersonMailingStreet = '500 Primary Blvd',
            PersonMailingCity = 'Manhattan',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '10001',
            PersonMailingCountry = 'US',
            Apartment_Number__c = 'PH 1'
          )
        }
      )
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(
            Id = appId,
            Primary_Guardian__c = guardian1AcctId,
            Secondary_Guardian__c = guardian2AcctId
          )
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    Test.startTest();
    ApplicationQuestionController.applyCompanionCopyFrom(
      appId,
      'Guardian_1_Address_Compound',
      'Guardian_2_Address_Compound'
    );
    Test.stopTest();

    mockDb.verify(mockDb.method.updateSObjects());
    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Assert.areEqual(1, updated.size());
    Account guardian2 = (Account) updated[0];
    Assert.areEqual(guardian2AcctId, guardian2.Id);
    // Source apt column was 'PH 1'; merged street becomes "<street>\nApt PH 1".
    Assert.areEqual('500 Primary Blvd\nApt PH 1', guardian2.PersonMailingStreet);
    Assert.areEqual('Manhattan', guardian2.PersonMailingCity);
    Assert.areEqual('NY', guardian2.PersonMailingState);
    Assert.areEqual('10001', guardian2.PersonMailingPostalCode);
    Assert.areEqual('US', guardian2.PersonMailingCountry);
    Assert.areEqual('PH 1', guardian2.Apartment_Number__c);
  }

  @IsTest
  private static void applyCompanionCopyFrom_emptySource_skipsWrite() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ new IndividualApplication(Id = appId) });

    Test.startTest();
    ApplicationQuestionController.applyCompanionCopyFrom(
      appId,
      'Guardian_1_Address_Compound',
      'Guardian_2_Address_Compound'
    );
    Test.stopTest();

    mockDb.never(mockDb.method.updateSObjects());
  }

  @IsTest
  private static void saveAddressQuestion_concatenatesApartmentIntoStreet() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '123 Main St',
        'city' => 'Brooklyn',
        'province' => 'NY',
        'postalCode' => '11201',
        'country' => 'US',
        'subpremise' => '4B'
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, ADDRESS_QUESTION, payload);
    Test.stopTest();

    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Account student = (Account) updated[0];
    Assert.areEqual('123 Main St\nApt 4B', student.PersonMailingStreet);
    Assert.areEqual('4B', student.Apartment_Number__c);
  }

  @IsTest
  private static void saveAddressQuestion_streetOnly_noTrailingNewline() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{
        'street' => '789 Park Pl',
        'city' => 'Brooklyn',
        'province' => 'NY',
        'postalCode' => '11216',
        'country' => 'US',
        'subpremise' => ''
      }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, ADDRESS_QUESTION, payload);
    Test.stopTest();

    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Account student = (Account) updated[0];
    Assert.areEqual('789 Park Pl', student.PersonMailingStreet);
    Assert.isFalse(
      student.PersonMailingStreet.contains('\nApt'),
      'Street should not have a trailing apartment line when apt is blank'
    );
  }

  @IsTest
  private static void saveAddressQuestion_apartmentOnly_writesAptPrefix() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{ 'street' => '', 'subpremise' => '4B' }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, ADDRESS_QUESTION, payload);
    Test.stopTest();

    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Account student = (Account) updated[0];
    Assert.areEqual('Apt 4B', student.PersonMailingStreet);
    Assert.areEqual('4B', student.Apartment_Number__c);
  }

  @IsTest
  private static void saveAddressQuestion_apartmentWithAptPrefix_doesNotDoublePrefix() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      );
    mockDb.when(mockDb.method.updateSObjects()).thenReturnVoid();

    String payload = JSON.serialize(
      new Map<String, Object>{ 'street' => '123 Main St', 'subpremise' => 'Apt 4B' }
    );

    Test.startTest();
    ApplicationQuestionController.saveAddressQuestion(appId, ADDRESS_QUESTION, payload);
    Test.stopTest();

    List<Map<String, Object>> calls = mockDb.getCalls(mockDb.method.updateSObjects());
    List<SObject> updated = (List<SObject>) calls[calls.size() - 1].get('sobjects');
    Account student = (Account) updated[0];
    Assert.areEqual('123 Main St\nApt 4B', student.PersonMailingStreet);
    Assert.areEqual('Apt 4B', student.Apartment_Number__c);
  }

  @IsTest
  private static void getAddressQuestionValues_stripsApartmentLineFromStreet() {
    DatabaseRepoMock mockDb = new DatabaseRepoMock();
    ApplicationQuestionController.databaseRepo = mockDb;

    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id studentAcctId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    mockDb.when(mockDb.method.queryWithBinds())
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = appId, AccountId = studentAcctId)
        }
      )
      .thenReturn(
        new List<Account>{
          new Account(
            Id = studentAcctId,
            PersonMailingStreet = '123 Main St\nApt 4B',
            PersonMailingCity = 'Brooklyn',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '11201',
            PersonMailingCountry = 'US',
            Apartment_Number__c = '4B'
          )
        }
      );

    Map<String, String> result = ApplicationQuestionController.getAddressQuestionValues(
      appId,
      ADDRESS_QUESTION
    );

    Assert.areEqual('123 Main St', result.get('street'));
    Assert.areEqual('4B', result.get('subpremise'));
  }

  @IsTest
  private static void mergeStreetAndApartment_bothBlank_returnsNull() {
    Assert.areEqual(null, ApplicationQuestionController.mergeStreetAndApartment('', ''));
    Assert.areEqual(null, ApplicationQuestionController.mergeStreetAndApartment(null, null));
  }

  @IsTest
  private static void stripApartmentSuffix_noNewline_returnsTrimmedInput() {
    Assert.areEqual(
      '123 Main St',
      ApplicationQuestionController.stripApartmentSuffix('  123 Main St  ')
    );
  }

  @IsTest
  private static void stripApartmentSuffix_nonAptTrailer_returnsTrimmedInput() {
    // A newline followed by anything other than "Apt " should NOT be stripped
    // — only "\nApt ..." is treated as a suffix.
    Assert.areEqual(
      '123 Main St\nFloor 2',
      ApplicationQuestionController.stripApartmentSuffix('123 Main St\nFloor 2')
    );
  }

  // ---------- Section-scoped bundle (create-screen address widget) ----------

  private static final String ADDRESS_SCOPE = 'Address,Guardian_1_Address,Student_Living_Status';

  @IsTest
  private static void parseSectionScope_blank_returnsNull() {
    Assert.isNull(ApplicationQuestionController.parseSectionScope(null));
    Assert.isNull(ApplicationQuestionController.parseSectionScope(''));
    Assert.isNull(ApplicationQuestionController.parseSectionScope('   '));
  }

  @IsTest
  private static void parseSectionScope_trimsAndDropsBlanks() {
    Set<String> scope = ApplicationQuestionController.parseSectionScope(
      ' Address , ,Guardian_1_Address '
    );
    Assert.areEqual(2, scope.size(), 'Should parse two non-blank, trimmed names');
    Assert.isTrue(scope.contains('Address'));
    Assert.isTrue(scope.contains('Guardian_1_Address'));
  }

  @IsTest
  private static void scopedBundle_returnsOnlyScopedSections() {
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null,
      ADDRESS_SCOPE
    );

    Assert.isNotNull(bundle.formStructure, 'Scoped bundle must include a form structure');
    // Only the two scoped sections — nothing else from Application_Details.
    for (AppQuestionSection section : bundle.formStructure.sections) {
      Assert.isTrue(
        section.developerName == 'Address' ||
          section.developerName == 'Guardian_1_Address' ||
          section.developerName == 'Student_Living_Status',
        'Scoped bundle leaked an out-of-scope section: ' + section.developerName
      );
    }
    Assert.isNotNull(
      findSection(bundle.formStructure.sections, 'Address'),
      'Address section must be present in the scoped bundle'
    );
    Assert.isNotNull(
      findSection(bundle.formStructure.sections, 'Guardian_1_Address'),
      'Guardian_1_Address section must be present in the scoped bundle'
    );
    Assert.isNotNull(
      findSection(bundle.formStructure.sections, 'Student_Living_Status'),
      'Student_Living_Status section must be present in the scoped bundle'
    );
    Assert.isNull(
      findSection(bundle.formStructure.sections, GUARDIAN_SECTION),
      'Guardian_Information must NOT appear in the address-scoped bundle'
    );
    Assert.isNull(
      findSection(bundle.formStructure.sections, 'Employee_Information'),
      'Employee_Information must NOT appear in the address-scoped bundle'
    );
  }

  @IsTest
  private static void scopedBundle_includesLivesWithGuardianCheckbox() {
    // The two-address capture depends on the Lives_With_Guardian_1 checkbox —
    // which now lives in its own Student_Living_Status section — being part of
    // the scoped create-screen fetch.
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null,
      ADDRESS_SCOPE
    );

    AppQuestionSection address = findSection(bundle.formStructure.sections, 'Address');
    Assert.isNotNull(address, 'Address section should exist in the scoped bundle');
    Assert.isNotNull(
      findQuestion(address.questions, 'Address_Compound'),
      'Scoped Address section must still contain the Address_Compound question'
    );

    AppQuestionSection g1 = findSection(bundle.formStructure.sections, 'Guardian_1_Address');
    Assert.isNotNull(g1, 'Guardian_1_Address section should exist in the scoped bundle');
    Assert.isNotNull(
      findQuestion(g1.questions, 'Guardian_1_Address_Compound'),
      'Scoped Guardian_1_Address section must still contain its Address question'
    );

    AppQuestionSection livingStatus = findSection(
      bundle.formStructure.sections,
      'Student_Living_Status'
    );
    Assert.isNotNull(
      livingStatus,
      'Student_Living_Status section should exist in the scoped bundle'
    );
    Assert.isNotNull(
      findQuestion(livingStatus.questions, 'Lives_With_Guardian_1'),
      'Scoped Student_Living_Status section must contain the Lives_With_Guardian_1 checkbox'
    );
  }

  @IsTest
  private static void scopedBundle_skipsSubmissionWarnings() {
    // The residency/age banner belongs on the full form, not the create screen.
    // The scoped call must NOT compute warnings — it returns the all-false default.
    AppFormBundle bundle = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null,
      ADDRESS_SCOPE
    );

    Assert.isNotNull(bundle.submissionWarnings, 'submissionWarnings map must be initialised');
    Assert.areEqual(
      false,
      bundle.submissionWarnings.get('hasAgeWarning'),
      'Scoped bundle must report no age warning'
    );
    Assert.areEqual(
      false,
      bundle.submissionWarnings.get('hasResidencyWarning'),
      'Scoped bundle must report no residency warning'
    );
  }

  @IsTest
  private static void scopedBundle_existingAnswersLimitedToScopedQuestions() {
    // existingAnswers is derived from the (scoped) form structure: only fields owned
    // by questions inside the scoped sections can ever appear. With a fake recordId
    // the query returns nothing, but the contract we assert is that an out-of-scope
    // question (Guardian_1_First_Name, in Guardian_Information) is absent from the
    // scoped structure and therefore can never surface in the scoped answer map.
    Id fakeId = IndividualApplication.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA';

    AppFormBundle scoped = ApplicationQuestionController.getApplicationFormBundle(
      fakeId,
      PAGE_DEV_NAME,
      null,
      ADDRESS_SCOPE
    );

    Assert.isNotNull(scoped.existingAnswers, 'existingAnswers must be initialised');
    Assert.isTrue(
      scoped.existingAnswers.isEmpty(),
      'Fake recordId yields no answers; scoped path must still produce an empty map'
    );

    // The scoped structure must not expose any out-of-scope question, which is what
    // bounds the answer query to scoped fields only.
    Set<String> scopedQuestionDevNames = new Set<String>();
    for (AppQuestionSection section : scoped.formStructure.sections) {
      for (AppQuestionInput q : section.questions) {
        scopedQuestionDevNames.add(q.developerName);
      }
    }
    Assert.isFalse(
      scopedQuestionDevNames.contains('Guardian_1_First_Name'),
      'Out-of-scope question must not be present in the scoped structure'
    );
    Assert.isTrue(
      scopedQuestionDevNames.contains('Address_Compound'),
      'Scoped structure must contain the in-scope Address question'
    );
  }

  @IsTest
  private static void unscopedBundle_stillReturnsFullPage() {
    // The no-scope path (page 4) must be unchanged: full sections + real warnings.
    AppFormBundle full = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null,
      null
    );
    AppFormBundle threeArg = ApplicationQuestionController.getApplicationFormBundle(
      null,
      PAGE_DEV_NAME,
      null
    );

    Assert.isTrue(
      full.formStructure.sections.size() >= 2,
      'Unscoped bundle must include the whole page'
    );
    Assert.areEqual(
      threeArg.formStructure.sections.size(),
      full.formStructure.sections.size(),
      'Three-arg overload and null-scope four-arg must return the same full page'
    );
    Assert.isNotNull(
      findSection(full.formStructure.sections, GUARDIAN_SECTION),
      'Unscoped bundle must still include Guardian_Information'
    );
    // Warnings ARE computed on the full path (default false for a null recordId).
    Assert.isTrue(
      full.submissionWarnings.containsKey('hasResidencyWarning'),
      'Unscoped bundle must compute submission warnings'
    );
  }

  @IsTest
  private static void buildCacheKey_scopeAltersKeyAndIsOrderIndependent() {
    String fullKey = ApplicationQuestionController.buildCacheKey(PAGE_DEV_NAME, null, null);
    String scopedKey = ApplicationQuestionController.buildCacheKey(
      PAGE_DEV_NAME,
      null,
      new Set<String>{ 'Address', 'Guardian_1_Address' }
    );
    String scopedKeyReordered = ApplicationQuestionController.buildCacheKey(
      PAGE_DEV_NAME,
      null,
      new Set<String>{ 'Guardian_1_Address', 'Address' }
    );

    Assert.areNotEqual(fullKey, scopedKey, 'Scoped key must not collide with the full-page key');
    Assert.areEqual(
      scopedKey,
      scopedKeyReordered,
      'Scope token must be order-independent so set iteration order cannot fork the key'
    );
    Assert.isTrue(scopedKey.length() <= 50, 'Scoped key must stay within the 50-char limit');
    Assert.isTrue(
      Pattern.matches('[a-zA-Z0-9]+', scopedKey),
      'Scoped key must be strictly alphanumeric'
    );
  }

  @IsTest
  private static void buildScopeToken_longScope_hashesWithinBudget() {
    Set<String> bigScope = new Set<String>{
      'Section_With_A_Really_Long_Developer_Name_One',
      'Section_With_A_Really_Long_Developer_Name_Two',
      'Section_With_A_Really_Long_Developer_Name_Three'
    };
    String token = ApplicationQuestionController.buildScopeToken(bigScope);
    Assert.isTrue(token.length() <= 16, 'Long scopes must hash to a bounded token');
    Assert.isTrue(Pattern.matches('[a-zA-Z0-9]+', token), 'Scope token must be alphanumeric');
  }

  @IsTest
  private static void scopedLoadCachedFormStructure_secondCallEquivalent() {
    Set<String> scope = new Set<String>{ 'Address', 'Guardian_1_Address' };
    ApplicationQuestionController.clearFormStructureCache(PAGE_DEV_NAME, null);

    AppQuestionFormStructure first = ApplicationQuestionController.loadCachedFormStructure(
      PAGE_DEV_NAME,
      null,
      scope
    );
    AppQuestionFormStructure second = ApplicationQuestionController.loadCachedFormStructure(
      PAGE_DEV_NAME,
      null,
      scope
    );

    Assert.areEqual(
      first.sections.size(),
      second.sections.size(),
      'Scoped structure must be stable across calls'
    );
    // Scoped build returns only the two address sections.
    Assert.isTrue(first.sections.size() <= 2, 'Scoped structure must be limited to its sections');
  }

  private static final String GUARDIAN_2_QUESTION = 'Guardian_2_Address_Compound';
  private static final String ADDRESS_QUESTION = 'Address_Compound';
}