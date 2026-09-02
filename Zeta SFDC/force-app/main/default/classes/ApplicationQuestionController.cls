/**
 * Controller for the Application Question Framework.
 * Provides metadata-driven form structure and answer persistence.
 */
public without sharing class ApplicationQuestionController {
  @TestVisible
  private static SObjectFieldCriteriaEvaluator criteriaEvaluator = new SObjectFieldCriteriaEvaluatorImpl();

  @TestVisible
  private static DatabaseRepo databaseRepo = new SystemModeDatabaseRepo();

  // Platform Cache partition for CMDT-derived form structures.
  // Defined in force-app/main/default/cachePartitions/ApplicationCache.cachePartition-meta.xml.
  // Long TTL is safe because the cached object depends only on Application_Section__mdt
  // and Application_Question__mdt — both of which change only on admin deploy.
  @TestVisible
  private static final String CACHE_PARTITION_NAME = 'local.ApplicationCache';
  @TestVisible
  private static final Integer CACHE_TTL_SECONDS = 43200; // 12 hours

  // In-memory cache hits/misses counters for tests + measurement.
  @TestVisible
  private static Integer cacheHitCount = 0;
  @TestVisible
  private static Integer cacheMissCount = 0;
  @TestVisible
  private static Boolean cacheDisabledForTest = false;

  /**
   * Returns the form structure for a given page, optionally filtered by variant.
   * When recordId is provided, evaluates visibility criteria to filter sections/questions.
   *
   * @param pageDevName The DeveloperName of the Application_Page__mdt record
   * @param variant Optional variant filter (e.g., 'Elementary', 'Middle', 'High')
   * @param recordId Optional record Id for visibility criteria evaluation
   * @return The complete form structure with page, sections, and questions
   */
  @AuraEnabled(cacheable=true)
  public static AppQuestionFormStructure getFormStructure(
    String pageDevName,
    String variant,
    Id recordId
  ) {
    Preconditions.checkNotBlank(pageDevName, 'Page developer name is required');
    return loadCachedFormStructure(pageDevName, variant);
  }

  /**
   * Bundled accessor used by the application-form LWC initial load. Returns the form
   * structure, existing answers, guardian defaults (when applicable) and submission
   * warnings in a single cacheable response so the client only makes one Apex round
   * trip on step load.
   *
   * NOTE: Apex forbids overloading @AuraEnabled methods, so this is the single entry
   * point. Callers that want the full page (e.g. page 4) pass a blank/null
   * {@code includeSectionDevNames}; the create-screen address widget passes its
   * section scope. {@code includeSectionDevNames} is non-nullable-friendly: blank,
   * null, and "no scope" all collapse to the full-page path.
   *
   * When {@code includeSectionDevNames} is blank, this returns the FULL page bundle
   * — including guardian defaults and submission warnings. This is the page-4 /
   * full-form path and is unchanged from the original three-arg behavior.
   *
   * When {@code includeSectionDevNames} names one or more sections (comma-separated),
   * the response is scoped to ONLY those sections SERVER-SIDE:
   *   - the form structure contains only the named sections and their questions;
   *   - existing answers are limited to fields owned by those questions;
   *   - {@code submissionWarnings} is NOT computed (the residency/age banner belongs
   *     on the full form, not the embedded create-screen address widget) — it is
   *     returned as the default all-false map so the LWC never renders a banner;
   *   - the assembled structure is cached under a scope-aware key so the page-1
   *     (address-only) and page-4 (full) variants never collide in the Org partition.
   *
   * Guardian defaults are still resolved for Application_Details regardless of scope
   * (cheap, and the embedded create-screen address form benefits from Guardian_1_*
   * prefill when relevant).
   *
   * @param recordId Optional record Id for existing-answer lookup
   * @param pageDevName The DeveloperName of the Application_Page__mdt record
   * @param variant Optional variant filter
   * @param includeSectionDevNames Optional comma-separated section DeveloperNames to scope to
   */
  @AuraEnabled(cacheable=true)
  public static AppFormBundle getApplicationFormBundle(
    Id recordId,
    String pageDevName,
    String variant,
    String includeSectionDevNames
  ) {
    Preconditions.checkNotBlank(pageDevName, 'Page developer name is required');

    Set<String> sectionScope = parseSectionScope(includeSectionDevNames);
    Boolean isScoped = sectionScope != null && !sectionScope.isEmpty();

    AppQuestionFormStructure structure = loadCachedFormStructure(
      pageDevName,
      variant,
      sectionScope
    );

    AppFormBundle bundle = new AppFormBundle();
    bundle.formStructure = structure;
    bundle.existingAnswers = loadExistingAnswersFromStructure(recordId, structure);
    bundle.guardianDefaults = (pageDevName == 'Application_Details')
      ? loadGuardianDefaults()
      : new Map<String, String>();
    // Scoped (embedded create-screen) calls intentionally SKIP the submission-warning
    // query: the residency/age banner belongs on the full form (page 4), not on the
    // address-only widget. Return the default all-false map so the LWC stays banner-free.
    bundle.submissionWarnings = isScoped
      ? defaultSubmissionWarnings()
      : loadSubmissionWarnings(recordId);
    return bundle;
  }

  /**
   * Convenience full-page accessor (no section scope). Not @AuraEnabled — Apex
   * forbids overloading exposed methods — so this exists only for internal/test
   * callers that want the original three-arg ergonomics. Delegates to the scoped
   * entry point with a null scope.
   */
  @TestVisible
  private static AppFormBundle getApplicationFormBundle(
    Id recordId,
    String pageDevName,
    String variant
  ) {
    return getApplicationFormBundle(recordId, pageDevName, variant, null);
  }

  /**
   * Parses a comma-separated section-scope string into a Set of trimmed, non-blank
   * DeveloperNames. Returns null when the input is blank (i.e. "no scope / full page").
   */
  @TestVisible
  private static Set<String> parseSectionScope(String includeSectionDevNames) {
    if (String.isBlank(includeSectionDevNames)) {
      return null;
    }
    Set<String> scope = new Set<String>();
    for (String raw : includeSectionDevNames.split(',')) {
      String trimmed = raw == null ? '' : raw.trim();
      if (String.isNotBlank(trimmed)) {
        scope.add(trimmed);
      }
    }
    return scope.isEmpty() ? null : scope;
  }

  private static Map<String, Boolean> defaultSubmissionWarnings() {
    return new Map<String, Boolean>{ 'hasAgeWarning' => false, 'hasResidencyWarning' => false };
  }

  /**
   * Returns the assembled form structure for (pageDevName, variant) from Platform Cache
   * when available, otherwise builds it from CMDT and writes it to the cache.
   *
   * The cached object depends ONLY on CMDT records (Application_Page, Application_Section,
   * Application_Question, SObject_Field, SObject_Field_Criteria) — none of which can change
   * outside an admin deploy. recordId/answers are intentionally excluded from the key.
   *
   * Defensive: any cache failure (missing partition, no capacity, serialization error)
   * falls back to the non-cached build path. Never throws.
   */
  @TestVisible
  private static AppQuestionFormStructure loadCachedFormStructure(
    String pageDevName,
    String variant
  ) {
    return loadCachedFormStructure(pageDevName, variant, null);
  }

  /**
   * Section-scoped overload. When {@code sectionScope} is non-empty the assembled
   * structure contains ONLY those sections (filtered before assembly and questions
   * queried for only those sections), and it is cached under a scope-aware key so the
   * full-page and address-only variants don't overwrite each other in the partition.
   */
  @TestVisible
  private static AppQuestionFormStructure loadCachedFormStructure(
    String pageDevName,
    String variant,
    Set<String> sectionScope
  ) {
    String key = buildCacheKey(pageDevName, variant, sectionScope);

    if (!cacheDisabledForTest) {
      try {
        Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION_NAME);
        if (partition != null) {
          Object cached = partition.get(key);
          if (cached != null && cached instanceof AppQuestionFormStructure) {
            cacheHitCount++;
            return (AppQuestionFormStructure) cached;
          }
        }
      } catch (Exception e) {
        // Partition missing, no allocated capacity, or other platform error.
        System.debug(LoggingLevel.WARN, 'ApplicationCache get failed: ' + e.getMessage());
      }
    }

    cacheMissCount++;
    AppQuestionFormStructure built = buildFormStructureFromCmdt(pageDevName, variant, sectionScope);

    if (!cacheDisabledForTest && built != null) {
      try {
        Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION_NAME);
        if (partition != null) {
          partition.put(key, built, CACHE_TTL_SECONDS);
        }
      } catch (Exception e) {
        // Put can fail if value isn't Serializable or partition has no capacity.
        // Log and continue — the live build path already returned a usable structure.
        System.debug(LoggingLevel.WARN, 'ApplicationCache put failed: ' + e.getMessage());
      }
    }

    return built;
  }

  /**
   * Cache key shape: 'fs<Page><Variant>' (alphanumeric only).
   * Platform cache keys MUST match [a-zA-Z0-9]+ — underscores and punctuation are
   * rejected with "Invalid Key, Key cannot be null or empty and must be alphanumeric".
   * Max length 50 chars total (the "local.<partition>." prefix doesn't count here).
   */
  @TestVisible
  private static String buildCacheKey(String pageDevName, String variant) {
    return buildCacheKey(pageDevName, variant, null);
  }

  /**
   * Scope-aware cache key. Shape:
   *   - full page (no scope): 'fs<Page><Variant>'
   *   - scoped:               'fs<Page><Variant>s<scopeToken>'
   * The scope token is an order-independent, alphanumeric digest of the scoped
   * section DeveloperNames (sorted, sanitized, then hashed if it would exceed the
   * 50-char limit). This guarantees the address-only (page-1) and full (page-4)
   * variants never collide in the Org partition.
   */
  @TestVisible
  private static String buildCacheKey(
    String pageDevName,
    String variant,
    Set<String> sectionScope
  ) {
    String v = String.isBlank(variant) ? 'X' : variant;
    String raw = 'fs' + pageDevName + v;
    if (sectionScope != null && !sectionScope.isEmpty()) {
      raw += 's' + buildScopeToken(sectionScope);
    }
    // Strip non-alphanumeric (this turns DeveloperNames like Application_Details
    // into ApplicationDetails — still uniquely identifying within this partition).
    String key = raw.replaceAll('[^a-zA-Z0-9]', '');
    return key.length() > 50 ? key.substring(0, 50) : key;
  }

  /**
   * Builds a stable, order-independent token from the scoped section names. Sorting
   * makes "Address,Guardian_1_Address" and "Guardian_1_Address,Address" collapse to
   * the same key. When the sanitized concatenation is long enough to risk blowing the
   * 50-char key budget, we substitute an 8-char hex digest so the key stays bounded
   * yet remains unique per distinct scope.
   */
  @TestVisible
  private static String buildScopeToken(Set<String> sectionScope) {
    List<String> names = new List<String>(sectionScope);
    names.sort();
    String joined = String.join(names, '');
    String sanitized = joined.replaceAll('[^a-zA-Z0-9]', '');
    if (sanitized.length() <= 24) {
      return sanitized;
    }
    // Hash to keep the overall key within the platform limit for large scopes.
    Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(joined));
    return EncodingUtil.convertToHex(digest).substring(0, 16);
  }

  /**
   * Pure CMDT-derived build path. Identical to the old inline body of
   * getApplicationFormBundle minus the recordId-dependent pieces.
   */
  private static AppQuestionFormStructure buildFormStructureFromCmdt(
    String pageDevName,
    String variant
  ) {
    return buildFormStructureFromCmdt(pageDevName, variant, null);
  }

  /**
   * Section-scoped CMDT build path. When {@code sectionScope} is non-empty, only the
   * named sections (and only those sections' questions) are queried/assembled — the
   * question SOQL is narrowed to the scoped section DeveloperNames so we never fetch,
   * filter, or assemble the rest of the page's questions on the create screen.
   */
  private static AppQuestionFormStructure buildFormStructureFromCmdt(
    String pageDevName,
    String variant,
    Set<String> sectionScope
  ) {
    AppQuestionPage page = queryPage(pageDevName);
    List<Application_Section__mdt> sectionRecords = querySections(pageDevName);
    List<Application_Section__mdt> filteredSections = filterSectionsByVariant(
      sectionRecords,
      variant
    );

    // Apply the section scope BEFORE collecting question dev-names so the question
    // SOQL is narrowed to only the scoped sections.
    Boolean isScoped = sectionScope != null && !sectionScope.isEmpty();
    if (isScoped) {
      List<Application_Section__mdt> scoped = new List<Application_Section__mdt>();
      for (Application_Section__mdt section : filteredSections) {
        if (sectionScope.contains(section.DeveloperName)) {
          scoped.add(section);
        }
      }
      filteredSections = scoped;
    }

    Set<String> sectionDevNames = new Set<String>();
    for (Application_Section__mdt section : filteredSections) {
      sectionDevNames.add(section.DeveloperName);
    }

    // Defensive: an empty scope match means no questions to fetch — short-circuit
    // the SOQL rather than issuing an unbounded IN () query.
    List<Application_Question__mdt> filteredQuestions = new List<Application_Question__mdt>();
    if (!sectionDevNames.isEmpty()) {
      List<Application_Question__mdt> questionRecords = queryQuestions(sectionDevNames);
      filteredQuestions = filterQuestionsByVariant(questionRecords, variant);
    }

    return buildFormStructure(page, filteredSections, filteredQuestions);
  }

  /**
   * Clears the Platform Cache entry for a given (pageDevName, variant) pair.
   * Intended for tests and admin-driven invalidation after deploying new CMDT.
   * Silent no-op if the partition is unavailable.
   */
  @TestVisible
  public static void clearFormStructureCache(String pageDevName, String variant) {
    try {
      Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION_NAME);
      if (partition != null) {
        partition.remove(buildCacheKey(pageDevName, variant));
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.WARN, 'ApplicationCache clear failed: ' + e.getMessage());
    }
  }

  @TestVisible
  private static void resetCacheCounters() {
    cacheHitCount = 0;
    cacheMissCount = 0;
  }

  /**
   * Evaluates visibility criteria against current answers (including unsaved changes).
   * Returns a map of section/question DeveloperName to visibility (true = visible).
   *
   * @param recordId The Id of the record
   * @param pageDevName The DeveloperName of the Application_Page__mdt record
   * @param variant Optional variant filter
   * @param answersJson JSON map of question DeveloperName to current answer value
   * @return Map of DeveloperName to Boolean visibility
   */
  @AuraEnabled
  public static Map<String, Boolean> evaluateVisibility(
    Id recordId,
    String pageDevName,
    String variant,
    String answersJson
  ) {
    Preconditions.checkNotBlank(pageDevName, 'Page developer name is required');

    Map<String, Boolean> visibilityMap = new Map<String, Boolean>();

    List<Application_Section__mdt> sectionRecords = querySections(pageDevName);
    Set<String> sectionDevNames = new Set<String>();
    List<Application_Section__mdt> filteredSections = new List<Application_Section__mdt>();
    for (Application_Section__mdt section : sectionRecords) {
      if (matchesVariant(section.Variant__c, variant)) {
        filteredSections.add(section);
        sectionDevNames.add(section.DeveloperName);
      }
    }

    List<Application_Question__mdt> questionRecords = queryQuestions(sectionDevNames);
    List<Application_Question__mdt> filteredQuestions = new List<Application_Question__mdt>();
    for (Application_Question__mdt question : questionRecords) {
      if (matchesVariant(question.Variant__c, variant)) {
        filteredQuestions.add(question);
      }
    }

    // Build in-memory SObject with answer overrides
    SObject record = buildRecordFromAnswers(recordId, filteredQuestions, answersJson);

    // Evaluate each section's visibility
    for (Application_Section__mdt section : filteredSections) {
      visibilityMap.put(
        section.DeveloperName,
        evaluateCriteria(section.Visibility_Criteria__r, record)
      );
    }

    // Evaluate each question's visibility
    for (Application_Question__mdt question : filteredQuestions) {
      visibilityMap.put(
        question.DeveloperName,
        evaluateCriteria(question.Visibility_Criteria__r, record)
      );
    }

    return visibilityMap;
  }

  /**
   * Returns existing field values for a record, keyed by question DeveloperName.
   * Uses WITH USER_MODE to respect FLS and sharing rules.
   *
   * @param recordId The Id of the record to query
   * @param pageDevName The DeveloperName of the Application_Page__mdt record
   * @return Map of question DeveloperName to current field value
   */
  @AuraEnabled
  public static Map<String, Object> getExistingAnswers(Id recordId, String pageDevName) {
    if (recordId == null) {
      return new Map<String, Object>();
    }
    Preconditions.checkNotBlank(pageDevName, 'Page developer name is required');

    List<Application_Section__mdt> sectionRecords = querySections(pageDevName);
    Set<String> sectionDevNames = new Set<String>();
    for (Application_Section__mdt section : sectionRecords) {
      sectionDevNames.add(section.DeveloperName);
    }

    if (sectionDevNames.isEmpty()) {
      return new Map<String, Object>();
    }

    List<Application_Question__mdt> questions = queryQuestions(sectionDevNames);
    return loadExistingAnswers(recordId, questions);
  }

  /**
   * Loads existing field values from a pre-assembled (potentially cached) form structure.
   * Reads targetObject/targetField from each AppQuestionInput DTO instead of re-resolving
   * via CMDT — this is what lets us reuse the cached structure without re-querying
   * Application_Question__mdt + EntityParticle.
   */
  private static Map<String, Object> loadExistingAnswersFromStructure(
    Id recordId,
    AppQuestionFormStructure structure
  ) {
    Map<String, Object> result = new Map<String, Object>();
    if (recordId == null || structure == null || structure.sections == null) {
      return result;
    }

    Map<String, String> fieldToQuestion = new Map<String, String>();
    Set<String> fieldApiNameSet = new Set<String>();
    String sobjectApiName = null;

    for (AppQuestionSection section : structure.sections) {
      if (section.questions == null) {
        continue;
      }
      for (AppQuestionInput input : section.questions) {
        // Compound inputs (e.g., Address) have no target field — skip.
        if (String.isBlank(input.targetField) || String.isBlank(input.targetObject)) {
          continue;
        }
        if (sobjectApiName == null) {
          sobjectApiName = input.targetObject;
        }
        fieldApiNameSet.add(input.targetField);
        fieldToQuestion.put(input.targetField, input.developerName);
      }
    }

    if (sobjectApiName == null || fieldApiNameSet.isEmpty()) {
      return result;
    }

    List<String> fieldApiNames = new List<String>(fieldApiNameSet);
    String query =
      'SELECT ' +
      String.join(fieldApiNames, ', ') +
      ' FROM ' +
      sobjectApiName +
      ' WHERE Id = :recordId LIMIT 1';

    List<SObject> records = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.SYSTEM_MODE
    );
    if (records.isEmpty()) {
      return result;
    }

    SObject record = records[0];
    for (String fieldName : fieldToQuestion.keySet()) {
      Object value = record.get(fieldName);
      if (value != null) {
        result.put(fieldToQuestion.get(fieldName), value);
      }
    }
    return result;
  }

  /**
   * Loads existing field values for the given questions, keyed by question DeveloperName.
   * Returns an empty map for a null recordId. Extracted so the bundle accessor can reuse
   * the previously-queried question metadata instead of re-querying CMDT.
   */
  private static Map<String, Object> loadExistingAnswers(
    Id recordId,
    List<Application_Question__mdt> questions
  ) {
    Map<String, Object> result = new Map<String, Object>();
    if (recordId == null || questions == null || questions.isEmpty()) {
      return result;
    }

    Map<String, String> fieldToQuestion = new Map<String, String>();
    Set<String> fieldApiNameSet = new Set<String>();
    SObjectType sobjectType = null;

    for (Application_Question__mdt q : questions) {
      // Compound inputs (e.g., Address) have no Target_Field mapping; they are
      // loaded by getAddressQuestionValues via Field_Bindings__c JSON instead
      // of being included in the single-row query below.
      if (q.Target_Field__r == null) {
        continue;
      }
      SObjectType qType = SObjectFieldCmdtParser.getSObjectType(q.Target_Field__r);
      if (sobjectType == null) {
        sobjectType = qType;
      }
      SObjectField field = SObjectFieldCmdtParser.getSObjectField(q.Target_Field__r);
      String fieldName = field.getDescribe().getName();
      fieldApiNameSet.add(fieldName);
      fieldToQuestion.put(fieldName, q.DeveloperName);
    }

    if (sobjectType == null || fieldApiNameSet.isEmpty()) {
      return result;
    }

    List<String> fieldApiNames = new List<String>(fieldApiNameSet);
    String query =
      'SELECT ' +
      String.join(fieldApiNames, ', ') +
      ' FROM ' +
      sobjectType.getDescribe().getName() +
      ' WHERE Id = :recordId LIMIT 1';

    List<SObject> records = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.SYSTEM_MODE
    );

    if (records.isEmpty()) {
      return result;
    }

    SObject record = records[0];
    for (String fieldName : fieldToQuestion.keySet()) {
      Object value = record.get(fieldName);
      if (value != null) {
        result.put(fieldToQuestion.get(fieldName), value);
      }
    }
    return result;
  }

  /**
   * Returns the running user's contact info as Guardian_1_* defaults.
   * Mirrors {@code SiblingSectionController.getGuardianDefaults} so the bundle accessor
   * does not introduce a cross-class dependency at the LWC layer.
   */
  private static Map<String, String> loadGuardianDefaults() {
    Map<String, String> defaults = new Map<String, String>();
    Id userId = UserInfo.getUserId();

    String userQuery = 'SELECT ContactId FROM User WHERE Id = :userId LIMIT 1';
    List<User> users = Database.queryWithBinds(
      userQuery,
      new Map<String, Object>{ 'userId' => userId },
      AccessLevel.SYSTEM_MODE
    );
    if (users.isEmpty() || users[0].ContactId == null) {
      return defaults;
    }

    Id contactId = users[0].ContactId;
    String contactQuery =
      'SELECT FirstName, LastName, Email, MobilePhone,' +
      ' Account.Self_Reported_Zeta_Employee__c' +
      ' FROM Contact WHERE Id = :contactId LIMIT 1';
    List<Contact> contacts = Database.queryWithBinds(
      contactQuery,
      new Map<String, Object>{ 'contactId' => contactId },
      AccessLevel.SYSTEM_MODE
    );
    if (contacts.isEmpty()) {
      return defaults;
    }

    Contact c = contacts[0];
    Boolean isZetaEmployee = c.Account != null && c.Account.Self_Reported_Zeta_Employee__c == true;
    return buildGuardianDefaults(c, isZetaEmployee);
  }

  /**
   * Pure helper: build the Guardian_1_* defaults map from a Contact's name/contact
   * details. Extracted so it can be exercised directly in test contexts where the
   * running user has no associated Contact.
   */
  @TestVisible
  private static Map<String, String> buildGuardianDefaults(Contact c) {
    return buildGuardianDefaults(c, false);
  }

  /**
   * Pure helper: build the Guardian_1_* defaults map, optionally pre-checking the
   * Zeta-employee indicator when the running guardian's parent record is flagged
   * as a self-reported Zeta employee. Kept pure so it can be unit-tested without
   * Person-Account DML — pass the resolved boolean in rather than reading the
   * cross-object field inside the helper.
   */
  @TestVisible
  private static Map<String, String> buildGuardianDefaults(Contact c, Boolean isZetaEmployee) {
    Map<String, String> defaults = new Map<String, String>();
    if (c == null) {
      return defaults;
    }
    if (String.isNotBlank(c.FirstName)) {
      defaults.put('Guardian_1_First_Name', c.FirstName);
    }
    if (String.isNotBlank(c.LastName)) {
      defaults.put('Guardian_1_Last_Name', c.LastName);
    }
    if (String.isNotBlank(c.Email)) {
      defaults.put('Guardian_1_Email', c.Email);
    }
    if (String.isNotBlank(c.MobilePhone)) {
      defaults.put('Guardian_1_Phone', c.MobilePhone);
    }
    if (isZetaEmployee == true) {
      // Pre-check the "is a parent a Zeta employee?" indicator and default the
      // picker to Primary (the running applicant is Guardian 1). The LWC coerces
      // the string 'true' to a real boolean for the checkbox answer; a saved
      // answer on the application still overrides this default.
      defaults.put('Employee_Priority', 'true');
      defaults.put('Employee_Priority_Guardian', 'Primary');
    }
    return defaults;
  }

  /**
   * Returns submission-time warning flags from the IndividualApplication record.
   * Mirrors {@code ZetaApplicationController.getSubmissionWarnings} so the bundle
   * accessor does not introduce a cross-class dependency at the LWC layer.
   */
  private static Map<String, Boolean> loadSubmissionWarnings(Id recordId) {
    Map<String, Boolean> result = new Map<String, Boolean>();
    result.put('hasAgeWarning', false);
    result.put('hasResidencyWarning', false);
    // Pre-K applicants only need NYC residency; everyone else needs NY State.
    result.put('residencyRequiresCityOnly', false);

    if (recordId == null) {
      return result;
    }

    String query =
      'SELECT Age_Inconsistency_Flag_c__c, Outside_of_NY__c,' +
      ' Grade_Applying_To__c, Account.PersonMailingState' +
      ' FROM IndividualApplication WHERE Id = :recordId LIMIT 1';
    List<IndividualApplication> apps = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.SYSTEM_MODE
    );
    if (apps.isEmpty()) {
      return result;
    }

    IndividualApplication app = apps[0];
    result.put('hasAgeWarning', app.Age_Inconsistency_Flag_c__c == true);
    // Only surface the residency warning once the student actually has a state.
    // Outside_of_NY__c is BlankAsZero, so a blank MailingState evaluates as
    // "outside NY" and would otherwise flash the warning before any address has
    // been entered. Gating here (rather than changing the shared formula, which
    // the eligibility/priority flows also consume) keeps the fix scoped to the UI.
    Boolean studentHasState =
      app.Account != null && String.isNotBlank(app.Account.PersonMailingState);
    result.put('hasResidencyWarning', studentHasState && app.Outside_of_NY__c == true);
    // Pre-K and TK require only NYC residency; K-9 (and up) require NY State
    // residency. Drives which residency message the portal renders.
    // (TK grouped with Pre-K pending client confirmation.)
    result.put(
      'residencyRequiresCityOnly',
      app.Grade_Applying_To__c == 'PK' || app.Grade_Applying_To__c == 'TK'
    );
    return result;
  }

  /**
   * Builds the AppQuestionFormStructure DTO from already-filtered CMDT records.
   * Centralized so getFormStructure and getApplicationFormBundle share assembly logic.
   */
  private static AppQuestionFormStructure buildFormStructure(
    AppQuestionPage page,
    List<Application_Section__mdt> filteredSections,
    List<Application_Question__mdt> filteredQuestions
  ) {
    Map<String, List<AppQuestionInput>> questionsBySection = buildQuestionsBySection(
      filteredQuestions
    );
    List<AppQuestionSection> sections = buildSections(filteredSections, questionsBySection);

    AppQuestionFormStructure result = new AppQuestionFormStructure();
    result.page = page;
    result.sections = sections;
    result.controllingQuestionDevNames = buildControllingQuestionDevNames(
      filteredSections,
      filteredQuestions
    );
    return result;
  }

  private static List<Application_Section__mdt> filterSectionsByVariant(
    List<Application_Section__mdt> sections,
    String variant
  ) {
    List<Application_Section__mdt> filtered = new List<Application_Section__mdt>();
    for (Application_Section__mdt section : sections) {
      if (matchesVariant(section.Variant__c, variant)) {
        filtered.add(section);
      }
    }
    return filtered;
  }

  private static List<Application_Question__mdt> filterQuestionsByVariant(
    List<Application_Question__mdt> questions,
    String variant
  ) {
    List<Application_Question__mdt> filtered = new List<Application_Question__mdt>();
    for (Application_Question__mdt question : questions) {
      if (matchesVariant(question.Variant__c, variant)) {
        filtered.add(question);
      }
    }
    return filtered;
  }

  /**
   * Saves form answers by mapping them to SObject fields via CMDT configuration.
   * Applies explicit type coercion based on DescribeFieldResult.getType().
   *
   * @param applicationId The Id of the record to update
   * @param answersJson JSON string of question developer name to answer value mappings
   */
  @AuraEnabled
  public static void saveFormAnswers(Id applicationId, String answersJson) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(answersJson, 'Answers JSON is required');

    Map<String, Object> answers = (Map<String, Object>) JSON.deserializeUntyped(answersJson);
    if (answers.isEmpty()) {
      return;
    }

    Set<String> questionDevNames = answers.keySet();
    List<Application_Question__mdt> questions = querySaveQuestions(questionDevNames);

    List<String> missing = new List<String>();
    for (Application_Question__mdt question : questions) {
      if (question.Is_Required__c != true) {
        continue;
      }
      Object answerValue = answers.get(question.DeveloperName);
      if (
        answerValue == null ||
        (answerValue instanceof String && String.isBlank((String) answerValue))
      ) {
        String labelKey = String.isNotBlank(question.Validation_Message__c)
          ? question.Validation_Message__c
          : String.isNotBlank(question.Display_Label__c)
              ? question.Display_Label__c
              : question.DeveloperName;
        missing.add(LabelResolver.resolve(labelKey));
      }
    }
    Preconditions.checkArgument(missing.isEmpty(), 'Required: ' + String.join(missing, '; '));

    SObject record = applicationId.getSobjectType().newSObject(applicationId);
    Boolean hasFieldToWrite = false;
    for (Application_Question__mdt question : questions) {
      // Compound inputs (e.g., Address) intentionally have no Target_Field —
      // they're persisted via saveAddressQuestion(...) which writes to
      // potentially different SObjects. Skip them in this generic writer.
      if (question.Target_Field__r == null) {
        continue;
      }
      SObjectField targetField = SObjectFieldCmdtParser.getSObjectField(question.Target_Field__r);
      Object answerValue = answers.get(question.DeveloperName);
      record.put(targetField, coerceValue(targetField, answerValue));
      hasFieldToWrite = true;
    }

    if (hasFieldToWrite) {
      new SystemModeDatabaseRepo().updateSObjects(new List<SObject>{ record });
    }
  }

  /**
   * Saves an Address-type question's payload to the SObject(s) named by the question's
   * `Field_Bindings__c` JSON. Each binding maps a `lightning-input-address` slot name
   * (street, city, province, postalCode, country, subpremise) to a field path on a
   * resolved SObject. Three target objects are supported:
   *
   * - `Account`: writes to the Person Account identified by the application's
   *   `AccountId` (i.e., the student) when the path begins with `Student.` —
   *   convenience alias so the same question can be used across applications.
   * - `Primary_Guardian__r.*`: writes to the Person Account named by
   *   `IndividualApplication.Primary_Guardian__c` (Guardian 1).
   * - Anything else: writes to the IndividualApplication record itself
   *   (e.g., `Parent_Guardian_2_Street__c`).
   *
   * @param applicationId The Id of the IndividualApplication record providing context
   * @param questionDeveloperName The DeveloperName of the Address-type Application_Question__mdt
   * @param payloadJson JSON object keyed by slot name (street/city/province/postalCode/country/subpremise)
   */
  @AuraEnabled
  public static void saveAddressQuestion(
    Id applicationId,
    String questionDeveloperName,
    String payloadJson
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(questionDeveloperName, 'Question developer name is required');
    Preconditions.checkNotBlank(payloadJson, 'Payload JSON is required');

    Application_Question__mdt question = queryAddressQuestion(questionDeveloperName);
    Map<String, String> bindings = parseFieldBindings(question.Field_Bindings__c);
    if (bindings == null || bindings.isEmpty()) {
      return;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);

    // Group bindings by target object so we can do one DML per object.
    // We also track, per target, the field names bound to the street and
    // subpremise slots so we can concat "<street>\nApt <apt>" into the
    // street field while leaving the standalone apartment column populated
    // (lossless round-trip).
    Map<String, Map<String, Object>> writesByTarget = new Map<String, Map<String, Object>>();
    Map<String, String> streetFieldByTarget = new Map<String, String>();
    Map<String, String> subpremiseFieldByTarget = new Map<String, String>();
    for (String slot : bindings.keySet()) {
      String path = bindings.get(slot);
      if (String.isBlank(path) || !payload.containsKey(slot)) {
        continue;
      }
      AddressBinding binding = parseAddressBinding(path);
      Map<String, Object> fields = writesByTarget.get(binding.targetKey);
      if (fields == null) {
        fields = new Map<String, Object>{ '__target' => binding.targetKey };
        writesByTarget.put(binding.targetKey, fields);
      }
      fields.put(binding.fieldName, payload.get(slot));
      if ('street'.equals(slot)) {
        streetFieldByTarget.put(binding.targetKey, binding.fieldName);
      } else if ('subpremise'.equals(slot)) {
        subpremiseFieldByTarget.put(binding.targetKey, binding.fieldName);
      }
    }

    if (writesByTarget.isEmpty()) {
      return;
    }

    // For any target that received BOTH a street and a subpremise binding,
    // merge them into the street field as "<street>\nApt <apt>". Keep the
    // standalone apartment column populated alongside.
    for (String targetKey : writesByTarget.keySet()) {
      String streetField = streetFieldByTarget.get(targetKey);
      String subField = subpremiseFieldByTarget.get(targetKey);
      if (String.isBlank(streetField) || String.isBlank(subField)) {
        continue;
      }
      Map<String, Object> fields = writesByTarget.get(targetKey);
      Object rawStreet = fields.get(streetField);
      Object rawSub = fields.get(subField);
      String mergedStreet = mergeStreetAndApartment(rawStreet, rawSub);
      if (mergedStreet == null) {
        fields.remove(streetField);
      } else {
        fields.put(streetField, mergedStreet);
      }
    }

    // Resolve target Ids per group (one query for the application up front).
    Id studentAccountId;
    Id guardian1AccountId;
    Id guardian2AccountId;
    Boolean needsApplicationLookups =
      writesByTarget.containsKey(ADDRESS_TARGET_STUDENT) ||
      writesByTarget.containsKey(ADDRESS_TARGET_GUARDIAN_1) ||
      writesByTarget.containsKey(ADDRESS_TARGET_GUARDIAN_2);
    if (needsApplicationLookups) {
      List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        'SELECT AccountId, Primary_Guardian__c, Secondary_Guardian__c' +
        ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
        new Map<String, Object>{ 'applicationId' => applicationId }
      );
      Preconditions.checkArgument(
        !apps.isEmpty(),
        'IndividualApplication not found: ' + applicationId
      );
      studentAccountId = apps[0].AccountId;
      guardian1AccountId = apps[0].Primary_Guardian__c;
      guardian2AccountId = apps[0].Secondary_Guardian__c;
    }

    // Fallback: the Secondary Guardian Account isn't created/linked yet — the
    // guardian-upsert flow stamps Secondary_Guardian__c asynchronously after
    // the first save that introduces Guardian 2 data. Re-target the address
    // write to the application's Parent_Guardian_2_* staging fields so that
    // flow copies real values (not blanks) onto the Account when it creates
    // or matches it. Once the lookup is stamped, later saves write to the
    // Account directly and this block never runs.
    if (writesByTarget.containsKey(ADDRESS_TARGET_GUARDIAN_2) && guardian2AccountId == null) {
      Map<String, Object> guardian2Fields = writesByTarget.remove(ADDRESS_TARGET_GUARDIAN_2);
      Map<String, Object> applicationFields = writesByTarget.get(ADDRESS_TARGET_APPLICATION);
      Boolean stagedAny = false;
      for (String accountField : guardian2Fields.keySet()) {
        String stagingField = GUARDIAN_2_STAGING_FIELD_BY_ACCOUNT_FIELD.get(accountField);
        if (stagingField == null) {
          continue;
        }
        if (applicationFields == null) {
          applicationFields = new Map<String, Object>{ '__target' => ADDRESS_TARGET_APPLICATION };
        }
        applicationFields.put(stagingField, guardian2Fields.get(accountField));
        stagedAny = true;
      }
      if (stagedAny) {
        writesByTarget.put(ADDRESS_TARGET_APPLICATION, applicationFields);
      }
    }

    List<SObject> recordsToUpdate = new List<SObject>();
    for (Map<String, Object> fieldMap : writesByTarget.values()) {
      String targetKey = (String) fieldMap.remove('__target');
      SObject record;
      if (ADDRESS_TARGET_STUDENT.equals(targetKey)) {
        if (studentAccountId == null) {
          continue;
        }
        record = new Account(Id = studentAccountId);
      } else if (ADDRESS_TARGET_GUARDIAN_1.equals(targetKey)) {
        if (guardian1AccountId == null) {
          continue;
        }
        record = new Account(Id = guardian1AccountId);
      } else if (ADDRESS_TARGET_GUARDIAN_2.equals(targetKey)) {
        if (guardian2AccountId == null) {
          continue;
        }
        record = new Account(Id = guardian2AccountId);
      } else {
        record = new IndividualApplication(Id = applicationId);
      }
      for (String fieldName : fieldMap.keySet()) {
        Object value = fieldMap.get(fieldName);
        record.put(fieldName, value == null ? null : String.valueOf(value));
      }
      recordsToUpdate.add(record);
    }

    if (!recordsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(recordsToUpdate);
    }
  }

  /**
   * Returns the current values for an Address-type question by reading the SObjects
   * pointed to by `Field_Bindings__c`. Returned map is keyed by slot name.
   *
   * @param applicationId The Id of the IndividualApplication record
   * @param questionDeveloperName The DeveloperName of the Address-type question
   */
  // NOT cacheable: address values change within a wizard session (the Guardian 1
  // address entered on step 1 must be reflected on step 4). With cacheable=true,
  // LDS serves a stale snapshot across questionAddress component instances —
  // saveAddressQuestion writes the records but does not invalidate the cache, so
  // the step-4 read returned the pre-edit value.
  @AuraEnabled
  public static Map<String, String> getAddressQuestionValues(
    Id applicationId,
    String questionDeveloperName
  ) {
    Map<String, String> result = new Map<String, String>();
    if (applicationId == null || String.isBlank(questionDeveloperName)) {
      return result;
    }

    Application_Question__mdt question;
    try {
      question = queryAddressQuestion(questionDeveloperName);
    } catch (Exception e) {
      return result;
    }
    Map<String, String> bindings = parseFieldBindings(question.Field_Bindings__c);
    if (bindings == null || bindings.isEmpty()) {
      return result;
    }

    Boolean needsStudent = false;
    Boolean needsGuardian1 = false;
    Boolean needsGuardian2 = false;
    Boolean needsApplication = false;
    Map<String, AddressBinding> resolvedBindings = new Map<String, AddressBinding>();
    for (String slot : bindings.keySet()) {
      String path = bindings.get(slot);
      if (String.isBlank(path)) {
        continue;
      }
      AddressBinding binding = parseAddressBinding(path);
      resolvedBindings.put(slot, binding);
      if (ADDRESS_TARGET_STUDENT.equals(binding.targetKey)) {
        needsStudent = true;
      } else if (ADDRESS_TARGET_GUARDIAN_1.equals(binding.targetKey)) {
        needsGuardian1 = true;
      } else if (ADDRESS_TARGET_GUARDIAN_2.equals(binding.targetKey)) {
        needsGuardian2 = true;
      } else {
        needsApplication = true;
      }
    }

    Id studentAccountId;
    Id guardian1AccountId;
    Id guardian2AccountId;
    IndividualApplication app;
    if (needsStudent || needsGuardian1 || needsGuardian2 || needsApplication) {
      List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        'SELECT Id, AccountId, Primary_Guardian__c, Secondary_Guardian__c,' +
          ' Parent_Guardian_2_Street__c, Parent_Guardian_2_City__c,' +
          ' Parent_Guardian_2_State__c, Parent_Guardian_2_Zip__c,' +
          ' Parent_Guardian_2_Apartment__c' +
          ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
        new Map<String, Object>{ 'applicationId' => applicationId }
      );
      if (apps.isEmpty()) {
        return result;
      }
      app = apps[0];
      studentAccountId = app.AccountId;
      guardian1AccountId = app.Primary_Guardian__c;
      guardian2AccountId = app.Secondary_Guardian__c;
    }

    Account studentAccount;
    if (needsStudent && studentAccountId != null) {
      List<Account> students = (List<Account>) databaseRepo.queryWithBinds(
        'SELECT PersonMailingStreet, PersonMailingCity, PersonMailingState,' +
          ' PersonMailingPostalCode, PersonMailingCountry, Apartment_Number__c' +
          ' FROM Account WHERE Id = :accountId LIMIT 1',
        new Map<String, Object>{ 'accountId' => studentAccountId }
      );
      if (!students.isEmpty()) {
        studentAccount = students[0];
      }
    }

    Account guardian1Account;
    if (needsGuardian1 && guardian1AccountId != null) {
      List<Account> guardians = (List<Account>) databaseRepo.queryWithBinds(
        'SELECT PersonMailingStreet, PersonMailingCity, PersonMailingState,' +
          ' PersonMailingPostalCode, PersonMailingCountry, Apartment_Number__c' +
          ' FROM Account WHERE Id = :accountId LIMIT 1',
        new Map<String, Object>{ 'accountId' => guardian1AccountId }
      );
      if (!guardians.isEmpty()) {
        guardian1Account = guardians[0];
      }
    }

    Account guardian2Account;
    if (needsGuardian2 && guardian2AccountId != null) {
      List<Account> guardians = (List<Account>) databaseRepo.queryWithBinds(
        'SELECT PersonMailingStreet, PersonMailingCity, PersonMailingState,' +
          ' PersonMailingPostalCode, PersonMailingCountry, Apartment_Number__c' +
          ' FROM Account WHERE Id = :accountId LIMIT 1',
        new Map<String, Object>{ 'accountId' => guardian2AccountId }
      );
      if (!guardians.isEmpty()) {
        guardian2Account = guardians[0];
      }
    }

    for (String slot : resolvedBindings.keySet()) {
      AddressBinding binding = resolvedBindings.get(slot);
      SObject source;
      String fieldToRead = binding.fieldName;
      if (ADDRESS_TARGET_STUDENT.equals(binding.targetKey)) {
        source = studentAccount;
      } else if (ADDRESS_TARGET_GUARDIAN_1.equals(binding.targetKey)) {
        source = guardian1Account;
      } else if (ADDRESS_TARGET_GUARDIAN_2.equals(binding.targetKey)) {
        if (guardian2Account != null) {
          source = guardian2Account;
        } else {
          // Fallback read: while Secondary_Guardian__c isn't stamped, the most
          // recently saved Guardian 2 address (if any) lives on the
          // application's Parent_Guardian_2_* staging fields. Mirror the
          // save-side fallback so the form round-trips what the user entered.
          source = app;
          fieldToRead = GUARDIAN_2_STAGING_FIELD_BY_ACCOUNT_FIELD.get(binding.fieldName);
          if (fieldToRead == null) {
            continue;
          }
        }
      } else {
        source = app;
      }
      if (source == null) {
        continue;
      }
      Object value;
      try {
        value = source.get(fieldToRead);
      } catch (Exception e) {
        continue;
      }
      if (value != null) {
        result.put(slot, String.valueOf(value));
      }
    }

    // The street field is stored as "<street>\nApt <apt>" so it renders nicely
    // in Salesforce's native multi-line Street display, but the lightning-input-address
    // street slot should receive only the literal street — the apartment input
    // picks up the standalone Apartment_Number__c / Parent_Guardian_2_Apartment__c
    // column. Strip the suffix here so the LWC re-renders cleanly without parsing
    // the street.
    if (result.containsKey('street')) {
      String stripped = stripApartmentSuffix(result.get('street'));
      if (String.isBlank(stripped)) {
        result.remove('street');
      } else {
        result.put('street', stripped);
      }
    }
    return result;
  }

  /**
   * Writes an address payload to the SObject(s) named by the companion question's
   * `Field_Bindings__c`. The companion question is looked up by DeveloperName and
   * resolves its bindings through the same prefix aliases as `saveAddressQuestion`
   * (`Student.` → student Person Account, `Primary_Guardian__r.` → Guardian 1
   * Person Account, anything else → IndividualApplication). This is the
   * framework-driven replacement for `applyGuardianOneWriteback` and contains no
   * hard-coded field references.
   *
   * Typical use: the Address question's LWC handler, when a controlling checkbox
   * (e.g. "Lives with Guardian 1") is true, passes the same payload it just saved
   * plus the companion question's DeveloperName so the bindings on that companion
   * receive the same values.
   *
   * @param applicationId The Id of the IndividualApplication providing context
   * @param payloadJson JSON object keyed by slot (street/city/province/postalCode/country/subpremise)
   * @param companionQuestionDevName DeveloperName of the companion Application_Question__mdt
   */
  @AuraEnabled
  public static void applyCompanionWriteback(
    Id applicationId,
    String payloadJson,
    String companionQuestionDevName
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(payloadJson, 'Payload JSON is required');
    Preconditions.checkNotBlank(
      companionQuestionDevName,
      'Companion question developer name is required'
    );

    // Delegate to saveAddressQuestion against the companion's developer name,
    // which already resolves bindings and groups writes by target SObject.
    saveAddressQuestion(applicationId, companionQuestionDevName, payloadJson);
  }

  /**
   * Nulls every field bound by an Address-type question. Counterpart to
   * `saveAddressQuestion` — `saveAddressQuestion` early-outs when no payload
   * slot matches a binding, so it cannot be used to clear. This method
   * iterates the bindings directly and writes null to each bound field.
   *
   * @param applicationId The Id of the IndividualApplication providing context
   * @param questionDeveloperName DeveloperName of the Address-type question whose bindings should be nulled
   */
  @AuraEnabled
  public static void clearAddressQuestion(Id applicationId, String questionDeveloperName) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(questionDeveloperName, 'Question developer name is required');

    Application_Question__mdt question = queryAddressQuestion(questionDeveloperName);
    Map<String, String> bindings = parseFieldBindings(question.Field_Bindings__c);
    if (bindings == null || bindings.isEmpty()) {
      return;
    }

    // Group bound field names by target SObject. Unlike saveAddressQuestion,
    // we don't deserialize a payload — every bound field is written null.
    Map<String, Set<String>> fieldsByTarget = new Map<String, Set<String>>();
    for (String slot : bindings.keySet()) {
      String path = bindings.get(slot);
      if (String.isBlank(path)) {
        continue;
      }
      AddressBinding binding = parseAddressBinding(path);
      Set<String> fields = fieldsByTarget.get(binding.targetKey);
      if (fields == null) {
        fields = new Set<String>();
        fieldsByTarget.put(binding.targetKey, fields);
      }
      fields.add(binding.fieldName);
    }
    if (fieldsByTarget.isEmpty()) {
      return;
    }

    Id studentAccountId;
    Id guardian1AccountId;
    Id guardian2AccountId;
    Boolean needsApplicationLookups =
      fieldsByTarget.containsKey(ADDRESS_TARGET_STUDENT) ||
      fieldsByTarget.containsKey(ADDRESS_TARGET_GUARDIAN_1) ||
      fieldsByTarget.containsKey(ADDRESS_TARGET_GUARDIAN_2);
    if (needsApplicationLookups) {
      List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
        'SELECT AccountId, Primary_Guardian__c, Secondary_Guardian__c' +
        ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
        new Map<String, Object>{ 'applicationId' => applicationId }
      );
      Preconditions.checkArgument(
        !apps.isEmpty(),
        'IndividualApplication not found: ' + applicationId
      );
      studentAccountId = apps[0].AccountId;
      guardian1AccountId = apps[0].Primary_Guardian__c;
      guardian2AccountId = apps[0].Secondary_Guardian__c;
    }

    List<SObject> recordsToUpdate = new List<SObject>();
    for (String targetKey : fieldsByTarget.keySet()) {
      SObject record;
      if (ADDRESS_TARGET_STUDENT.equals(targetKey)) {
        if (studentAccountId == null) {
          continue;
        }
        record = new Account(Id = studentAccountId);
      } else if (ADDRESS_TARGET_GUARDIAN_1.equals(targetKey)) {
        if (guardian1AccountId == null) {
          continue;
        }
        record = new Account(Id = guardian1AccountId);
      } else if (ADDRESS_TARGET_GUARDIAN_2.equals(targetKey)) {
        if (guardian2AccountId == null) {
          continue;
        }
        record = new Account(Id = guardian2AccountId);
      } else {
        record = new IndividualApplication(Id = applicationId);
      }
      for (String fieldName : fieldsByTarget.get(targetKey)) {
        record.put(fieldName, null);
      }
      recordsToUpdate.add(record);
    }

    if (!recordsToUpdate.isEmpty()) {
      databaseRepo.updateSObjects(recordsToUpdate);
    }
  }

  /**
   * Reads the current address values via the source question's `Field_Bindings__c`
   * and writes them via the target question's bindings. Framework-driven replacement
   * for `applyGuardianTwoSameAsPrimary`; the prefix alias support (`Student.`,
   * `Primary_Guardian__r.`, IndividualApplication-default) handles all current
   * target objects without hard-coding field names.
   *
   * @param applicationId The Id of the IndividualApplication providing context
   * @param sourceQuestionDevName DeveloperName of the question whose bindings supply values
   * @param targetQuestionDevName DeveloperName of the question whose bindings receive values
   */
  @AuraEnabled
  public static void applyCompanionCopyFrom(
    Id applicationId,
    String sourceQuestionDevName,
    String targetQuestionDevName
  ) {
    Preconditions.checkNotNull(applicationId, 'Application Id is required');
    Preconditions.checkNotBlank(
      sourceQuestionDevName,
      'Source question developer name is required'
    );
    Preconditions.checkNotBlank(
      targetQuestionDevName,
      'Target question developer name is required'
    );

    Map<String, String> sourceValues = getAddressQuestionValues(
      applicationId,
      sourceQuestionDevName
    );
    if (sourceValues == null || sourceValues.isEmpty()) {
      return;
    }
    saveAddressQuestion(applicationId, targetQuestionDevName, JSON.serialize(sourceValues));
  }

  /**
   * Looks up an Application_Question__mdt by DeveloperName for the address
   * read/write paths. We deliberately do NOT filter by Is_Active__c here:
   * companion questions (used only for their Field_Bindings__c) are kept as
   * inactive CMDT records so the form-structure query excludes them from
   * rendering, but address read/write/copy operations must still resolve them.
   */
  private static Application_Question__mdt queryAddressQuestion(String developerName) {
    List<Application_Question__mdt> questions = [
      SELECT DeveloperName, Input_Type__c, Field_Bindings__c
      FROM Application_Question__mdt
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    Preconditions.checkArgument(
      !questions.isEmpty(),
      'Application Question not found: ' + developerName
    );
    return questions[0];
  }

  private static Map<String, String> parseFieldBindings(String bindingsJson) {
    if (String.isBlank(bindingsJson)) {
      return null;
    }
    try {
      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(bindingsJson);
      Map<String, String> result = new Map<String, String>();
      for (String slot : raw.keySet()) {
        Object value = raw.get(slot);
        result.put(slot, value == null ? null : String.valueOf(value));
      }
      return result;
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private static final String ADDRESS_TARGET_STUDENT = 'Student';
  @TestVisible
  private static final String ADDRESS_TARGET_GUARDIAN_1 = 'Guardian1';
  @TestVisible
  private static final String ADDRESS_TARGET_GUARDIAN_2 = 'Guardian2';
  @TestVisible
  private static final String ADDRESS_TARGET_APPLICATION = 'Application';

  /**
   * Maps Secondary Guardian Account address fields to the application's
   * `Parent_Guardian_2_*` staging fields. Used as a write/read fallback while
   * `Secondary_Guardian__c` is not yet stamped: the admin-team-owned
   * guardian-upsert flow creates (or matches) the Guardian 2 Person Account
   * asynchronously after the first save that introduces Guardian 2 data, and
   * copies these staging fields onto that Account. Once the lookup is
   * stamped, reads/writes go to the Account directly and the staging fields
   * are no longer consulted by this class.
   *
   * `PersonMailingCountry` has no staging equivalent (and the flow doesn't
   * copy country either) — country lands on the Account via the direct write
   * on any save made after the lookup is stamped.
   */
  private static final Map<String, String> GUARDIAN_2_STAGING_FIELD_BY_ACCOUNT_FIELD = new Map<String, String>{
    'PersonMailingStreet' => 'Parent_Guardian_2_Street__c',
    'PersonMailingCity' => 'Parent_Guardian_2_City__c',
    'PersonMailingState' => 'Parent_Guardian_2_State__c',
    'PersonMailingPostalCode' => 'Parent_Guardian_2_Zip__c',
    'Apartment_Number__c' => 'Parent_Guardian_2_Apartment__c'
  };

  /**
   * Lightweight DTO that classifies a `Field_Bindings__c` path into a target SObject
   * group ("Student", "Guardian1", or "Application") and the field API name to write.
   * Apex inner classes can't expose static members, so the parse function lives on
   * the outer class as {@link #parseAddressBinding(String)}.
   */
  @TestVisible
  private class AddressBinding {
    public String targetKey;
    public String fieldName;
  }

  /**
   * Merges a street and an apartment value into a single string suitable for
   * writing back to a Street field (Salesforce's native multi-line Street
   * display + the lightning-input-address convention). The standalone
   * apartment column stays populated separately so we can round-trip
   * losslessly.
   *
   * Rules:
   *   - both present  -> "<street>\nApt <apt>"
   *   - street only   -> "<street>"
   *   - apt only      -> "Apt <apt>"
   *   - both blank    -> null (caller should treat as "do not write")
   *
   * Idempotent: if the incoming street already contains a "\nApt " suffix
   * matching the apt value, do not double-concat.
   */
  @TestVisible
  private static String mergeStreetAndApartment(Object streetValue, Object apartmentValue) {
    String street = streetValue == null ? '' : String.valueOf(streetValue);
    String apt = apartmentValue == null ? '' : String.valueOf(apartmentValue);
    // Trim whitespace from the street (lightning-input-address may emit
    // leading/trailing whitespace) but keep any internal newlines we will
    // strip out below.
    String trimmedStreet = street == null ? '' : street.trim();
    String trimmedApt = apt == null ? '' : apt.trim();

    // Idempotency: if the street already ends with a "\nApt ..." suffix,
    // strip it before deciding what to write. That suffix could be left over
    // from a previous save with the same apt, or could be stale if the apt
    // value changed.
    String streetOnly = stripApartmentSuffix(trimmedStreet);

    Boolean hasStreet = String.isNotBlank(streetOnly);
    Boolean hasApt = String.isNotBlank(trimmedApt);

    // If the user typed their own "Apt " prefix into the apartment input, do
    // not double-prefix it on the merged street.
    String aptDisplay = hasApt
      ? (trimmedApt.toLowerCase().startsWith('apt ') ? trimmedApt : 'Apt ' + trimmedApt)
      : '';

    if (hasStreet && hasApt) {
      return streetOnly + '\n' + aptDisplay;
    }
    if (hasStreet) {
      return streetOnly;
    }
    if (hasApt) {
      return aptDisplay;
    }
    return null;
  }

  /**
   * Strips a trailing newline-delimited "Apt <value>" segment from a street
   * string so the literal street can be returned to the LWC (or re-merged on
   * save). Case-insensitive on the "Apt " prefix. Returns the input
   * unchanged (trimmed) when no such suffix is present.
   */
  @TestVisible
  private static String stripApartmentSuffix(String street) {
    if (String.isBlank(street)) {
      return street;
    }
    Integer idx = street.indexOf('\n');
    if (idx < 0) {
      return street.trim();
    }
    String trailer = street.substring(idx + 1).trim();
    if (!trailer.toLowerCase().startsWith('apt ')) {
      return street.trim();
    }
    return street.substring(0, idx).trim();
  }

  @TestVisible
  private static AddressBinding parseAddressBinding(String path) {
    AddressBinding b = new AddressBinding();
    String trimmed = path == null ? '' : path.trim();
    if (trimmed.startsWith('Student.')) {
      b.targetKey = ADDRESS_TARGET_STUDENT;
      b.fieldName = trimmed.substringAfter('Student.');
    } else if (trimmed.startsWith('Primary_Guardian__r.')) {
      b.targetKey = ADDRESS_TARGET_GUARDIAN_1;
      b.fieldName = trimmed.substringAfter('Primary_Guardian__r.');
    } else if (trimmed.startsWith('Secondary_Guardian__r.')) {
      b.targetKey = ADDRESS_TARGET_GUARDIAN_2;
      b.fieldName = trimmed.substringAfter('Secondary_Guardian__r.');
    } else if (trimmed.startsWith('IndividualApplication.')) {
      b.targetKey = ADDRESS_TARGET_APPLICATION;
      b.fieldName = trimmed.substringAfter('IndividualApplication.');
    } else {
      b.targetKey = ADDRESS_TARGET_APPLICATION;
      b.fieldName = trimmed;
    }
    return b;
  }

  /**
   * Queries the record with all fields needed for visibility criteria evaluation.
   */
  private static SObject queryRecordForCriteria(
    Id recordId,
    List<Application_Section__mdt> sections,
    List<Application_Question__mdt> questions
  ) {
    Set<String> allFields = new Set<String>{ 'Id' };
    SObjectType sobjectType = recordId.getSobjectType();

    for (Application_Section__mdt section : sections) {
      if (
        section.Visibility_Criteria__r != null &&
        String.isNotBlank(section.Visibility_Criteria__r.Formula_Expression__c)
      ) {
        allFields.addAll(criteriaEvaluator.getReferencedFields(section.Visibility_Criteria__r));
      }
    }

    for (Application_Question__mdt question : questions) {
      if (
        question.Visibility_Criteria__r != null &&
        String.isNotBlank(question.Visibility_Criteria__r.Formula_Expression__c)
      ) {
        allFields.addAll(criteriaEvaluator.getReferencedFields(question.Visibility_Criteria__r));
      }
    }

    // Only Id — no criteria fields needed
    if (allFields.size() <= 1) {
      return null;
    }

    String query =
      'SELECT ' +
      String.join(new List<String>(allFields), ', ') +
      ' FROM ' +
      sobjectType.getDescribe().getName() +
      ' WHERE Id = :recordId LIMIT 1';

    List<SObject> records = Database.queryWithBinds(
      query,
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.SYSTEM_MODE
    );

    return records.isEmpty() ? null : records[0];
  }

  private static List<Application_Section__mdt> filterVisibleSections(
    List<Application_Section__mdt> sections,
    SObject record
  ) {
    List<Application_Section__mdt> visible = new List<Application_Section__mdt>();
    for (Application_Section__mdt section : sections) {
      if (evaluateCriteria(section.Visibility_Criteria__r, record)) {
        visible.add(section);
      }
    }
    return visible;
  }

  private static List<Application_Question__mdt> filterVisibleQuestions(
    List<Application_Question__mdt> questions,
    SObject record
  ) {
    List<Application_Question__mdt> visible = new List<Application_Question__mdt>();
    for (Application_Question__mdt question : questions) {
      if (evaluateCriteria(question.Visibility_Criteria__r, record)) {
        visible.add(question);
      }
    }
    return visible;
  }

  /**
   * Evaluates a single visibility criteria. Returns true (visible) if:
   * - criteria is null (no restriction)
   * - criteria formula is blank (no restriction)
   * - criteria evaluates to true
   */
  @TestVisible
  private static Boolean evaluateCriteria(SObject_Field_Criteria__mdt criteria, SObject record) {
    if (criteria == null || String.isBlank(criteria.Formula_Expression__c)) {
      return true;
    }
    if (record == null) {
      return true;
    }
    try {
      return criteriaEvaluator.evaluate(criteria, record);
    } catch (Exception e) {
      // FormulaEval can fail when the in-memory SObject lacks fields the formula
      // references (e.g. relationship fields populated only when queried). Treat
      // unresolvable criteria as "visible" so the question still renders; the
      // server-side evaluation with a queried record will produce the correct
      // result once the LWC has a recordId.
      return true;
    }
  }

  /**
   * Builds an in-memory SObject from answers, resolving question DeveloperNames
   * to field API names via CMDT.
   */
  private static SObject buildRecordFromAnswers(
    Id recordId,
    List<Application_Question__mdt> questions,
    String answersJson
  ) {
    Map<String, Object> answers = String.isNotBlank(answersJson)
      ? (Map<String, Object>) JSON.deserializeUntyped(answersJson)
      : new Map<String, Object>();

    SObjectType sobjectType = null;
    if (recordId != null) {
      sobjectType = recordId.getSobjectType();
    } else {
      for (Application_Question__mdt q : questions) {
        if (q.Target_Field__r != null) {
          sobjectType = SObjectFieldCmdtParser.getSObjectType(q.Target_Field__r);
          break;
        }
      }
    }

    if (sobjectType == null) {
      return null;
    }

    SObject record = recordId != null ? sobjectType.newSObject(recordId) : sobjectType.newSObject();

    // Map answers (keyed by question DeveloperName) to field API names.
    // Skip compound inputs (no Target_Field) — address-type questions are
    // excluded from in-memory criteria evaluation.
    for (Application_Question__mdt q : questions) {
      if (answers.containsKey(q.DeveloperName) && q.Target_Field__r != null) {
        SObjectType qType = SObjectFieldCmdtParser.getSObjectType(q.Target_Field__r);
        if (qType != sobjectType) {
          // Cross-object answer (e.g. an Account field) — skip; visibility formulas
          // only target the record's own object.
          continue;
        }
        SObjectField targetField = SObjectFieldCmdtParser.getSObjectField(q.Target_Field__r);
        Object value = answers.get(q.DeveloperName);
        record.put(targetField, coerceValue(targetField, value));
      }
    }

    return record;
  }

  @TestVisible
  private static Object coerceValue(SObjectField field, Object value) {
    if (value == null) {
      return null;
    }

    String stringValue = String.valueOf(value);
    if (String.isBlank(stringValue)) {
      return null;
    }
    DisplayType fieldType = field.getDescribe().getType();

    switch on fieldType {
      when BOOLEAN {
        return Boolean.valueOf(stringValue);
      }
      when DOUBLE, INTEGER, CURRENCY, PERCENT {
        return Decimal.valueOf(stringValue);
      }
      when DATE {
        return Date.valueOf(stringValue);
      }
      when DATETIME {
        if (stringValue.contains('T')) {
          return (Datetime) JSON.deserialize('"' + stringValue + '"', Datetime.class);
        }
        return Datetime.valueOf(stringValue);
      }
      when else {
        return value;
      }
    }
  }

  private static AppQuestionPage queryPage(String pageDevName) {
    List<Application_Page__mdt> pages = [
      SELECT
        DeveloperName,
        Display_Label__c,
        Description__c,
        Sort_Order__c,
        Page_Type__c,
        Component_Name__c
      FROM Application_Page__mdt
      WHERE DeveloperName = :pageDevName AND Is_Active__c = TRUE
      LIMIT 1
    ];

    Preconditions.checkArgument(!pages.isEmpty(), 'Page not found: ' + pageDevName);
    AppQuestionPage page = AppQuestionPage.fromCmdt(pages[0]);
    page.label = LabelResolver.resolve(page.label);
    page.description = LabelResolver.resolve(page.description);
    return page;
  }

  private static List<Application_Section__mdt> querySections(String pageDevName) {
    return [
      SELECT
        DeveloperName,
        Display_Label__c,
        Description__c,
        Sort_Order__c,
        Columns__c,
        Variant__c,
        Collapsible__c,
        Auto_Collapse_When_Complete__c,
        Summary_Template__c,
        Visibility_Criteria__r.MasterLabel,
        Visibility_Criteria__r.Formula_Expression__c,
        Visibility_Criteria__r.Entity_Definition__r.QualifiedApiName
      FROM Application_Section__mdt
      WHERE Page__r.DeveloperName = :pageDevName AND Is_Active__c = TRUE
      ORDER BY Sort_Order__c ASC
    ];
  }

  /**
   * Queries questions with full relationship traversals via dynamic SOQL.
   * Includes Target_Field__r -> Entity_Definition/Field_Definition/Entity_Particle
   * and Visibility_Criteria__r for criteria evaluation.
   */
  private static List<Application_Question__mdt> queryQuestions(Set<String> sectionDevNames) {
    List<String> fields = new List<String>{
      'DeveloperName',
      'Display_Label__c',
      'Section__r.DeveloperName',
      'Input_Type__c',
      'Sort_Order__c',
      'Is_Required__c',
      'Help_Text__c',
      'Placeholder__c',
      'Default_Value__c',
      'Max_Length__c',
      'Validation_Message__c',
      'Validation_Pattern__c',
      'Variant__c',
      'Column_Span__c',
      'Invert_Display__c',
      'Field_Bindings__c',
      'Target_Field__r.DeveloperName',
      'Target_Field__r.Entity_Definition__r.QualifiedApiName',
      'Target_Field__r.Field_Definition__r.QualifiedApiName',
      'Target_Field__r.Entity_Particle__r.QualifiedApiName',
      'Companion_Question__c',
      'Visibility_Criteria__r.MasterLabel',
      'Visibility_Criteria__r.Formula_Expression__c',
      'Visibility_Criteria__r.Entity_Definition__r.QualifiedApiName'
    };
    String query = String.join(
      new List<String>{
        'SELECT',
        String.join(fields, ', '),
        'FROM Application_Question__mdt',
        'WHERE Section__r.DeveloperName IN :sectionDevNames AND Is_Active__c = TRUE',
        'ORDER BY Sort_Order__c ASC'
      },
      ' '
    );
    return Database.query(query);
  }

  /**
   * Queries questions for saveFormAnswers with target field relationship traversals.
   */
  private static List<Application_Question__mdt> querySaveQuestions(Set<String> questionDevNames) {
    List<String> fields = new List<String>{
      'DeveloperName',
      'Display_Label__c',
      'Input_Type__c',
      'Field_Bindings__c',
      'Is_Required__c',
      'Validation_Message__c',
      'Validation_Pattern__c',
      'Target_Field__r.Entity_Definition__r.QualifiedApiName',
      'Target_Field__r.Field_Definition__r.QualifiedApiName',
      'Target_Field__r.Entity_Particle__r.QualifiedApiName',
      'Companion_Question__c'
    };
    String query = String.join(
      new List<String>{
        'SELECT',
        String.join(fields, ', '),
        'FROM Application_Question__mdt',
        'WHERE DeveloperName IN :questionDevNames AND Is_Active__c = TRUE'
      },
      ' '
    );
    return Database.query(query);
  }

  private static Map<String, List<AppQuestionInput>> buildQuestionsBySection(
    List<Application_Question__mdt> questionRecords
  ) {
    Map<String, List<AppQuestionInput>> questionsBySection = new Map<String, List<AppQuestionInput>>();

    for (Application_Question__mdt q : questionRecords) {
      String sectionDevName = q.Section__r.DeveloperName;
      if (!questionsBySection.containsKey(sectionDevName)) {
        questionsBySection.put(sectionDevName, new List<AppQuestionInput>());
      }
      AppQuestionInput input = AppQuestionInput.fromCmdt(q);
      input.label = LabelResolver.resolve(input.label);
      input.helpText = LabelResolver.resolve(input.helpText);
      input.placeholder = LabelResolver.resolve(input.placeholder);
      input.validationMessage = LabelResolver.resolve(input.validationMessage);
      questionsBySection.get(sectionDevName).add(input);
    }

    return questionsBySection;
  }

  private static List<AppQuestionSection> buildSections(
    List<Application_Section__mdt> sectionRecords,
    Map<String, List<AppQuestionInput>> questionsBySection
  ) {
    List<AppQuestionSection> sections = new List<AppQuestionSection>();

    for (Application_Section__mdt s : sectionRecords) {
      List<AppQuestionInput> questions = questionsBySection.containsKey(s.DeveloperName)
        ? questionsBySection.get(s.DeveloperName)
        : new List<AppQuestionInput>();
      AppQuestionSection section = AppQuestionSection.fromCmdt(s, questions);
      section.label = LabelResolver.resolve(section.label);
      section.description = LabelResolver.resolve(section.description);
      sections.add(section);
    }

    return sections;
  }

  /**
   * Builds the list of question DeveloperNames whose target fields are referenced
   * by any visibility criteria. These are the "controlling" questions — only changes
   * to these fields need to trigger visibility re-evaluation.
   */
  private static List<String> buildControllingQuestionDevNames(
    List<Application_Section__mdt> sections,
    List<Application_Question__mdt> questions
  ) {
    Set<String> referencedFieldApiNames = new Set<String>();

    for (Application_Section__mdt section : sections) {
      if (
        section.Visibility_Criteria__r != null &&
        String.isNotBlank(section.Visibility_Criteria__r.Formula_Expression__c)
      ) {
        try {
          referencedFieldApiNames.addAll(
            criteriaEvaluator.getReferencedFields(section.Visibility_Criteria__r)
          );
        } catch (Exception e) {
          // Fall through — field will not be mapped
        }
      }
    }

    for (Application_Question__mdt question : questions) {
      if (
        question.Visibility_Criteria__r != null &&
        String.isNotBlank(question.Visibility_Criteria__r.Formula_Expression__c)
      ) {
        try {
          referencedFieldApiNames.addAll(
            criteriaEvaluator.getReferencedFields(question.Visibility_Criteria__r)
          );
        } catch (Exception e) {
          // Fall through — field will not be mapped
        }
      }
    }

    if (referencedFieldApiNames.isEmpty()) {
      return new List<String>();
    }

    Map<String, String> fieldApiToQuestionDevName = new Map<String, String>();
    for (Application_Question__mdt q : questions) {
      // Compound inputs without Target_Field can't drive visibility — skip.
      if (q.Target_Field__r == null) {
        continue;
      }
      SObjectField field = SObjectFieldCmdtParser.getSObjectField(q.Target_Field__r);
      fieldApiToQuestionDevName.put(field.getDescribe().getName(), q.DeveloperName);
    }

    Set<String> controllingDevNames = new Set<String>();
    for (String fieldApiName : referencedFieldApiNames) {
      if (fieldApiToQuestionDevName.containsKey(fieldApiName)) {
        controllingDevNames.add(fieldApiToQuestionDevName.get(fieldApiName));
      }
    }

    return new List<String>(controllingDevNames);
  }

  @TestVisible
  private static Boolean matchesVariant(String recordVariant, String filterVariant) {
    if (String.isBlank(filterVariant)) {
      return true;
    }
    if (String.isBlank(recordVariant)) {
      return true;
    }
    return recordVariant.contains(filterVariant);
  }
}