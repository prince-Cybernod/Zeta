import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import applyCompanionCopyFrom from '@salesforce/apex/ApplicationQuestionController.applyCompanionCopyFrom';
import applyCompanionWriteback from '@salesforce/apex/ApplicationQuestionController.applyCompanionWriteback';
import clearAddressQuestion from '@salesforce/apex/ApplicationQuestionController.clearAddressQuestion';
import getApplicationFormBundle from '@salesforce/apex/ApplicationQuestionController.getApplicationFormBundle';
import saveFormAnswers from '@salesforce/apex/ApplicationQuestionController.saveFormAnswers';
import labelAllChangesSaved from '@salesforce/label/c.AppUI_AllChangesSaved';
import labelAriaLoadingForm from '@salesforce/label/c.AppUI_AriaLoadingForm';
import labelAriaUpdatingForm from '@salesforce/label/c.AppUI_AriaUpdatingForm';
import labelFormSavedSuccess from '@salesforce/label/c.AppUI_FormSavedSuccess';
import labelNoRecordId from '@salesforce/label/c.AppUI_NoRecordId';
import labelResidencyWarning from '@salesforce/label/c.AppUI_ResidencyWarning';
import labelResidencyWarningState from '@salesforce/label/c.AppUI_ResidencyWarning_State';
import labelSave from '@salesforce/label/c.AppUI_Save';
import labelSaveFailed from '@salesforce/label/c.AppUI_SaveFailed';
import labelSaving from '@salesforce/label/c.AppUI_Saving';
import labelUnsavedChanges from '@salesforce/label/c.AppUI_UnsavedChanges';
import {
  CriteriaEvalError,
  evaluateCriteria,
  extractReferencedFields
} from 'c/criteriaEvaluator';
import { ErrorHandler } from 'c/errorHandler';

const AUTO_SAVE_DELAY = 2000;
const VISIBILITY_DELAY = 50;

const COMM_PREFS_PAIRS = {
  Email_Consent: 'Email_Opt_Out',
  Email_Opt_Out: 'Email_Consent',
  Text_Message_Opt_In: 'Text_Message_Opt_Out',
  Text_Message_Opt_Out: 'Text_Message_Opt_In'
};

// Map Employee_Priority_Guardian picklist value -> source guardian question
// developer-name prefix. When the user picks one of these values in the
// Employee Information section, the Employee First/Last Name fields prefill
// from the corresponding guardian's already-captured answers.
// Blank leaves the fields untouched.
const EMPLOYEE_GUARDIAN_PICKER = 'Employee_Priority_Guardian';
const EMPLOYEE_GUARDIAN_SOURCES = {
  Primary: 'Guardian_1',
  Secondary: 'Guardian_2'
};
const EMPLOYEE_GUARDIAN_FIELDS = [
  { employee: 'Employee_First_Name', guardianSuffix: '_First_Name' },
  { employee: 'Employee_Last_Name', guardianSuffix: '_Last_Name' }
];

export default class ApplicationFormPage extends LightningElement {
  @api pageDevName = 'Application_Details';
  @api variant;
  @api recordId;
  @api readOnly = false;
  @api showToast = false;
  @api embedded = false;
  @api sectionVisibilityRules = {};
  @api insertSlotAfterSortOrder = 0;
  // Comma-separated section developer-name allow/deny lists. They let the SAME
  // CMDT page (e.g. Application_Details) be rendered in two places without
  // duplicating section/question metadata: the create screen (step 1) renders
  // ONLY the address sections (include) while step 4 renders everything EXCEPT
  // those sections (exclude). Purely a client-side render filter over the one
  // shared, page-scoped bundle — single source of truth is preserved.
  @api includeSectionDevNames = '';
  @api excludeSectionDevNames = '';

  formStructure;
  answers = {};
  hasResidencyWarning = false;
  residencyRequiresCityOnly = false;
  isLoading = true;
  isSaving = false;
  isVisibilityEvaluating = false;
  saveStatusMessage = '';
  error;
  wiredBundleResult;
  _visibilityResolved = false;

  _autoSaveTimerId;
  _visibilityTimerId;
  _visibilityMap = {};
  _controllingFields = new Set();
  _visibilityRules = []; // { devName, kind: 'section'|'question', formula }
  _bundleAppliedKey = null;
  // True once we've built `this.answers` from the first bundle. Subsequent
  // (post-save) bundle refreshes must NOT rebuild the answer map — they would
  // clobber in-progress client state (unchecked booleans absent from
  // existingAnswers, lazily-loaded Address compound values) with stale server
  // data. We still refresh structure/rules/warnings/visibility every time.
  _answersInitialized = false;

  _handleBeforeUnload = (event) => {
    if (this.saveStatusMessage === labelUnsavedChanges) {
      event.returnValue = '';
    }
  };

  connectedCallback() {
    window.addEventListener('beforeunload', this._handleBeforeUnload);
  }

  disconnectedCallback() {
    window.removeEventListener('beforeunload', this._handleBeforeUnload);
    clearTimeout(this._autoSaveTimerId);
    clearTimeout(this._visibilityTimerId);
    clearTimeout(this._clearAddressTimerId);
  }

  get ariaLoadingForm() {
    return labelAriaLoadingForm;
  }

  get ariaUpdatingForm() {
    return labelAriaUpdatingForm;
  }

  get hasFormData() {
    return !this.isLoading && !this.error && this.formStructure;
  }

  get saveButtonLabel() {
    return this.isSaving ? labelSaving : labelSave;
  }

  get containerClass() {
    return 'form-card' + (this.embedded ? ' form-embedded' : '');
  }

  get showSaveButton() {
    return !this.readOnly && !this.embedded;
  }

  get showFormHeader() {
    return !this.embedded;
  }

  get showResidencyWarning() {
    return this.hasResidencyWarning && !this.readOnly;
  }

  get residencyWarningMessage() {
    // Pre-K only requires NYC residency; K-9 (and up) require NY State.
    return this.residencyRequiresCityOnly
      ? labelResidencyWarning
      : labelResidencyWarningState;
  }

  get wireVariant() {
    return this.variant || null;
  }

  get wireRecordId() {
    return this.recordId || null;
  }

  // Push the include-section list THROUGH to the Apex bundle call so the server
  // scopes the structure/answers it builds (and skips submission warnings) rather
  // than building the entire page and discarding all but these sections client-side.
  // Page 4 supplies no include list, so this is null and the full bundle is returned.
  get wireIncludeSections() {
    return this.includeSectionDevNames || null;
  }

  get questionVisibilityMap() {
    return this._visibilityMap;
  }

  get isVisibilityResolved() {
    return this._visibilityResolved;
  }

  get _includeSet() {
    return this._parseSectionList(this.includeSectionDevNames);
  }

  get _excludeSet() {
    return this._parseSectionList(this.excludeSectionDevNames);
  }

  _parseSectionList(raw) {
    if (!raw || typeof raw !== 'string') {
      return null;
    }
    const names = raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    return names.length ? new Set(names) : null;
  }

  get visibleSections() {
    if (!this.formStructure?.sections) {
      return [];
    }

    const includeSet = this._includeSet;
    const excludeSet = this._excludeSet;

    return this.formStructure.sections.filter((section) => {
      if (!section.questions || section.questions.length === 0) {
        return false;
      }

      // Section-scoping filters: render only the allow-listed sections (when an
      // include list is supplied) and never the deny-listed ones.
      if (includeSet && !includeSet.has(section.developerName)) {
        return false;
      }
      if (excludeSet && excludeSet.has(section.developerName)) {
        return false;
      }

      const rules = this.sectionVisibilityRules[section.developerName];
      if (rules) {
        for (const [questionDevName, expectedValue] of Object.entries(rules)) {
          if (this.answers[questionDevName] !== expectedValue) {
            return false;
          }
        }
      }

      if (!this._visibilityResolved) {
        return !section.hasVisibilityRule;
      }

      if (
        this._visibilityMap[section.developerName] !== undefined &&
        !this._visibilityMap[section.developerName]
      ) {
        return false;
      }

      return true;
    });
  }

  get sectionsBeforeSlot() {
    if (!this.insertSlotAfterSortOrder) return this.visibleSections;
    return this.visibleSections.filter(
      (s) => s.sortOrder <= this.insertSlotAfterSortOrder
    );
  }

  get sectionsAfterSlot() {
    if (!this.insertSlotAfterSortOrder) return [];
    return this.visibleSections.filter(
      (s) => s.sortOrder > this.insertSlotAfterSortOrder
    );
  }

  get hasSlotContent() {
    return !!this.insertSlotAfterSortOrder;
  }

  @wire(getApplicationFormBundle, {
    recordId: '$wireRecordId',
    pageDevName: '$pageDevName',
    variant: '$wireVariant',
    includeSectionDevNames: '$wireIncludeSections'
  })
  wiredGetApplicationFormBundle(result) {
    this.wiredBundleResult = result;
    const { data, error } = result;

    if (data) {
      this.error = undefined;
      this._applyBundle(data);
    } else if (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
      this.formStructure = undefined;
      this.isLoading = false;
    }
  }

  _applyBundle(bundle) {
    const formStructure = bundle.formStructure || {};
    this.formStructure = formStructure;

    // Capture every section/question formula in a single pass so we can
    // re-evaluate visibility client-side.
    this._visibilityRules = this._buildVisibilityRules(formStructure);
    this._fieldAliasMap = this._buildFieldAliasMap(formStructure);
    this._controllingFields = this._buildControllingFields(formStructure);

    // Seed answers with question default values + any guardian defaults the
    // server resolved for us. Existing saved answers always win.
    //
    // We only build `this.answers` from the bundle on the FIRST load. A
    // post-save refreshApex re-provisions this wire with a fresh bundle, but
    // the client answer map is the authoritative source of in-progress edits:
    //   - unchecked booleans aren't echoed by existingAnswers in a way that
    //     survives the seed (a cleared checkbox loses to its server/CMDT
    //     default), so re-seeding silently re-checks Lives_With_Guardian_1;
    //   - Address compound values live ONLY in `this.answers` (lazily loaded
    //     inside questionAddress and pushed up via answerchange) and are NOT
    //     part of existingAnswers, so re-seeding drops them and the address
    //     section's Collapse button vanishes.
    // Everything else below (structure, rules, warnings, visibility) is
    // server-derived and refreshed on every apply.
    const existingAnswers = bundle.existingAnswers || {};

    if (!this._answersInitialized) {
      const defaults = {};
      const questionInputTypes = {};
      for (const section of formStructure.sections || []) {
        for (const question of section.questions || []) {
          questionInputTypes[question.developerName] = question.inputType;
          if (question.defaultValue) {
            // CMDT default values are stored as strings. Checkbox questions
            // (e.g. Lives_With_Guardian_1, default "true") must seed a real
            // boolean so the strict `=== true` checks in companion-writeback
            // and visibility evaluation behave correctly.
            defaults[question.developerName] =
              question.inputType === 'Checkbox'
                ? String(question.defaultValue).toLowerCase() === 'true'
                : question.defaultValue;
          }
        }
      }

      const guardianDefaults =
        this.pageDevName === 'Application_Details' && bundle.guardianDefaults
          ? { ...bundle.guardianDefaults }
          : {};

      // guardianDefaults arrive from an Apex Map<String, String>, so every
      // value is a string. Checkbox-typed prefills (e.g. Employee_Priority,
      // pre-checked when the parent is a self-reported Zeta employee) must be
      // coerced to a real boolean for the same strict `=== true` checks.
      for (const key of Object.keys(guardianDefaults)) {
        if (questionInputTypes[key] === 'Checkbox') {
          guardianDefaults[key] =
            String(guardianDefaults[key]).toLowerCase() === 'true';
        }
      }

      this.answers = { ...defaults, ...guardianDefaults, ...existingAnswers };

      // When the employee-guardian picker arrives prefilled (a Self-Reported
      // Zeta Employee parent), mirror the manual-selection behavior and seed the
      // Employee First/Last Name from the matching guardian, so the prefill is
      // complete instead of leaving the required name fields blank. Direct seed
      // (no updateAnswer side effects) keeps it consistent with how the box and
      // picker prefill — the values render now and persist on continue/submit.
      // Skipped when the parent already saved their own picker answer (saved
      // wins) or already has an employee name on the application (never clobber).
      const prefilledEmployeeGuardian =
        guardianDefaults[EMPLOYEE_GUARDIAN_PICKER];
      if (
        prefilledEmployeeGuardian &&
        existingAnswers[EMPLOYEE_GUARDIAN_PICKER] === undefined
      ) {
        for (const entry of this._employeeNamePrefillEntries(
          prefilledEmployeeGuardian
        )) {
          const current = this.answers[entry.field];
          if (current === undefined || current === null || current === '') {
            this.answers[entry.field] = entry.value;
          }
        }
      }

      this._answersInitialized = true;

      // Fire the answerchange events the wizard depends on for cross-step
      // state. Only on the initial seed — a post-save refresh would otherwise
      // re-broadcast stale server values over fresher client state.
      if (Object.keys(existingAnswers).length > 0) {
        this._dispatchExistingAnswers(existingAnswers);
      }
    }

    // Submission warnings come bundled too — always taken from the (possibly
    // refreshed) server bundle so residency/age warnings update after autosave.
    const warnings = bundle.submissionWarnings || {};
    this.hasResidencyWarning = warnings.hasResidencyWarning === true;
    this.residencyRequiresCityOnly =
      warnings.residencyRequiresCityOnly === true;

    // First-pass / re-evaluation of visibility. Pure JS, runs every apply
    // against the current answer map.
    this._performVisibilityCheck();

    this.isLoading = false;
  }

  _buildVisibilityRules(formStructure) {
    const rules = [];
    for (const section of formStructure.sections || []) {
      const formula = section?.visibilityCriteria?.formulaExpression;
      if (formula) {
        rules.push({
          devName: section.developerName,
          kind: 'section',
          formula
        });
      }
      for (const question of section?.questions || []) {
        const qFormula = question?.visibilityCriteria?.formulaExpression;
        if (qFormula) {
          rules.push({
            devName: question.developerName,
            kind: 'question',
            formula: qFormula
          });
        }
      }
    }
    return rules;
  }

  /**
   * Build the field-API-name -> question-developer-name lookup used to bridge
   * `SObject_Field_Criteria__mdt` formulas (which reference field API names)
   * against `this.answers` (which is keyed by question developer name). Passed
   * to `evaluateCriteria` as a fallback resolver and reused by
   * `_buildControllingFields` to map formula references to controlling answer
   * keys.
   */
  _buildFieldAliasMap(formStructure) {
    const aliasMap = new Map();
    for (const section of formStructure.sections || []) {
      for (const question of section.questions || []) {
        if (question.targetField) {
          aliasMap.set(question.targetField, question.developerName);
        }
      }
    }
    return aliasMap;
  }

  /**
   * Compute the set of controlling question developer names whose answers
   * influence visibility. Uses `this._fieldAliasMap` to map referenced field
   * API names to question developer names, falling back to the server-provided
   * list when our parser cannot handle a formula.
   */
  _buildControllingFields(formStructure) {
    const controlling = new Set();
    let parseFailed = false;

    for (const rule of this._visibilityRules) {
      try {
        const fields = extractReferencedFields(rule.formula);
        for (const field of fields) {
          if (this._fieldAliasMap.has(field)) {
            controlling.add(this._fieldAliasMap.get(field));
          } else {
            // The reference might already be a question developer name.
            controlling.add(field);
          }
        }
      } catch (err) {
        parseFailed = true;
        // eslint-disable-next-line no-console
        console.warn(
          `[applicationFormPage] Falling back to server controllingQuestionDevNames — failed to parse formula: ${rule.formula}`,
          err
        );
      }
    }

    if (
      parseFailed &&
      Array.isArray(formStructure.controllingQuestionDevNames)
    ) {
      for (const name of formStructure.controllingQuestionDevNames) {
        controlling.add(name);
      }
    }

    return controlling;
  }

  _dispatchExistingAnswers(existing) {
    for (const [developerName, value] of Object.entries(existing)) {
      this.dispatchEvent(
        new CustomEvent('answerchange', {
          detail: { developerName, value },
          bubbles: true,
          composed: true
        })
      );
    }
  }

  _dispatchSaveStatus(status) {
    this.dispatchEvent(
      new CustomEvent('savestatus', {
        detail: { status },
        bubbles: true,
        composed: true
      })
    );
  }

  _dispatchVisibilityChange() {
    this.dispatchEvent(
      new CustomEvent('visibilitychange', {
        detail: { visibilityMap: { ...this._visibilityMap } },
        bubbles: true,
        composed: true
      })
    );
  }

  handleAnswerChange(event) {
    const { developerName, value } = event.detail;
    this.answers = { ...this.answers, [developerName]: value };
    this.saveStatusMessage = labelUnsavedChanges;
    this._dispatchSaveStatus('unsaved');
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: { developerName, value },
        bubbles: true,
        composed: true
      })
    );
    this.scheduleAutoSave();
    if (this._controllingFields.has(developerName)) {
      this.scheduleVisibilityCheck();
    }
    this._handleCommPrefsChange(developerName, value);
    this._handleSameAsPrimaryChange(developerName, value);
    this._handleLivesWithGuardianOneChange(developerName, value);
    this._handleEmployeeGuardianPickerChange(developerName, value);
  }

  /**
   * When the user selects which guardian is the Zeta employee, prefill the
   * downstream Employee First/Last Name fields from the matching guardian's
   * already-entered answers. Pure client-side — no Apex round trip; the
   * guardian answers are already in `this.answers`. The auto-save debounce
   * will persist the prefilled values just like any other edit.
   *
   * Behavior:
   *   Primary  -> copy Guardian_1_First_Name / Guardian_1_Last_Name
   *   Secondary-> copy Guardian_2_First_Name / Guardian_2_Last_Name
   *   blank -> no-op (don't clobber what the user may have typed)
   *
   * The user can still edit the prefilled fields manually after the fact.
   */
  _handleEmployeeGuardianPickerChange(developerName, value) {
    if (developerName !== EMPLOYEE_GUARDIAN_PICKER) {
      return;
    }
    for (const entry of this._employeeNamePrefillEntries(value)) {
      this.updateAnswer(entry.field, entry.value);
    }
  }

  /**
   * Resolve the Employee First/Last Name values to copy for a given
   * Employee_Priority_Guardian picker value, reading the matching guardian's
   * already-captured answers from `this.answers`. Returns `{ field, value }`
   * entries for every non-blank source; an unmapped or blank picker value
   * yields an empty list. Shared by the user-driven picker handler and the
   * prefill seed so the Primary->Guardian_1 / Secondary->Guardian_2 mapping
   * lives in exactly one place.
   */
  _employeeNamePrefillEntries(guardianValue) {
    const sourcePrefix = EMPLOYEE_GUARDIAN_SOURCES[guardianValue];
    if (!sourcePrefix) {
      return [];
    }
    const entries = [];
    for (const mapping of EMPLOYEE_GUARDIAN_FIELDS) {
      const sourceValue = this.answers[sourcePrefix + mapping.guardianSuffix];
      if (
        sourceValue !== undefined &&
        sourceValue !== null &&
        sourceValue !== ''
      ) {
        entries.push({ field: mapping.employee, value: sourceValue });
      }
    }
    return entries;
  }

  _findQuestion(developerName) {
    if (!developerName || !this.formStructure?.sections) {
      return null;
    }
    for (const section of this.formStructure.sections) {
      if (!section.questions) continue;
      for (const q of section.questions) {
        if (q.developerName === developerName) {
          return q;
        }
      }
    }
    return null;
  }

  _findAddressQuestion() {
    if (!this.formStructure?.sections) return null;
    for (const section of this.formStructure.sections) {
      if (!section.questions) continue;
      for (const q of section.questions) {
        if (q.inputType === 'Address' && q.companionQuestionDevName) {
          return q;
        }
      }
    }
    return null;
  }

  _handleLivesWithGuardianOneChange(developerName, value) {
    if (!this.recordId) {
      return;
    }
    const addressQ = this._findAddressQuestion();
    if (!addressQ) {
      return;
    }
    // companionQuestionDevName is the student-side Address_Compound question
    // whose Field_Bindings__c write to Student.PersonMailing*. The handler
    // owns two flows against it: writeback (copy guardian -> student) when
    // the checkbox flips ON, and clear (null student fields) when it flips
    // OFF — without the clear, the student record keeps the guardian's
    // address from the previous writeback and `questionAddress` re-seeds it.
    const studentQDevName = addressQ.companionQuestionDevName;
    if (developerName === 'Lives_With_Guardian_1' && value === false) {
      this.updateAnswer(studentQDevName, null);
      clearTimeout(this._clearAddressTimerId);
      this._clearAddressTimerId = setTimeout(() => {
        clearAddressQuestion({
          applicationId: this.recordId,
          questionDeveloperName: studentQDevName
        }).catch((err) => {
          // eslint-disable-next-line no-console
          console.error('Clear address question failed:', err);
        });
      }, 800);
      return;
    }
    const livesWith = this.answers.Lives_With_Guardian_1 === true;
    const isCheckboxFlip =
      developerName === 'Lives_With_Guardian_1' && value === true;
    const isAddressEdit = developerName === addressQ.developerName && livesWith;
    if (!isCheckboxFlip && !isAddressEdit) {
      return;
    }
    const payload =
      isAddressEdit && value && typeof value === 'object'
        ? value
        : this.answers[addressQ.developerName];
    if (!payload || typeof payload !== 'object') {
      return;
    }
    // Defer slightly so the address save (debounced in questionAddress) lands first.
    setTimeout(() => {
      applyCompanionWriteback({
        applicationId: this.recordId,
        payloadJson: JSON.stringify(payload),
        companionQuestionDevName: addressQ.companionQuestionDevName
      }).catch((err) => {
        // eslint-disable-next-line no-console
        console.error('Companion writeback failed:', err);
      });
    }, 800);
  }

  _handleSameAsPrimaryChange(developerName, value) {
    if (value !== true || !this.recordId) {
      return;
    }
    const checkboxQ = this._findQuestion(developerName);
    // Only Checkbox questions with a companion are "copy-from" triggers.
    // (Address questions with a companion are writeback sources handled by
    // _handleLivesWithGuardianOneChange.)
    if (
      !checkboxQ ||
      checkboxQ.inputType !== 'Checkbox' ||
      !checkboxQ.companionQuestionDevName
    ) {
      return;
    }
    // Find the target Address question that lives in the same section as the
    // checkbox — the checkbox names a source companion (the question whose
    // bindings supply the values to copy from) and the target is the sibling
    // Address question in the same section.
    const targetQ = this._findTargetAddressInSection(checkboxQ);
    if (!targetQ) {
      return;
    }
    applyCompanionCopyFrom({
      applicationId: this.recordId,
      sourceQuestionDevName: checkboxQ.companionQuestionDevName,
      targetQuestionDevName: targetQ.developerName
    }).catch((err) => {
      // eslint-disable-next-line no-console
      console.error('Companion copy-from failed:', err);
    });
  }

  _findTargetAddressInSection(checkboxQ) {
    if (!this.formStructure?.sections) return null;
    for (const section of this.formStructure.sections) {
      if (!section.questions) continue;
      let hasCheckbox = false;
      let addressInSection = null;
      for (const q of section.questions) {
        if (q.developerName === checkboxQ.developerName) hasCheckbox = true;
        if (q.inputType === 'Address') addressInSection = q;
      }
      if (hasCheckbox && addressInSection) {
        return addressInSection;
      }
    }
    return null;
  }

  _handleCommPrefsChange(developerName, value) {
    const pair = COMM_PREFS_PAIRS[developerName];
    if (!pair) {
      return;
    }

    // Mutual exclusion: uncheck the paired checkbox
    if (value === true && this.answers[pair] === true) {
      this.updateAnswer(pair, false);
    }
  }

  scheduleAutoSave() {
    if (this.readOnly || !this.recordId) {
      return;
    }
    clearTimeout(this._autoSaveTimerId);
    this._autoSaveTimerId = setTimeout(() => {
      this._performAutoSave();
    }, AUTO_SAVE_DELAY);
  }

  async _performAutoSave() {
    if (this.isSaving) {
      return;
    }

    this.isSaving = true;
    this.saveStatusMessage = labelSaving;
    this._dispatchSaveStatus('saving');

    try {
      await saveFormAnswers({
        applicationId: this.recordId,
        answersJson: JSON.stringify(this.answers)
      });
      this.saveStatusMessage = labelAllChangesSaved;
      this._dispatchSaveStatus('saved');
      if (this.wiredBundleResult) {
        // Best-effort refresh — don't fail the save if cache invalidation breaks.
        refreshApex(this.wiredBundleResult).catch((err) => {
          // eslint-disable-next-line no-console
          console.warn(
            '[applicationFormPage] refreshApex after autosave failed',
            err
          );
        });
      }
    } catch (err) {
      this.saveStatusMessage = labelSaveFailed;
      this._dispatchSaveStatus('failed');
      // eslint-disable-next-line no-console
      console.error('Auto-save failed:', err);
    } finally {
      this.isSaving = false;
    }
  }

  scheduleVisibilityCheck() {
    clearTimeout(this._visibilityTimerId);
    this._visibilityTimerId = setTimeout(() => {
      this._performVisibilityCheck();
    }, VISIBILITY_DELAY);
  }

  /**
   * Re-evaluate every visibility rule against the current answer map. Pure JS,
   * no network, runs on every controlling-field change.
   */
  _performVisibilityCheck() {
    if (!this._visibilityRules.length) {
      this._visibilityMap = {};
      this._visibilityResolved = true;
      this._dispatchVisibilityChange();
      return;
    }

    this.isVisibilityEvaluating = true;
    const next = {};
    try {
      for (const rule of this._visibilityRules) {
        try {
          next[rule.devName] = evaluateCriteria(
            rule.formula,
            this.answers,
            this._fieldAliasMap
          );
        } catch (err) {
          if (err instanceof CriteriaEvalError) {
            // Conservative fallback — keep the rule visible so the user can
            // still complete the form when our parser hits an edge case.
            // eslint-disable-next-line no-console
            console.warn(
              `[applicationFormPage] Visibility rule '${rule.devName}' failed to evaluate, defaulting to visible`,
              err
            );
            next[rule.devName] = true;
          } else {
            throw err;
          }
        }
      }
      this._visibilityMap = next;
      this._visibilityResolved = true;
      // Force a re-render of dependent getters.
      this.answers = { ...this.answers };
      this._dispatchVisibilityChange();
    } finally {
      this.isVisibilityEvaluating = false;
    }
  }

  @api
  async flushAndSave() {
    clearTimeout(this._autoSaveTimerId);
    if (this.recordId && this.saveStatusMessage === labelUnsavedChanges) {
      await this._performAutoSave();
    }
  }

  @api
  updateAnswer(developerName, value) {
    this.answers = { ...this.answers, [developerName]: value };
    this.saveStatusMessage = labelUnsavedChanges;
    this._dispatchSaveStatus('unsaved');
    this.scheduleAutoSave();
    if (this._controllingFields.has(developerName)) {
      this.scheduleVisibilityCheck();
    }
  }

  @api
  validateForm() {
    const sections = this.template.querySelectorAll('c-application-section');
    let allValid = true;
    let firstIncomplete = null;

    sections.forEach((section) => {
      let state = null;
      if (typeof section.getSectionState === 'function') {
        state = section.getSectionState();
      }
      if (state === 'incomplete' || state === 'untouched') {
        if (typeof section.forceExpand === 'function') {
          section.forceExpand();
        }
        if (state === 'incomplete' && !firstIncomplete) {
          firstIncomplete = section;
        }
        if (state === 'incomplete') {
          allValid = false;
        }
      }
      if (!section.reportValidity()) {
        allValid = false;
      }
    });

    if (!allValid && firstIncomplete) {
      // Defer to next paint so the force-expanded section is in the DOM.
      // eslint-disable-next-line no-undef
      requestAnimationFrame(() => {
        firstIncomplete.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }

    return allValid;
  }

  async handleSave() {
    if (!this.recordId) {
      if (this.showToast) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: labelNoRecordId,
            variant: 'error'
          })
        );
      }
      return;
    }

    if (!this.validateForm()) {
      return;
    }

    // Cancel any pending auto-save since we're saving now
    clearTimeout(this._autoSaveTimerId);

    this.isSaving = true;
    this.saveStatusMessage = labelSaving;
    this._dispatchSaveStatus('saving');

    try {
      await saveFormAnswers({
        applicationId: this.recordId,
        answersJson: JSON.stringify(this.answers)
      });

      this.saveStatusMessage = labelAllChangesSaved;
      this._dispatchSaveStatus('saved');

      if (this.wiredBundleResult) {
        await refreshApex(this.wiredBundleResult);
      }

      this.dispatchEvent(
        new CustomEvent('formsubmit', {
          detail: {
            recordId: this.recordId,
            answers: { ...this.answers }
          }
        })
      );

      if (this.showToast) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Success',
            message: labelFormSavedSuccess,
            variant: 'success'
          })
        );
      }
    } catch (err) {
      this.saveStatusMessage = labelSaveFailed;
      this._dispatchSaveStatus('failed');
      if (this.showToast) {
        ErrorHandler.toast(this, err);
      }
    } finally {
      this.isSaving = false;
    }
  }
}