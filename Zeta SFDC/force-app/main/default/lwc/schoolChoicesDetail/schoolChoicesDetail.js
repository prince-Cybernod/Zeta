import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import acceptOffer from '@salesforce/apex/SchoolApplicationDecisionController.acceptOffer';
import declineOffer from '@salesforce/apex/SchoolApplicationDecisionController.declineOffer';
import getStudentFirstName from '@salesforce/apex/SchoolApplicationDecisionController.getStudentFirstName';
import getRankedSchools from '@salesforce/apex/SchoolRankingController.getRankedSchools';
import withdrawSchoolApplication from '@salesforce/apex/SchoolRankingController.withdrawSchoolApplication';

import labelAcceptConfirmationBody from '@salesforce/label/c.AppUI_AcceptConfirmationBody';
import labelAcceptConfirmationTitle from '@salesforce/label/c.AppUI_AcceptConfirmationTitle';
import labelAcceptSeat from '@salesforce/label/c.AppUI_AcceptSeat';
import labelAcceptThisSchool from '@salesforce/label/c.AppUI_AcceptThisSchool';
import labelAcceptWarningBody from '@salesforce/label/c.AppUI_AcceptWarningBody';
import labelAcceptWarningTitle from '@salesforce/label/c.AppUI_AcceptWarningTitle';
import labelCancel from '@salesforce/label/c.AppUI_Cancel';
import labelCurrentOffer from '@salesforce/label/c.AppUI_CurrentOffer';
import labelDeclineCommentsLabel from '@salesforce/label/c.AppUI_DeclineCommentsLabel';
import labelDeclineConfirmationBody from '@salesforce/label/c.AppUI_DeclineConfirmationBody';
import labelDeclineConfirmationTitle from '@salesforce/label/c.AppUI_DeclineConfirmationTitle';
import labelDeclineReasonPrompt from '@salesforce/label/c.AppUI_DeclineReasonPrompt';
import labelDeclineSeat from '@salesforce/label/c.AppUI_DeclineSeat';
import labelDetailsFieldLabel from '@salesforce/label/c.AppUI_DetailsFieldLabel';
import labelDone from '@salesforce/label/c.AppUI_Done';
import labelLoading from '@salesforce/label/c.AppUI_Loading';
import labelLowerRankedOffers from '@salesforce/label/c.AppUI_LowerRankedOffers';
import labelMoreActions from '@salesforce/label/c.AppUI_MoreActions';
import labelReasonFieldLabel from '@salesforce/label/c.AppUI_ReasonFieldLabel';
import labelRespondByPrefix from '@salesforce/label/c.AppUI_RespondByPrefix';
import labelSeatAcceptedSection from '@salesforce/label/c.AppUI_SeatAcceptedSection';
import labelUpdateRankings from '@salesforce/label/c.AppUI_UpdateRankings';
import labelWaitlisted from '@salesforce/label/c.AppUI_WaitlistedSection';
import labelWithdraw from '@salesforce/label/c.AppUI_Withdraw';
import labelWithdrawApplicationMenuItem from '@salesforce/label/c.AppUI_WithdrawApplicationMenuItem';
import labelWithdrawConfirmTitle from '@salesforce/label/c.AppUI_WithdrawConfirmTitle';
import ACADEMIC_INTEREST_OBJECT from '@salesforce/schema/AcademicInterest';
import REASON_FIELD from '@salesforce/schema/AcademicInterest.Withdrawn_Declined_Reason_Picklist__c';

const NULL_RECORD_TYPE_ID = '012000000000000AAA';

// Org Status -> section/key, the single source both this component and the
// Apex accept/decline eligibility check agree with. There is no org Status
// matching the wireframe's 'notreached'/'contact' keys, so those
// are dropped: Lower Ranked Offers is exactly the non-primary offer-bucket
// rows, nothing else.
const OFFER_STATUSES = new Set([
  'Seat Offered',
  'Offer Rescinded due to Seat Optimization'
]);

function formatRespondByDate(isoValue) {
  if (!isoValue) {
    return null;
  }
  // A date-only value parses as UTC midnight; formatting in the viewer's zone
  // would show the previous day anywhere west of UTC.
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeZone: 'UTC'
  }).format(new Date(isoValue));
}

function formatLabel(template, ...values) {
  return template.replace(/\{(\d+)\}/g, (match, index) => {
    return values[index] ?? match;
  });
}

function badgeClassFor(status) {
  return status === 'Seat Accepted'
    ? 'badge-tag badge-tag--accepted'
    : 'badge-tag';
}

export default class SchoolChoicesDetail extends LightningElement {
  // Internal lightning__RecordPage target populates this automatically.
  @api recordId;

  // Portal target: the parent dashboard supplies the application Id.
  @api
  get applicationId() {
    return this._applicationId;
  }
  set applicationId(value) {
    this._applicationId = value;
    if (this._connected) {
      this._loadIfReady();
    }
  }

  _applicationId;
  _connected = false;

  _loadedForAppId;
  isLoading = true;
  loadError = null;
  schools = [];
  _studentFirstName = '';

  _openMenuAiId = null;

  showUpdateRankings = false;
  showAcceptWarning = false;
  showDeclineForm = false;
  showWithdrawModal = false;
  showAcceptConfirmation = false;
  showDeclineConfirmation = false;
  _actingOnAiId = null;
  _declinePicklistValue = '';
  _declineReason = '';
  _withdrawPicklistValue = '';
  _withdrawReason = '';
  _actionError = null;
  _isActing = false;
  _reasonRecordTypeId = NULL_RECORD_TYPE_ID;
  withdrawPicklistOptions = [];

  labels = {
    currentOffer: labelCurrentOffer,
    lowerRankedOffers: labelLowerRankedOffers,
    seatAccepted: labelSeatAcceptedSection,
    waitlisted: labelWaitlisted,
    acceptSeat: labelAcceptSeat,
    declineSeat: labelDeclineSeat,
    acceptThisSchool: labelAcceptThisSchool,
    respondByPrefix: labelRespondByPrefix,
    acceptWarningTitle: labelAcceptWarningTitle,
    acceptWarningBody: labelAcceptWarningBody,
    declineReasonPrompt: labelDeclineReasonPrompt,
    declineCommentsLabel: labelDeclineCommentsLabel,
    acceptConfirmationTitle: labelAcceptConfirmationTitle,
    acceptConfirmationBody: labelAcceptConfirmationBody,
    declineConfirmationTitle: labelDeclineConfirmationTitle,
    declineConfirmationBody: labelDeclineConfirmationBody,
    updateRankings: labelUpdateRankings,
    loading: labelLoading,
    done: labelDone,
    withdrawApplicationMenuItem: labelWithdrawApplicationMenuItem,
    withdrawConfirmTitle: labelWithdrawConfirmTitle,
    withdraw: labelWithdraw,
    cancel: labelCancel,
    reasonFieldLabel: labelReasonFieldLabel,
    detailsFieldLabel: labelDetailsFieldLabel,
    moreActions: labelMoreActions
  };

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
  wiredReasons({ data }) {
    if (data) {
      this.withdrawPicklistOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    }
  }

  get effectiveAppId() {
    return this.recordId || this.applicationId;
  }

  connectedCallback() {
    this._connected = true;
    this._loadIfReady();
  }

  _loadIfReady() {
    const appId = this.effectiveAppId;
    if (!appId || appId === this._loadedForAppId) {
      return;
    }
    this._loadedForAppId = appId;
    this._load(appId);
  }

  // quiet: refresh after a failed action without the loading swap, keeping the
  // current rows and the action error if the refresh itself fails.
  async _load(appId, { quiet = false } = {}) {
    if (!quiet) {
      this.isLoading = true;
      this.loadError = null;
    }
    try {
      const [rows, firstName] = await Promise.all([
        getRankedSchools({ applicationId: appId }),
        getStudentFirstName({ applicationId: appId }).catch(() => '')
      ]);
      this._studentFirstName = firstName || '';
      this.schools = (rows || []).map((s) => ({
        ...s,
        isOfferEligible: OFFER_STATUSES.has(s.status)
      }));
    } catch (err) {
      if (!quiet) {
        this.loadError =
          err?.body?.message ||
          err?.message ||
          'Unable to load school choices.';
      }
    } finally {
      if (!quiet) {
        this.isLoading = false;
      }
    }
  }

  get offerRows() {
    return this.schools.filter((s) => s.isOfferEligible);
  }

  get primaryOffer() {
    const offers = this.offerRows;
    if (offers.length === 0) {
      return null;
    }
    return offers.reduce((min, s) => (s.rank < min.rank ? s : min), offers[0]);
  }

  get currentOfferRows() {
    const primary = this.primaryOffer;
    if (!primary) {
      return [];
    }
    return [
      {
        ...primary,
        respondBy: formatRespondByDate(primary.offerExpirationDate)
      }
    ];
  }

  get lowerRankedOfferRows() {
    const primary = this.primaryOffer;
    return this.offerRows.filter(
      (s) => !primary || s.academicInterestId !== primary.academicInterestId
    );
  }

  get waitlistedRows() {
    return this.schools
      .filter((s) => s.status === 'Waitlisted')
      .map((s) => ({
        ...s,
        menuOpen: s.academicInterestId === this._openMenuAiId
      }));
  }

  get acceptedRows() {
    return this.schools
      .filter((s) => s.status === 'Seat Accepted')
      .map((s) => ({ ...s, statusClass: badgeClassFor(s.status) }));
  }

  get hasAcceptedRows() {
    return this.acceptedRows.length > 0;
  }

  get otherRows() {
    return this.schools
      .filter(
        (s) =>
          !s.isOfferEligible &&
          s.status !== 'Waitlisted' &&
          s.status !== 'Seat Accepted'
      )
      .map((s) => ({ ...s, statusClass: badgeClassFor(s.status) }));
  }

  get acceptWarningBody() {
    const acting = this.schools.find(
      (s) => s.academicInterestId === this._actingOnAiId
    );
    return formatLabel(
      this.labels.acceptWarningBody,
      acting?.name || '',
      this._studentFirstName
    );
  }

  get declineReasonPrompt() {
    const acting = this.schools.find(
      (s) => s.academicInterestId === this._actingOnAiId
    );
    return formatLabel(this.labels.declineReasonPrompt, acting?.name || '');
  }

  get hasCurrentOffer() {
    return this.currentOfferRows.length > 0;
  }

  get hasLowerRankedOffers() {
    return this.lowerRankedOfferRows.length > 0;
  }

  get hasWaitlisted() {
    return this.waitlistedRows.length > 0;
  }

  get hasOpenChoices() {
    return (
      this.hasCurrentOffer || this.hasLowerRankedOffers || this.hasWaitlisted
    );
  }

  get hasOtherRows() {
    return this.otherRows.length > 0;
  }

  // The withdraw menu reuses confirmationReview's withdraw logic, which calls
  // SchoolRankingController.withdrawSchoolApplication — its ownership check
  // always fails for an internal/no-session caller (it hardcodes
  // resolveGuardianContactId(databaseRepo, null)). So the menu is portal-only
  // until that method is made recordId-aware too.
  get isPortalTarget() {
    return !this.recordId;
  }

  get showWithdrawReasonText() {
    return this._withdrawPicklistValue === 'Other';
  }

  get showDeclineReasonText() {
    return this._declinePicklistValue === 'Other';
  }

  get declineConfirmDisabled() {
    if (this._isActing || !this._declinePicklistValue) {
      return true;
    }
    return this.showDeclineReasonText && !this._declineReason?.trim();
  }

  get withdrawConfirmDisabled() {
    if (this._isActing || !this._withdrawPicklistValue) {
      return true;
    }
    return this.showWithdrawReasonText && !this._withdrawReason?.trim();
  }

  handleOpenUpdateRankings(event) {
    event.preventDefault();
    this.showUpdateRankings = true;
  }

  async handleDoneRanking() {
    await this.refs.ranking?.flushAndSave();
    this.showUpdateRankings = false;
    await this._load(this.effectiveAppId);
  }

  handleAcceptClick(event) {
    this._actingOnAiId = event.currentTarget.dataset.id;
    this._actionError = null;
    this.showAcceptWarning = true;
  }

  handleAcceptCancel() {
    this.showAcceptWarning = false;
    this._actingOnAiId = null;
  }

  async handleAcceptConfirm() {
    this._isActing = true;
    this._actionError = null;
    try {
      await acceptOffer({
        applicationId: this.effectiveAppId,
        academicInterestId: this._actingOnAiId
      });
      this.showAcceptWarning = false;
      this.showAcceptConfirmation = true;
      await this._load(this.effectiveAppId);
    } catch (err) {
      this.showAcceptWarning = false;
      this._actionError =
        err?.body?.message || err?.message || 'Unable to accept this offer.';
      await this._load(this.effectiveAppId, { quiet: true });
    } finally {
      this._isActing = false;
    }
  }

  handleDeclineClick(event) {
    this._actingOnAiId = event.currentTarget.dataset.id;
    this._declinePicklistValue = '';
    this._declineReason = '';
    this._actionError = null;
    this.showDeclineForm = true;
  }

  handleDeclinePicklistChange(event) {
    this._declinePicklistValue = event.detail.value;
  }

  handleDeclineReasonChange(event) {
    this._declineReason = event.target.value;
  }

  handleDeclineCancel() {
    this.showDeclineForm = false;
    this._actingOnAiId = null;
  }

  async handleDeclineConfirm() {
    if (this.declineConfirmDisabled) {
      return;
    }
    this._isActing = true;
    this._actionError = null;
    try {
      await declineOffer({
        applicationId: this.effectiveAppId,
        academicInterestId: this._actingOnAiId,
        picklistReason: this._declinePicklistValue,
        reason: this._declineReason.trim() || null
      });
      this.showDeclineForm = false;
      this.showDeclineConfirmation = true;
      await this._load(this.effectiveAppId);
    } catch (err) {
      this.showDeclineForm = false;
      this._actionError =
        err?.body?.message || err?.message || 'Unable to decline this offer.';
      await this._load(this.effectiveAppId, { quiet: true });
    } finally {
      this._isActing = false;
    }
  }

  handleKebabClick(event) {
    event.stopPropagation();
    const aiId = event.currentTarget.dataset.id;
    this._openMenuAiId = this._openMenuAiId === aiId ? null : aiId;
  }

  handleMenuBackdropClick() {
    this._openMenuAiId = null;
  }

  handleModalClick(event) {
    event.stopPropagation();
  }

  handleWithdrawClick(event) {
    this._actingOnAiId = event.currentTarget.dataset.id;
    this._withdrawPicklistValue = '';
    this._withdrawReason = '';
    this._actionError = null;
    this._openMenuAiId = null;
    this.showWithdrawModal = true;
  }

  handleWithdrawPicklistChange(event) {
    this._withdrawPicklistValue = event.detail.value;
    if (!this.showWithdrawReasonText) {
      this._withdrawReason = '';
    }
  }

  handleWithdrawReasonChange(event) {
    this._withdrawReason = event.target.value;
  }

  handleWithdrawCancel() {
    this.showWithdrawModal = false;
    this._actingOnAiId = null;
  }

  async handleWithdrawConfirm() {
    if (this.withdrawConfirmDisabled) {
      return;
    }
    this._isActing = true;
    this._actionError = null;
    try {
      await withdrawSchoolApplication({
        academicInterestId: this._actingOnAiId,
        picklistReason: this._withdrawPicklistValue,
        reason: this.showWithdrawReasonText ? this._withdrawReason.trim() : null
      });
      this.showWithdrawModal = false;
      await this._load(this.effectiveAppId);
    } catch (err) {
      this.showWithdrawModal = false;
      this._actionError =
        err?.body?.message ||
        err?.message ||
        'Unable to withdraw this school application.';
      await this._load(this.effectiveAppId, { quiet: true });
    } finally {
      this._isActing = false;
    }
  }
}