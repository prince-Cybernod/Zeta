import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import ACADEMIC_INTEREST_OBJECT from '@salesforce/schema/AcademicInterest';
import REASON_FIELD from '@salesforce/schema/AcademicInterest.Withdrawn_Declined_Reason_Picklist__c';
import getReviewBundle from '@salesforce/apex/ApplicationReviewController.getReviewBundle';
import withdrawSchoolApplication from '@salesforce/apex/SchoolRankingController.withdrawSchoolApplication';

// Master record type id — Salesforce's sentinel for "no record types"; the
// getPicklistValues fallback when getObjectInfo reports no default record type.
const NULL_RECORD_TYPE_ID = '012000000000000AAA';
import labelAriaLoadingReview from '@salesforce/label/c.AppUI_AriaLoadingReview';
import labelEdit from '@salesforce/label/c.AppUI_Edit';
import labelAddress from '@salesforce/label/c.AppUI_FieldAddress';
import labelDateOfBirth from '@salesforce/label/c.AppUI_FieldDateOfBirth';
import labelGender from '@salesforce/label/c.AppUI_FieldGender';
import labelGrade from '@salesforce/label/c.AppUI_FieldGrade';
import labelName from '@salesforce/label/c.AppUI_FieldName';
import labelZetaSchool from '@salesforce/label/c.AppUI_FieldZetaSchool';
import labelLotteryMessage from '@salesforce/label/c.AppUI_LotteryMessage';
import labelResidencyWarning from '@salesforce/label/c.AppUI_ResidencyWarning';
import labelResidencyWarningState from '@salesforce/label/c.AppUI_ResidencyWarning_State';
import labelApplicationDetails from '@salesforce/label/c.AppUI_SectionApplicationDetails';
import labelSchoolRankings from '@salesforce/label/c.AppUI_SectionSchoolRankings';
import labelSiblings from '@salesforce/label/c.AppUI_SectionSiblings';
import labelSiblingsApplying from '@salesforce/label/c.AppUI_SiblingsApplying';
import labelSiblingsAttending from '@salesforce/label/c.AppUI_SiblingsAttending';
import labelStudentInfo from '@salesforce/label/c.AppUI_StudentInfo';
import labelUpdateRankings from '@salesforce/label/c.AppUI_UpdateRankings';

export default class ConfirmationReview extends LightningElement {
  @api recordId;
  @api pageDevName = 'Application_Details';
  @api variant;
  @api readOnly = false;
  @api postSubmitMode = false;
  @api timelineClosed = false;
  @api applicationStatus = '';

  // --- Per-school withdraw ---------------------------------------------------
  _openMenuAiId = null;
  showWithdrawModal = false;
  _withdrawAiId = null;
  _withdrawSchoolName = '';
  _withdrawPicklistValue = '';
  _withdrawReason = '';
  _withdrawError = null;
  _isWithdrawing = false;
  withdrawPicklistOptions = [];
  _reasonRecordTypeId = NULL_RECORD_TYPE_ID;

  // Withdrawal reasons come from the AcademicInterest picklist field via the
  // platform UI API — record-type-aware and no custom Apex, mirroring the
  // whole-application withdraw on applicationDashboard.
  @wire(getObjectInfo, { objectApiName: ACADEMIC_INTEREST_OBJECT })
  wiredAcademicInterestInfo({ data }) {
    if (data) {
      this._reasonRecordTypeId =
        data.defaultRecordTypeId || NULL_RECORD_TYPE_ID;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_reasonRecordTypeId',
    fieldApiName: REASON_FIELD
  })
  wiredWithdrawReasons({ data, error }) {
    if (data) {
      this.withdrawPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    } else if (error) {
      this._withdrawError = 'Unable to load withdrawal reasons.';
    }
  }

  get showEditButtons() {
    return !this.readOnly;
  }

  get showStudentEditButton() {
    return !this.readOnly && !this.postSubmitMode;
  }

  get showSchoolsEditButton() {
    return !this.readOnly && !this.postSubmitMode;
  }

  get showApplicationEditButton() {
    return !this.readOnly && !this.postSubmitMode;
  }

  get showSiblingsEditButton() {
    return !this.readOnly && !this.postSubmitMode;
  }

  get showUpdateRankingsButton() {
    return (
      this.postSubmitMode &&
      !this.timelineClosed &&
      this.applicationStatus !== 'Withdrawn/Declined'
    );
  }

  schools = [];
  attendingSiblings = [];
  applyingSiblings = [];
  hasResidencyWarning = false;
  residencyRequiresCityOnly = false;
  _studentName = '';
  _studentDob = '';
  _studentGrade = '';
  _studentAddress = '';
  wiredBundleResult;
  // Guards the one-time, cache-bypassing re-fetch on (re)mount (see wiredBundle).
  _didInitialRefresh = false;
  // Stays false until that initial re-fetch lands. isLoading keys off it so the
  // skeleton holds — the stale cached snapshot is applied but never painted.
  _initialRefreshDone = false;

  labels = {
    schoolRankings: labelSchoolRankings,
    applicationDetails: labelApplicationDetails,
    siblings: labelSiblings,
    siblingsAttending: labelSiblingsAttending,
    siblingsApplying: labelSiblingsApplying,
    edit: labelEdit,
    updateRankings: labelUpdateRankings,
    name: labelName,
    dateOfBirth: labelDateOfBirth,
    gender: labelGender,
    zetaSchool: labelZetaSchool,
    lotteryMessage: labelLotteryMessage,
    studentInfo: labelStudentInfo,
    grade: labelGrade,
    address: labelAddress,
    ariaLoadingReview: labelAriaLoadingReview
  };

  get showLotteryMessage() {
    return !!this.labels.lotteryMessage;
  }

  get hasWarnings() {
    return this.hasResidencyWarning;
  }

  get residencyWarningMessage() {
    // Pre-K only requires NYC residency; K-9 (and up) require NY State.
    return this.residencyRequiresCityOnly
      ? labelResidencyWarning
      : labelResidencyWarningState;
  }

  get isLoading() {
    // Hold the skeleton until the initial cache-bypassing re-fetch resolves so
    // a stale sibling list never flashes before correcting (see wiredBundle).
    if (!this._initialRefreshDone) {
      return true;
    }
    return (
      !this.wiredBundleResult ||
      (!this.wiredBundleResult.data && !this.wiredBundleResult.error)
    );
  }

  @wire(getReviewBundle, { applicationId: '$recordId' })
  wiredBundle(result) {
    this.wiredBundleResult = result;
    if (result.data) {
      this._applyBundle(result.data);
    }
    if (result.error) {
      console.error('Failed to load review bundle:', result.error);
    }
    // getReviewBundle is cacheable, so the first provision after (re)mount may
    // be a stale LDS snapshot — siblings selected/deselected on step 4 commit
    // via a non-cacheable call LDS never observes. This component is destroyed/
    // recreated on every step-5 entry, so force exactly one cache-bypassing
    // re-fetch on that first provision. We DO apply the stale snapshot (so a
    // missed re-emit can never leave the review blank) but keep the loading
    // skeleton up via _initialRefreshDone until the fresh result lands — so the
    // pre-edit sibling list is never actually painted and there's no flash.
    if (!this._didInitialRefresh && (result.data || result.error)) {
      this._didInitialRefresh = true;
      refreshApex(this.wiredBundleResult)
        .catch((err) => {
          console.error('Failed to refresh review bundle:', err);
        })
        .finally(() => {
          this._initialRefreshDone = true;
        });
    }
  }

  /**
   * Forces a server re-fetch of the review bundle, bypassing the LDS cache.
   *
   * getReviewBundle is @AuraEnabled(cacheable=true) so the @wire serves a
   * cached snapshot on (re)mount. Sibling selection on step 4 commits via a
   * non-cacheable Apex call (SiblingSectionController.setApplyingSiblingSelected)
   * that LDS does not observe, so the cache goes stale. The component already
   * self-refreshes on mount (see wiredBundle); this @api lets zetaApplication
   * also nudge a refresh on step-5 entry as a belt-and-suspenders safeguard.
   */
  @api
  refresh() {
    if (!this.wiredBundleResult) {
      return Promise.resolve();
    }
    return refreshApex(this.wiredBundleResult);
  }

  _applyBundle(data) {
    const {
      schools,
      siblings,
      applicationStudent,
      students,
      submissionWarnings
    } = data;

    this.hasResidencyWarning = submissionWarnings?.hasResidencyWarning === true;
    this.residencyRequiresCityOnly =
      submissionWarnings?.residencyRequiresCityOnly === true;

    if (applicationStudent?.studentAccountId) {
      const match = (students || []).find(
        (s) => s.id === applicationStudent.studentAccountId
      );
      if (match) {
        this._studentName =
          `${match.firstName || ''} ${match.lastName || ''}`.trim();
        this._studentDob = match.birthdate || '';
        this._studentAddress = match.address || '';
      }
      this._studentGrade =
        applicationStudent.gradeLabel || applicationStudent.grade || '';
    }

    this.schools = (schools || []).map((s) => ({
      ...s,
      rank: s.rank != null ? String(s.rank) : '--'
    }));

    const attending = [];
    const applying = [];
    for (const item of siblings || []) {
      const row = {
        id: item.Id,
        firstName: item.First_Name__c || '',
        lastName: item.Last_Name__c || '',
        dateOfBirth: item.Date_of_Birth__c || '',
        gender: item.Gender__c || '',
        zetaSchool: item.Sibling_s_Zeta_School__c || ''
      };
      if (item.Priority_Type__c === 'Sibling Attending') {
        attending.push(row);
      } else {
        applying.push(row);
      }
    }
    this.attendingSiblings = attending;
    this.applyingSiblings = applying;
  }

  get hasStudentInfo() {
    return !!this._studentName;
  }

  get studentName() {
    return this._studentName;
  }

  get studentDob() {
    return this._studentDob;
  }

  get studentGrade() {
    return this._studentGrade;
  }

  get studentAddress() {
    return this._studentAddress;
  }

  get hasSchools() {
    return this.schools.length > 0;
  }

  // Decorates each ranked school with per-row withdraw state. A getter (vs.
  // baking these into `schools`) so the open-menu highlight recomputes whenever
  // `_openMenuAiId` changes. Per-school withdraw is a post-submission action,
  // gated like the "Update Rankings" link plus the row's own status.
  get schoolsForDisplay() {
    const canWithdrawBase =
      this.postSubmitMode &&
      !this.timelineClosed &&
      this.applicationStatus !== 'Withdrawn/Declined';
    return this.schools.map((s) => {
      const isWithdrawn = s.status === 'Withdrawn/Declined';
      return {
        ...s,
        isWithdrawn,
        canWithdraw: canWithdrawBase && !isWithdrawn,
        menuOpen: s.academicInterestId === this._openMenuAiId,
        rowClass: isWithdrawn
          ? 'ranking-row ranking-row--withdrawn'
          : 'ranking-row'
      };
    });
  }

  get showWithdrawReasonText() {
    return this._withdrawPicklistValue === 'Other';
  }

  get withdrawConfirmDisabled() {
    if (this._isWithdrawing) {
      return true;
    }
    if (!this._withdrawPicklistValue) {
      return true;
    }
    if (this.showWithdrawReasonText && !this._withdrawReason?.trim()) {
      return true;
    }
    return false;
  }

  get withdrawModalBody() {
    const student = this._studentName || 'this student';
    return `This will withdraw ${student}'s application to ${this._withdrawSchoolName}. This action cannot be undone.`;
  }

  get hasAttendingSiblings() {
    return this.attendingSiblings.length > 0;
  }

  get hasApplyingSiblings() {
    return this.applyingSiblings.length > 0;
  }

  get hasSiblings() {
    return this.hasAttendingSiblings || this.hasApplyingSiblings;
  }

  get showContent() {
    return !this.isLoading;
  }

  handleEditStudent() {
    this.dispatchEvent(
      new CustomEvent('navigatestep', {
        detail: { step: 1 },
        bubbles: true,
        composed: true
      })
    );
  }

  handleEditSchools() {
    this.dispatchEvent(
      new CustomEvent('navigatestep', {
        detail: { step: 3 },
        bubbles: true,
        composed: true
      })
    );
  }

  handleEditApplication() {
    this.dispatchEvent(
      new CustomEvent('navigatestep', {
        detail: { step: 4 },
        bubbles: true,
        composed: true
      })
    );
  }

  handleEditSiblings() {
    this.dispatchEvent(
      new CustomEvent('navigatestep', {
        detail: { step: 4 },
        bubbles: true,
        composed: true
      })
    );
  }

  // --- Per-school withdraw handlers ------------------------------------------
  handleKebabClick(event) {
    event.stopPropagation();
    const aiId = event.currentTarget.dataset.id;
    this._openMenuAiId = this._openMenuAiId === aiId ? null : aiId;
  }

  handleMenuBackdropClick() {
    this._openMenuAiId = null;
  }

  handleModalClick(event) {
    // Keep clicks inside the dialog from bubbling to the backdrop (which cancels).
    event.stopPropagation();
  }

  handleWithdrawClick(event) {
    const aiId = event.currentTarget.dataset.id;
    const school = this.schools.find((s) => s.academicInterestId === aiId);
    this._withdrawAiId = aiId;
    this._withdrawSchoolName = school ? school.name : '';
    this._withdrawPicklistValue = '';
    this._withdrawReason = '';
    this._withdrawError = null;
    this._isWithdrawing = false;
    this._openMenuAiId = null;
    this.showWithdrawModal = true;
  }

  handleWithdrawPicklistChange(event) {
    this._withdrawPicklistValue = event.detail.value;
    if (!this.showWithdrawReasonText) {
      this._withdrawReason = '';
    }
    if (this._withdrawError) {
      this._withdrawError = null;
    }
  }

  handleWithdrawReasonChange(event) {
    this._withdrawReason = event.target.value;
    if (this._withdrawError) {
      this._withdrawError = null;
    }
  }

  async handleWithdrawConfirm() {
    if (this.withdrawConfirmDisabled) {
      return;
    }
    this._isWithdrawing = true;
    this._withdrawError = null;
    try {
      await withdrawSchoolApplication({
        academicInterestId: this._withdrawAiId,
        picklistReason: this._withdrawPicklistValue,
        reason: this.showWithdrawReasonText ? this._withdrawReason.trim() : null
      });
      this.showWithdrawModal = false;
      this._withdrawAiId = null;
      this._withdrawSchoolName = '';
      this._withdrawPicklistValue = '';
      this._withdrawReason = '';
      // getReviewBundle is cacheable; bypass the cache so the withdrawn school
      // re-renders with its badge and a disabled kebab.
      await this.refresh();
    } catch (err) {
      this._withdrawError =
        err?.body?.message ||
        err?.message ||
        'Unable to withdraw school application.';
    } finally {
      this._isWithdrawing = false;
    }
  }

  handleWithdrawCancel() {
    if (this._isWithdrawing) {
      return;
    }
    this.showWithdrawModal = false;
    this._withdrawAiId = null;
    this._withdrawSchoolName = '';
    this._withdrawPicklistValue = '';
    this._withdrawReason = '';
    this._withdrawError = null;
    this._openMenuAiId = null;
  }
}