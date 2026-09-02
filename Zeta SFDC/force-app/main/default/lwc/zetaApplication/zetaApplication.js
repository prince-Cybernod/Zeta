import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getApplicationFormBundle from '@salesforce/apex/ApplicationQuestionController.getApplicationFormBundle';
import getReviewBundle from '@salesforce/apex/ApplicationReviewController.getReviewBundle';
import getEligibleSchools from '@salesforce/apex/SchoolSelectionController.getEligibleSchools';
import syncEmployeePriority from '@salesforce/apex/SiblingSectionController.syncEmployeePriority';
import checkDuplicateApplication from '@salesforce/apex/ZetaApplicationController.checkDuplicateApplication';
import checkDuplicateBeforeCreate from '@salesforce/apex/ZetaApplicationController.checkDuplicateBeforeCreate';
import checkEnrollmentStatus from '@salesforce/apex/ZetaApplicationController.checkEnrollmentStatus';
import createApplication from '@salesforce/apex/ZetaApplicationController.createApplication';
import findDraftApplication from '@salesforce/apex/ZetaApplicationController.findDraftApplication';
import getTimelineLandingContent from '@salesforce/apex/ZetaApplicationController.getTimelineLandingContent';
import getWizardState from '@salesforce/apex/ZetaApplicationController.getWizardState';
import submitApplication from '@salesforce/apex/ZetaApplicationController.submitApplication';
import updateWizardStep from '@salesforce/apex/ZetaApplicationController.updateWizardStep';
import labelAllChangesSaved from '@salesforce/label/c.AppUI_AllChangesSaved';
import labelApplicationsClosed from '@salesforce/label/c.AppUI_ApplicationsClosed';
import labelApplyingFor from '@salesforce/label/c.AppUI_ApplyingFor';
import labelAppSubmittedFor from '@salesforce/label/c.AppUI_AppSubmittedFor';
import labelAriaAppProgress from '@salesforce/label/c.AppUI_AriaAppProgress';
import labelAriaLoadingApp from '@salesforce/label/c.AppUI_AriaLoadingApp';
import labelAriaLoadingNextStep from '@salesforce/label/c.AppUI_AriaLoadingNextStep';
import labelAriaSubmittingApp from '@salesforce/label/c.AppUI_AriaSubmittingApp';
import labelBack from '@salesforce/label/c.AppUI_Back';
import labelCancelReturnToReview from '@salesforce/label/c.AppUI_CancelReturnToReview';
import labelComingSoon from '@salesforce/label/c.AppUI_ComingSoon';
import labelContinue from '@salesforce/label/c.AppUI_Continue';
import labelDuplicateApplication from '@salesforce/label/c.AppUI_DuplicateApplication';
import labelExistingAppDesc from '@salesforce/label/c.AppUI_ExistingAppDesc';
import labelExistingAppFound from '@salesforce/label/c.AppUI_ExistingAppFound';
import labelGoBack from '@salesforce/label/c.AppUI_GoBack';
import labelResume from '@salesforce/label/c.AppUI_Resume';
import labelReturnHome from '@salesforce/label/c.AppUI_ReturnHome';
import labelSaveAndExit from '@salesforce/label/c.AppUI_SaveAndExit';
import labelSaveAndReturnToReview from '@salesforce/label/c.AppUI_SaveAndReturnToReview';
import labelSaveFailed from '@salesforce/label/c.AppUI_SaveFailed';
import labelSaveFailedRetry from '@salesforce/label/c.AppUI_SaveFailedRetry';
import labelSaveSignatureFailed from '@salesforce/label/c.AppUI_SaveSignatureFailed';
import labelSaving from '@salesforce/label/c.AppUI_Saving';
import labelStartNew from '@salesforce/label/c.AppUI_StartNew';
import labelStepChooseSchools from '@salesforce/label/c.AppUI_StepChooseSchools';
import labelStepConfirmSubmit from '@salesforce/label/c.AppUI_StepConfirmSubmit';
import labelStepFillApplication from '@salesforce/label/c.AppUI_StepFillApplication';
import labelStepOf from '@salesforce/label/c.AppUI_StepOf';
import labelStepRankSchools from '@salesforce/label/c.AppUI_StepRankSchools';
import labelStepStudentInfo from '@salesforce/label/c.AppUI_StepStudentInfo';
import labelSubmit from '@salesforce/label/c.AppUI_Submit';
import labelSubmitAppDesc from '@salesforce/label/c.AppUI_SubmitAppDesc';
import labelSubmitAppQuestion from '@salesforce/label/c.AppUI_SubmitAppQuestion';
import labelSubmitFailed from '@salesforce/label/c.AppUI_SubmitFailed';
import labelSubmittedMessage from '@salesforce/label/c.AppUI_SubmittedMessage';
import labelSubmittedTitle from '@salesforce/label/c.AppUI_SubmittedTitle';
import labelSubmitting from '@salesforce/label/c.AppUI_Submitting';
import labelUnsavedChanges from '@salesforce/label/c.AppUI_UnsavedChanges';
import labelZetaCharterSchools from '@salesforce/label/c.AppUI_ZetaCharterSchools';

const TOTAL_STEPS = 5;
// Section scope for the embedded create-screen address widget. Must mirror
// studentSelection.html's <c-application-form-page include-section-dev-names="...">
// exactly so the prefetch warms the SAME LDS cache key the embedded form's @wire
// resolves against.
const CREATE_SCREEN_ADDRESS_SECTIONS =
  'Address,Guardian_1_Address,Student_Living_Status';
const STEP_LABELS = [
  labelStepStudentInfo,
  labelStepChooseSchools,
  labelStepRankSchools,
  labelStepFillApplication,
  labelStepConfirmSubmit
];
// Page reference types only Lightning Experience produces. Aura communities
// also report standard__namedPage, so these are the unambiguous internal ones.
const INTERNAL_PAGE_TYPES = new Set([
  'standard__navItemPage',
  'standard__recordPage',
  'standard__app'
]);
const PORTAL_EXIT_URL = '/parents/s/';

export default class ZetaApplication extends LightningElement {
  @api recordId;
  @api variant;
  @api pageDevName = 'Application_Details';
  @api timelineId;
  @api timelineName = '';
  @api forceNew = false;
  @api contactSupportUrl;

  // The header sticks to the top of the viewport, which is what the parent
  // portal wants because the wizard owns the page there. A host that already
  // supplies page chrome — the internal staff tab, sitting under the Salesforce
  // navigation — sets this so the header scrolls with the content instead of
  // covering that navigation.
  @api staticHeader = false;

  currentStep = 1;
  saveStatus = 'saved';
  isLoading = true;
  enrollmentClosed = false;
  landingContent = null;
  isSubmitted = false;
  justSubmitted = false;
  postSubmitMode = false;
  timelineClosed = false;
  _applicationStatus = '';
  isSubmitting = false;
  applicationName = '';
  submitError = '';
  siblingAttendingToggle = false;
  // The "Siblings Also Applying" list is always shown — applying siblings are
  // detected server-side, not via a manual checkbox. (No longer driven by the
  // Sibling_Applying_Details section's visibility map.)
  siblingApplyingToggle = true;
  _resolvedRecordId;
  _pageRefType;
  _createPromise = null;
  _step1Complete = false;
  _step1StudentAccountId;
  _step1Grade;
  _step1GradeLabel;
  _step1CurrentGrade;
  _step1IsEnrolled = false;
  _step1Duplicate = false;
  // True while the step-1 picker is persisting a student/grade selection. Gates
  // Continue so the parent can't advance before the server-side age/grade
  // validation resolves.
  _step1Saving = false;
  _step1Committed = false;
  _step2Complete = false;
  _step2SelectedCount = 0;
  _step3Complete = false;
  _studentName = '';
  maxCompletedStep = 0;
  isTransitioning = false;
  transitionError = '';
  showSubmitConfirm = false;
  showDraftChoice = false;
  _draftApplicationId = null;
  // Tracks the step that was live on the previous render so renderedCallback
  // can detect a fresh ENTRY into step 5 and refresh confirmationReview's
  // cached @wire exactly once per entry (see renderedCallback).
  _prevRenderedStep = null;

  labels = {
    continue: labelContinue,
    back: labelBack,
    saveAndExit: labelSaveAndExit,
    submit: labelSubmit,
    comingSoon: labelComingSoon,
    applicationsClosed: labelApplicationsClosed,
    submittedTitle: labelSubmittedTitle,
    submittedMessage: labelSubmittedMessage,
    submitting: labelSubmitting,
    saveAndReturnToReview: labelSaveAndReturnToReview,
    cancelReturnToReview: labelCancelReturnToReview,
    zetaCharterSchools: labelZetaCharterSchools,
    returnHome: labelReturnHome,
    submitAppQuestion: labelSubmitAppQuestion,
    submitAppDesc: labelSubmitAppDesc,
    goBack: labelGoBack,
    existingAppFound: labelExistingAppFound,
    existingAppDesc: labelExistingAppDesc,
    startNew: labelStartNew,
    resume: labelResume,
    ariaAppProgress: labelAriaAppProgress,
    ariaLoadingApp: labelAriaLoadingApp,
    ariaLoadingNextStep: labelAriaLoadingNextStep,
    ariaSubmittingApp: labelAriaSubmittingApp
  };

  @wire(CurrentPageReference)
  handlePageRef(pageRef) {
    this._pageRefType = pageRef?.type;
    if (pageRef?.state?.applicationId && !this.recordId) {
      this._resolvedRecordId = pageRef.state.applicationId;
      this._loadWizardState();
    }
  }

  connectedCallback() {
    if (this.recordId) {
      this._resolvedRecordId = this.recordId;
      this._loadWizardState();
    } else if (!this._resolvedRecordId) {
      this._findOrStartFresh();
    }
  }

  renderedCallback() {
    // Refresh confirmationReview whenever the user (re)enters step 5.
    //
    // confirmationReview loads from getReviewBundle, an
    // @AuraEnabled(cacheable=true) @wire. The component is mounted via lwc:if,
    // so it is destroyed on leaving step 5 and re-created on return — and the
    // fresh @wire re-provisions from the STALE LDS cache. Sibling selection on
    // step 4 commits through a non-cacheable Apex call that LDS never observes,
    // so returning to step 5 would otherwise show a stale sibling list.
    //
    // Firing on the prev !== 5 -> 5 transition (rather than every render)
    // guarantees exactly one refresh per entry and cannot loop: refreshApex
    // updates the child wire's data, never this component's currentStep.
    const prevStep = this._prevRenderedStep;
    const wasStep5 = prevStep === 5;
    this._prevRenderedStep = this.currentStep;

    // Scroll back to the top of the wizard whenever the user moves between steps.
    // Without this the new step inherits the prior step's scroll position, leaving
    // the user at the bottom of a long page. Guard on a real, changed prior step so
    // it never fires on first render / resume-to-saved-step (already at top) and
    // cannot loop (the scroll never mutates currentStep). scrollIntoView on a
    // component-owned element (not window.scrollTo) because in Experience Cloud the
    // scroll container is a theme wrapper, not reliably window; instant (not smooth)
    // because the step content fully swaps and auto-smooth-scroll is a
    // reduced-motion hazard. Anchor on the host element, NOT .zeta-header: the
    // header is position:sticky, so it is always "in view" at the viewport top and
    // scrollIntoView on it is a no-op when the page is scrolled.
    if (prevStep !== null && prevStep !== this.currentStep) {
      requestAnimationFrame(() => {
        this.template.host.scrollIntoView({
          behavior: 'instant',
          block: 'start'
        });
      });
    }

    if (this.currentStep === 5 && !wasStep5) {
      const review = this.template.querySelector('c-confirmation-review');
      if (review) {
        Promise.resolve(review.refresh()).catch((err) => {
          console.error('Failed to refresh review on step 5 entry:', err);
        });
      }
    }
  }

  async _findOrStartFresh() {
    try {
      const enrollment = await checkEnrollmentStatus();
      if (!enrollment.isOpen) {
        this.enrollmentClosed = true;
        this.landingContent = enrollment.landingContent || null;
        return;
      }

      if (this.timelineId) {
        try {
          const content = await getTimelineLandingContent({
            timelineId: this.timelineId
          });
          if (content) {
            this.landingContent = content;
          }
        } catch (err) {
          console.error('Failed to load timeline landing content:', err);
        }
      }

      if (this.forceNew) {
        return;
      }

      const draft = await findDraftApplication({
        timelineId: this.timelineId || null
      });
      if (draft.applicationId) {
        this._draftApplicationId = draft.applicationId;
        this.showDraftChoice = true;
      }
    } catch (err) {
      console.error('Failed to find draft application:', err);
    } finally {
      this.isLoading = false;
    }
  }

  handleResumeDraft() {
    this.showDraftChoice = false;
    this._resolvedRecordId = this._draftApplicationId;
    this._updateUrlWithApplicationId(this._draftApplicationId);
    this.isLoading = true;
    this._resumeWizardState()
      .catch((err) => {
        console.error('Failed to resume draft:', err);
        this._resolvedRecordId = undefined;
        this._clearUrlApplicationId();
        this.currentStep = 1;
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleStartNewApplication() {
    this.showDraftChoice = false;
    this._draftApplicationId = null;
    this.currentStep = 1;
    this.maxCompletedStep = 0;
  }

  async _loadWizardState() {
    if (!this._resolvedRecordId) {
      this.isLoading = false;
      return;
    }

    try {
      const enrollment = await checkEnrollmentStatus();
      if (!enrollment.isOpen) {
        this.enrollmentClosed = true;
        this.landingContent = enrollment.landingContent || null;
        return;
      }

      await this._resumeWizardState();
    } catch (err) {
      console.error('Failed to load wizard state:', err);
      this._resolvedRecordId = undefined;
      this._clearUrlApplicationId();
      this.currentStep = 1;
    } finally {
      this.isLoading = false;
    }
  }

  async _resumeWizardState() {
    const state = await getWizardState({
      applicationId: this._resolvedRecordId
    });

    this._applicationStatus = state.status || '';
    const isWithdrawn = this._applicationStatus === 'Withdrawn/Declined';

    if (state.studentName) {
      this._studentName = state.studentName;
    }

    if (state.landingContent) {
      this.landingContent = state.landingContent;
    }

    if (state.isSubmitted || isWithdrawn) {
      // Submitted apps — and withdrawn apps, which must open read-only and can
      // never be resumed — land on the read-only review step. Keep isSubmitted
      // accurate (false for a withdrawn draft) rather than faking a submission;
      // postSubmitMode is what drives the read-only chrome (no footer, no nav).
      this.isSubmitted = state.isSubmitted === true;
      this.postSubmitMode = true;
      this.timelineClosed = state.timelineClosed === true;
      this.applicationName = state.applicationName || '';
      this.currentStep = TOTAL_STEPS;
      this.maxCompletedStep = TOTAL_STEPS;
      this._step1Committed = true;
      return;
    }

    const lastCompleted = state.lastCompletedStep || 0;
    this.maxCompletedStep = lastCompleted;
    this.currentStep = Math.min(lastCompleted + 1, TOTAL_STEPS);
    if (lastCompleted >= 1) {
      this._step1Committed = true;
    }
  }

  get resolvedRecordId() {
    return this._resolvedRecordId || this.recordId;
  }

  // Staff reach the wizard from a Lightning tab or record page, where the
  // portal URL is a dead end. Anything we can't positively identify as
  // internal keeps the portal behaviour.
  get exitUrl() {
    if (!INTERNAL_PAGE_TYPES.has(this._pageRefType)) {
      return PORTAL_EXIT_URL;
    }
    return this.resolvedRecordId
      ? `/lightning/r/IndividualApplication/${this.resolvedRecordId}/view`
      : '/lightning/page/home';
  }

  get applicationStatus() {
    return this._applicationStatus;
  }

  get stepperSteps() {
    return STEP_LABELS.map((label, i) => {
      const number = i + 1;
      let status;
      if (this.isSubmitted) {
        status = 'complete';
      } else if (number < this.currentStep) {
        status = 'complete';
      } else if (number === this.currentStep) {
        status = 'active';
      } else {
        status = 'future';
      }
      return {
        number,
        label,
        status,
        isComplete: status === 'complete',
        isActive: status === 'active',
        isFuture: status === 'future',
        stepItemClass: `step-item${number > this.maxCompletedStep && number !== this.currentStep ? ' step-item--future' : ' step-item--clickable'}`,
        circleClass: `step-circle step-circle--${status}`,
        labelClass: `step-label step-label--${status}`,
        connectorClass:
          i < TOTAL_STEPS - 1
            ? `step-connector step-connector--${number < this.currentStep ? 'complete' : number === this.currentStep ? 'active' : 'future'}`
            : '',
        showConnector: i < TOTAL_STEPS - 1,
        ariaCurrent: status === 'active' ? 'step' : null
      };
    });
  }

  get stepCounterText() {
    return labelStepOf
      .replace('{0}', this.currentStep)
      .replace('{1}', TOTAL_STEPS);
  }

  get _stepReady() {
    return (
      !this.isLoading &&
      !this.isTransitioning &&
      !this.enrollmentClosed &&
      !this.justSubmitted
    );
  }
  get isStep1() {
    return this._stepReady && this.currentStep === 1;
  }
  get isStep2() {
    return this._stepReady && this.currentStep === 2;
  }
  get isStep3() {
    return this._stepReady && this.currentStep === 3;
  }
  get isStep4() {
    return this._stepReady && this.currentStep === 4;
  }
  get isStep5() {
    return this._stepReady && this.currentStep === 5;
  }
  get isStubStep() {
    return this._stepReady && ![1, 2, 3, 4, 5].includes(this.currentStep);
  }
  get showTransitionSkeleton() {
    return this.isTransitioning && !this.isLoading;
  }

  get hasLandingContent() {
    return !!this.landingContent;
  }

  get showWizardChrome() {
    return !this.enrollmentClosed && (!this.isSubmitted || this.postSubmitMode);
  }

  get showStandardFooter() {
    return !this.postSubmitMode;
  }

  get showPostSubmitStep3Footer() {
    return this.postSubmitMode && this.currentStep === 3;
  }

  get currentStepLabel() {
    return STEP_LABELS[this.currentStep - 1] || '';
  }

  get showBackButton() {
    if (this.postSubmitMode) {
      return false;
    }
    return this.currentStep > 1;
  }

  get continueLabel() {
    if (this.isSubmitting) {
      return labelSubmitting;
    }
    return this.currentStep === TOTAL_STEPS ? labelSubmit : labelContinue;
  }

  get isContinueDisabled() {
    return this.isSubmitting || this._step1Duplicate || this._step1Saving;
  }

  // Exposed to the step-1 student picker so it hides the grade fields when the
  // selected student already has a submitted application (duplicate).
  get step1DuplicateBlocked() {
    return this._step1Duplicate;
  }

  get headerClass() {
    return this.staticHeader
      ? 'zeta-header zeta-header--static'
      : 'zeta-header';
  }

  get saveStatusDotClass() {
    return `save-dot save-dot--${this.saveStatus}`;
  }

  get saveStatusTooltip() {
    const tooltips = {
      saved: labelAllChangesSaved,
      saving: labelSaving,
      unsaved: labelUnsavedChanges,
      failed: labelSaveFailed
    };
    return tooltips[this.saveStatus] || '';
  }

  get hasRecordId() {
    return !!this.resolvedRecordId;
  }

  get studentLocked() {
    return this._step1Committed;
  }

  get showStudentHeader() {
    return !!this._studentName && this.currentStep > 1 && !this.justSubmitted;
  }

  get studentHeaderText() {
    let text = labelApplyingFor.replace('{0}', this._studentName);
    if (this.timelineName) {
      text += ` \u2022 ${this.timelineName}`;
    }
    return text;
  }

  get submittedDisplayMessage() {
    if (this._studentName) {
      return labelAppSubmittedFor.replace('{0}', this._studentName);
    }
    return this.labels.submittedMessage;
  }

  handleReturnHome() {
    this.dispatchEvent(new CustomEvent('returntodashboard'));
  }

  handleStepClick(event) {
    if (this.postSubmitMode) {
      return;
    }
    const step = Number(event.currentTarget.dataset.step);
    if (
      step >= 1 &&
      (step <= this.currentStep || step <= this.maxCompletedStep)
    ) {
      this._prefetchStepData(step);
      this.currentStep = step;
    }
  }

  handleAnswerChange() {}

  handleVisibilityChange(event) {
    const { visibilityMap } = event.detail;
    this.siblingAttendingToggle =
      visibilityMap.Sibling_Attending_Details === true;
    // siblingApplyingToggle is intentionally always true (set at field
    // initialization); the applying list no longer depends on a checkbox.
  }

  handleControllingReset(event) {
    const { developerName, value } = event.detail;
    const formPage = this.template.querySelector('c-application-form-page');
    if (formPage) {
      formPage.updateAnswer(developerName, value);
    }
  }

  async handleStudentCompletion(event) {
    const studentChanged =
      event.detail.studentAccountId !== this._step1StudentAccountId;

    this._step1Complete = event.detail.complete === true;
    this._step1Saving = event.detail.saving === true;
    this._step1StudentAccountId = event.detail.studentAccountId;
    this._step1Grade = event.detail.grade;
    this._step1GradeLabel = event.detail.gradeLabel || event.detail.grade;
    this._step1CurrentGrade = event.detail.currentGrade;
    this._step1IsEnrolled = event.detail.isEnrolled === true;
    if (event.detail.studentName) {
      this._studentName = event.detail.studentName;
    }

    // Switching to a different student clears any stale duplicate banner so it
    // is re-evaluated below for the newly selected student.
    if (studentChanged) {
      this.transitionError = '';
      this._step1Duplicate = false;
    }

    if (
      !this.resolvedRecordId &&
      this._step1StudentAccountId &&
      !this._step1IsEnrolled &&
      !this._step1Duplicate
    ) {
      try {
        const dupCheck = await checkDuplicateBeforeCreate({
          studentAccountId: this._step1StudentAccountId,
          timelineId: this.timelineId || null
        });
        if (dupCheck.isDuplicate) {
          this.transitionError = labelDuplicateApplication;
          this._step1Duplicate = true;
          return;
        }
        await this._createApplicationFromStep1();
        await Promise.resolve();
        const el = this.template.querySelector('c-student-selection');
        if (el) await el.flushAndSave();
      } catch (err) {
        console.error('Failed to create application early:', err);
      }
    }
  }

  handleSchoolCompletion(event) {
    this._step2Complete = event.detail.complete === true;
    this._step2SelectedCount = event.detail.selectedCount || 0;
  }

  handleRankingCompletion(event) {
    this._step3Complete = event.detail.complete === true;
  }

  handleSaveStatus(event) {
    this.saveStatus = event.detail.status;
  }

  async handleNext() {
    this.transitionError = '';

    // Hard backstop for duplicate students: never advance past step 1 when the
    // selected student already has a submitted application for this timeline.
    // The Continue button is also disabled via isContinueDisabled, but the
    // duplicate flag is set by an async check, so guard here too in case a fast
    // click lands before that disabled state paints.
    if (this.currentStep === 1 && this._step1Duplicate) {
      this.transitionError = labelDuplicateApplication;
      return;
    }

    if (this.currentStep === 5) {
      const eSignature = this.template.querySelector('c-e-signature');
      if (eSignature && !eSignature.validate()) {
        return;
      }
      this.showSubmitConfirm = true;
      return;
    }

    if (!this._validateCurrentStep()) {
      return;
    }

    // Compute the next step up-front so we can warm the LDS cache for its
    // primary cacheable Apex calls in parallel with the save round-trip.
    // This lets the new step render with data already cached, eliminating
    // the serial save_time + new_step_load_time the user used to feel.
    let plannedNextStep = null;
    if (this.currentStep < TOTAL_STEPS) {
      plannedNextStep = this.currentStep + 1;
      if (this.currentStep === 2 && this._step2SelectedCount === 1) {
        plannedNextStep = 4;
      }
      // Fire-and-forget: warms LDS cache for cacheable=true methods so the
      // next step's @wire / imperative cacheable calls resolve from cache.
      this._prefetchStepData(plannedNextStep);
    }

    this.isTransitioning = true;
    try {
      await this._flushCurrentStep();
      if (this.currentStep < TOTAL_STEPS) {
        if (this.currentStep === 1) {
          this._step1Committed = true;
        }
        const nextStep =
          plannedNextStep !== null ? plannedNextStep : this.currentStep + 1;
        this.currentStep = nextStep;
        this.maxCompletedStep = Math.max(
          this.maxCompletedStep,
          this.currentStep
        );
        this._persistStep();
      }
    } catch (err) {
      this.transitionError =
        err.body?.message || err.message || labelSaveFailedRetry;
    } finally {
      this.isTransitioning = false;
    }
  }

  handleCancelSubmit() {
    this.showSubmitConfirm = false;
  }

  async handleConfirmSubmit() {
    this.isSubmitting = true;
    this.showSubmitConfirm = false;
    const eSignature = this.template.querySelector('c-e-signature');
    if (eSignature) {
      try {
        await eSignature.flushAndSave();
      } catch (err) {
        this.isSubmitting = false;
        this.submitError =
          err.body?.message || err.message || labelSaveSignatureFailed;
        return;
      }
    }
    await this._submitApplication();
  }

  _validateCurrentStep() {
    if (this.currentStep === 1) {
      const el = this.template.querySelector('c-student-selection');
      return !el || el.validate();
    }
    if (this.currentStep === 2) {
      const el = this.template.querySelector('c-school-selection');
      return !el || el.validate();
    }
    if (this.currentStep === 3) {
      const el = this.template.querySelector('c-school-ranking');
      return !el || el.validate();
    }
    if (this.currentStep === 4) {
      const el = this.template.querySelector('c-application-form-page');
      return !el || el.validateForm();
    }
    return true;
  }

  async _flushCurrentStep() {
    if (this.currentStep === 1) {
      if (this._createPromise) {
        await this._createPromise;
      } else if (!this.resolvedRecordId) {
        const dupCheck = await checkDuplicateBeforeCreate({
          studentAccountId: this._step1StudentAccountId,
          timelineId: this.timelineId || null
        });
        if (dupCheck.isDuplicate) {
          throw new Error(labelDuplicateApplication);
        }
        await this._createApplicationFromStep1();
      } else {
        const el = this.template.querySelector('c-student-selection');
        if (el) await el.flushAndSave();
      }
    } else if (this.currentStep === 2) {
      const el = this.template.querySelector('c-school-selection');
      if (el) await el.flushAndSave();
    } else if (this.currentStep === 3) {
      const el = this.template.querySelector('c-school-ranking');
      if (el) await el.flushAndSave();
    } else if (this.currentStep === 4) {
      const el = this.template.querySelector('c-application-form-page');
      if (el) await el.flushAndSave();
      await this._flushStep4();
    }
  }

  handleBack() {
    if (this.currentStep > 1) {
      this.currentStep -= 1;
    }
  }

  handleNavigateStep(event) {
    const step = event.detail.step;
    if (step >= 1 && step <= TOTAL_STEPS) {
      this.currentStep = step;
    }
  }

  async handleSaveAndReturnToReview() {
    this.transitionError = '';
    this.isTransitioning = true;
    try {
      const el = this.template.querySelector('c-school-ranking');
      if (el && el.validate()) {
        await el.flushAndSave();
        this.currentStep = 5;
      }
    } catch (err) {
      this.transitionError =
        err.body?.message || err.message || labelSaveFailedRetry;
    } finally {
      this.isTransitioning = false;
    }
  }

  handleCancelReturnToReview() {
    this.currentStep = 5;
  }

  async handleSaveAndExit() {
    if (this.currentStep === 1) {
      if (!this.resolvedRecordId && this._step1Complete) {
        await this._createApplicationFromStep1();
      } else {
        const studentSelection = this.template.querySelector(
          'c-student-selection'
        );
        if (studentSelection) {
          await studentSelection.flushAndSave();
        }
      }
    }

    if (this.currentStep === 2) {
      const schoolSelection = this.template.querySelector('c-school-selection');
      if (schoolSelection) {
        await schoolSelection.flushAndSave();
      }
    }

    if (this.currentStep === 3) {
      const schoolRanking = this.template.querySelector('c-school-ranking');
      if (schoolRanking) {
        await schoolRanking.flushAndSave();
      }
    }

    if (this.currentStep === 4) {
      const formPage = this.template.querySelector('c-application-form-page');
      if (formPage) {
        await formPage.flushAndSave();
      }
      await this._flushStep4();
    }
    this._persistStep();
    window.location.href = this.exitUrl;
  }

  async _flushStep4() {
    if (!this.resolvedRecordId) {
      return;
    }
    const siblingSection = this.template.querySelector('c-sibling-section');
    if (siblingSection) {
      await siblingSection.flushAndSave();
    }
    try {
      await syncEmployeePriority({ applicationId: this.resolvedRecordId });
    } catch (err) {
      console.error('Failed to sync employee priority:', err);
    }
  }

  async _createApplicationFromStep1() {
    if (this._createPromise) {
      return this._createPromise;
    }
    this._createPromise = this._doCreateApplication();
    try {
      return await this._createPromise;
    } finally {
      this._createPromise = null;
    }
  }

  async _doCreateApplication() {
    try {
      const result = await createApplication({
        studentAccountId: this._step1StudentAccountId,
        grade: this._step1Grade,
        currentGrade: this._step1CurrentGrade,
        timelineId: this.timelineId || null
      });
      this._resolvedRecordId = result.applicationId;
      this._updateUrlWithApplicationId(result.applicationId);
      // Warm the LDS cache for the embedded address widget's scoped bundle the
      // instant the application exists. The embedded c-application-form-page
      // mounts a tick later (once recordId flows down to studentSelection); by
      // warming the SAME cache key here, its @wire resolves from cache instead of
      // a cold server round-trip — collapsing the create -> address-load waterfall.
      getApplicationFormBundle({
        recordId: result.applicationId,
        pageDevName: 'Application_Details',
        variant: null,
        includeSectionDevNames: CREATE_SCREEN_ADDRESS_SECTIONS
      }).catch(() => {});
      return true;
    } catch (err) {
      console.error(
        'Failed to create application:',
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      return false;
    }
  }

  _updateUrlWithApplicationId(applicationId) {
    const url = new URL(window.location.href);
    url.searchParams.set('applicationId', applicationId);
    window.history.replaceState(null, '', url.toString());
  }

  _clearUrlApplicationId() {
    const url = new URL(window.location.href);
    url.searchParams.delete('applicationId');
    window.history.replaceState(null, '', url.toString());
  }

  async _submitApplication() {
    if (!this.resolvedRecordId) {
      return;
    }
    this.isSubmitting = true;
    this.submitError = '';
    try {
      const dupCheck = await checkDuplicateApplication({
        applicationId: this.resolvedRecordId
      });
      if (dupCheck.isDuplicate) {
        this.submitError = labelDuplicateApplication;
        this.isSubmitting = false;
        return;
      }

      const result = await submitApplication({
        applicationId: this.resolvedRecordId
      });
      this.applicationName = result.applicationName || '';
      this.isSubmitted = true;
      this.justSubmitted = true;
    } catch (err) {
      this.submitError = err.body?.message || err.message || labelSubmitFailed;
      console.error('Failed to submit application:', err);
    } finally {
      this.isSubmitting = false;
    }
  }

  _stopPropagation(event) {
    event.stopPropagation();
  }

  /**
   * Warms the LDS cache for the next step's primary cacheable Apex calls so
   * the new step's @wire / imperative cacheable lookups resolve from cache
   * rather than waiting on a server round-trip. Strictly fire-and-forget:
   * errors are swallowed (the real call will surface them) and the prefetch
   * only targets methods declared @AuraEnabled(cacheable=true).
   *
   * Only cacheable methods benefit here — imperative-to-imperative reuse of
   * cacheable results is what makes this work. Non-cacheable methods
   * (e.g. SchoolRankingController.getRankedSchools) cannot be warmed and are
   * intentionally skipped.
   *
   * @param {number} step  The 1-based step number we're about to navigate to.
   */
  _prefetchStepData(step) {
    const applicationId = this.resolvedRecordId;
    if (!applicationId) {
      return;
    }
    try {
      if (step === 2) {
        // Step 2 (school selection): cacheable
        getEligibleSchools({ applicationId }).catch(() => {});
      } else if (step === 4) {
        // Step 4 (application form): bundle is cacheable; mirror
        // applicationFormPage's wire params exactly so the cache key matches.
        // Page 4 is the FULL form, so its include scope is null (no scoping).
        getApplicationFormBundle({
          recordId: applicationId,
          pageDevName: this.pageDevName,
          variant: this.variant || null,
          includeSectionDevNames: null
        }).catch(() => {});
      } else if (step === 5) {
        // Step 5 (confirmation review): single cacheable bundle matches
        // confirmationReview's @wire — entire screen loads from cache.
        getReviewBundle({ applicationId }).catch(() => {});
      }
      // Steps 1 and 3 have no high-value cacheable prefetch target.
    } catch (err) {
      // Defensive: never let a prefetch failure affect the user-facing flow.
      // (Synchronous throws shouldn't happen here, but belt-and-suspenders.)
    }
  }

  async _persistStep() {
    if (!this.resolvedRecordId) {
      return;
    }
    try {
      await updateWizardStep({
        applicationId: this.resolvedRecordId,
        step: this.currentStep - 1
      });
    } catch (err) {
      console.error('Failed to update wizard step:', err);
    }
  }
}