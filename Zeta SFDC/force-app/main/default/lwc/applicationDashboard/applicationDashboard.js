import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import REASON_FIELD from '@salesforce/schema/IndividualApplication.Withdrawn_Declined_Reason_Picklist__c';
import getDashboardData from '@salesforce/apex/ApplicationDashboardController.getDashboardData';
import withdrawApplication from '@salesforce/apex/ApplicationDashboardController.withdrawApplication';

// Master record type id — Salesforce's sentinel for "the object has no record
// types", used as the getPicklistValues fallback when getObjectInfo reports no
// default. IndividualApplication is single-record-type, so the default is the
// right value set; this keeps the wire valid if that ever changes.
const NULL_RECORD_TYPE_ID = '012000000000000AAA';

// Top-to-bottom application display order, keyed by the normalized statusKey
// that also drives the badge a parent sees (see _statusKey) — NOT the raw
// Status picklist. Ranking off raw Status let a card sort into a tier its badge
// never claimed whenever Status and AppliedDate disagreed: e.g. Status='Applied'
// with no AppliedDate renders "In Progress" yet used to sort into the Applied
// tier, and Status='Draft' with an AppliedDate renders "Applied" yet sorted into
// the Draft tier. Keys are statusKey values; any unlisted key sits in a middle
// band so it never jumps above the ranked tiers, and withdrawn sinks to the
// bottom.
const STATUS_RANK = {
  draft: 0,
  applied: 1,
  eligible: 2
};
const DEFAULT_STATUS_RANK = 3; // any unlisted statusKey
const WITHDRAWN_RANK = 99;

function statusRank(statusKey) {
  if (statusKey === 'withdrawn') return WITHDRAWN_RANK;
  const rank = STATUS_RANK[statusKey];
  return rank === undefined ? DEFAULT_STATUS_RANK : rank;
}

export default class ApplicationDashboard extends LightningElement {
  @api variant;
  @api pageDevName = 'Application_Details';

  // Which applications this placement shows. Set per Experience Builder
  // placement: 'in-progress' on the Dashboard tab, 'submitted' on the
  // Application Status tab, 'all' (default) shows everything.
  @api view = 'all';
  // Hide the navy "My Applications" header bar. Turn on for the Dashboard
  // (it sits under the family welcome); leave off for Application Status.
  // (LWC requires boolean @api props default to false, hence the inverted name.)
  @api hideHeader = false;

  // Show the "Welcome, <Family>!" greeting + intro at the top of the component
  // (Dashboard tab). Off by default.
  @api showWelcome = false;
  @api welcomeMessage =
    'We are delighted to welcome you to your one-stop destination for your child’s enrollment at Zeta.';

  isLoading = true;
  isOpen = false;
  timelineName = '';
  landingContent = null;
  familyName = '';
  applications = [];
  timelines = [];
  showTimelinePicker = false;
  _pickerTimelineId = null;
  showWizard = false;
  _wizardApplicationId;
  _wizardTimelineId;
  _wizardTimelineName = '';
  _wizardForceNew = false;
  showWithdrawModal = false;
  _withdrawAppId = null;
  _withdrawTimelineName = '';
  _withdrawReason = '';
  _withdrawPicklistValue = '';
  withdrawPicklistOptions = [];
  _recordTypeId = NULL_RECORD_TYPE_ID;
  _withdrawError = null;
  _isWithdrawing = false;
  _openMenuAppId = null;

  // Timeline group keys the parent has collapsed. Empty = every group expanded,
  // which is the default Brett asked for. Reassigned (never mutated in place) so
  // the displayGroups getter re-runs on toggle.
  _collapsedGroups = new Set();

  _viewApps = [];
  _displayGroups = [];

  // Withdrawal reasons come from the field's own picklist via the platform UI
  // API — no Apex needed, and record-type-aware. getObjectInfo first resolves
  // the default record type id that getPicklistValues requires.
  @wire(getObjectInfo, { objectApiName: 'IndividualApplication' })
  wiredObjectInfo({ data }) {
    if (data) {
      this._recordTypeId = data.defaultRecordTypeId || NULL_RECORD_TYPE_ID;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_recordTypeId',
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

  async connectedCallback() {
    await this.loadDashboard();
  }

  // Fetch + shape the dashboard data. Extracted so the refresh paths (returning
  // from the wizard, after a withdraw) can re-run it without invoking the
  // lifecycle hook by hand.
  async loadDashboard() {
    this.isLoading = true;
    try {
      const data = await getDashboardData();
      this.timelineName = data.timelineName || '';
      this.landingContent = data.landingContent || null;
      this.familyName = data.familyName || '';
      const deadlineByTimeline = this._buildDeadlineLookup(data.timelines);
      this.applications = (data.applications || []).map((app) => {
        const statusKey = this._statusKey(app);
        const isWithdrawn = statusKey === 'withdrawn';
        const timelineName = app.timelineName || '';
        return {
          ...app,
          statusKey,
          statusTagClass: `badge-tag badge-tag--${statusKey}`,
          statusLabel: this._statusLabel(app),
          isDraft: !app.isSubmitted,
          actionLabel: app.isSubmitted || isWithdrawn ? 'View' : 'Resume',
          actionClass:
            app.isSubmitted || isWithdrawn ? 'btn btn--view' : 'btn btn--edit',
          rowClass: isWithdrawn ? 'app-row app-row--withdrawn' : 'app-row',
          gradeDisplay: app.grade || 'Not selected',
          timelineId: app.timelineId || null,
          timelineOpenDate: app.timelineOpenDate || null,
          timelineName,
          timelineLabel: timelineName ? `${timelineName} Application` : '',
          deadlineDisplay: this._deadlineDisplay(
            app,
            statusKey,
            timelineName,
            deadlineByTimeline
          ),
          canWithdraw: this._isWithdrawable(app)
        };
      });
      this.timelines = (data.timelines || []).filter((tl) => tl.isOpen);
      this.isOpen = this.timelines.length > 0;
      this._viewApps = this._computeViewApps();
      this._displayGroups = this._computeDisplayGroups();
    } catch (err) {
      console.error('Failed to load dashboard:', err);
    } finally {
      this.isLoading = false;
    }
  }

  // Applications scoped to this placement's view, then sorted.
  // Computed once per load (view is a design-time attribute, not a
  // runtime-reactive value), rather than re-filtering on every getter access.
  // 'in-progress' = open/editable drafts; 'submitted' = everything else
  // (Applied, Eligible, Withdrawn); 'all' = everything.
  //
  // Sort keys: the timeline keys (1-3) form a total order so every application
  // sharing a timeline stays contiguous — a prerequisite for the single-scan
  // grouping in _computeDisplayGroups. Status rank (4) orders rows within a
  // timeline; the stable SOQL CreatedDate DESC order breaks any remaining ties.
  _computeViewApps() {
    let list;
    if (this.view === 'in-progress') {
      list = this.applications.filter((a) => a.statusKey === 'draft');
    } else if (this.view === 'submitted') {
      list = this.applications.filter((a) => a.statusKey !== 'draft');
    } else {
      list = this.applications;
    }
    return [...list].sort((a, b) => {
      // 1. timeline open date, most recent first (null dates sink to the bottom)
      const da = a.timelineOpenDate
        ? Date.parse(a.timelineOpenDate)
        : -Infinity;
      const db = b.timelineOpenDate
        ? Date.parse(b.timelineOpenDate)
        : -Infinity;
      if (da !== db) return db - da;
      // 2. tiebreak when open dates are equal: timeline Name, A->Z
      const na = a.timelineName || '';
      const nb = b.timelineName || '';
      if (na !== nb) return na.localeCompare(nb);
      // 3. final contiguity guard: timeline Id (keeps same-date, same-name
      //    timelines as distinct, deterministically-ordered groups)
      const ia = a.timelineId || '';
      const ib = b.timelineId || '';
      if (ia !== ib) return ia < ib ? -1 : 1;
      // 4. status rank within the timeline, ascending. Rank off statusKey (the
      //    badge's source of truth) so a row always sorts into the tier its
      //    badge displays, even when raw Status and AppliedDate disagree.
      const sr = statusRank(a.statusKey) - statusRank(b.statusKey);
      if (sr !== 0) return sr;
      // 5. stable fallback: SOQL CreatedDate DESC order preserved
      return 0;
    });
  }

  // Single header-less group when one timeline; date-ordered header groups when
  // many. Built once from the already-sorted _viewApps (a single linear scan,
  // safe because same-timeline apps are guaranteed contiguous). Group identity
  // is the timeline Id, never the Name — two timelines that share a Name are
  // still two groups.
  _computeDisplayGroups() {
    const apps = this._viewApps;
    const distinct = new Set(apps.map((a) => a.timelineId || '__none__'));
    if (distinct.size <= 1) {
      return [{ key: 'all', showHeader: false, headerLabel: '', apps }];
    }
    const groups = [];
    const byKey = new Map();
    for (const app of apps) {
      const key = app.timelineId || '__none__';
      let group = byKey.get(key);
      if (!group) {
        group = {
          key,
          showHeader: true,
          headerLabel: app.timelineName || 'Other Applications',
          apps: []
        };
        byKey.set(key, group);
        groups.push(group);
      }
      group.apps.push(app);
    }
    return groups;
  }

  get viewApps() {
    return this._viewApps;
  }

  get showHeader() {
    return !this.hideHeader;
  }

  get hasApplications() {
    return this.viewApps.length > 0;
  }

  get displayApps() {
    return this.viewApps.map((app) => ({
      ...app,
      menuOpen: app.id === this._openMenuAppId
    }));
  }

  // Cheap per-render getter: the bucket/sort work already ran once at load
  // (_computeDisplayGroups); here we only stamp the reactive per-render flags
  // (group collapse state + leaf menuOpen) without recomputing groups.
  get displayGroups() {
    return this._displayGroups.map((group) => {
      const collapsed = this._collapsedGroups.has(group.key);
      return {
        ...group,
        collapsed,
        expanded: !collapsed,
        listId: `app-group-${group.key}`,
        chevronClass: collapsed
          ? 'group-chevron group-chevron--collapsed'
          : 'group-chevron',
        apps: group.apps.map((app) => ({
          ...app,
          menuOpen: app.id === this._openMenuAppId
        }))
      };
    });
  }

  // Collapse/expand a timeline group by its key (the timeline Id). Reassigns the
  // Set so the displayGroups getter recomputes; only the group's own apps hide.
  handleToggleGroup(event) {
    const key = event.currentTarget.dataset.key;
    if (key === undefined || key === null) return;
    const next = new Set(this._collapsedGroups);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this._collapsedGroups = next;
  }

  get isFilteredView() {
    return this.view === 'in-progress' || this.view === 'submitted';
  }

  get showFilteredEmpty() {
    return !this.isLoading && this.isFilteredView && !this.hasApplications;
  }

  get filteredEmptyText() {
    return this.view === 'in-progress'
      ? "You don't have any applications in progress."
      : 'No submitted applications yet.';
  }

  // On the in-progress (Dashboard) view, the empty state still offers a way to
  // start a new application so parents never have to leave the tab.
  get showFilteredEmptyCta() {
    return this.view === 'in-progress' && this.showStartNew;
  }

  get showWelcomeBlock() {
    return this.showWelcome && !this.isLoading;
  }

  get welcomeGreeting() {
    return this.familyName ? `Welcome, ${this.familyName}!` : 'Welcome!';
  }

  get showStartNew() {
    return this.isOpen;
  }

  get hasLandingContent() {
    return !!this.landingContent;
  }

  get showClosedMessage() {
    // The closed banner is about starting NEW applications; it only belongs on
    // the default (all) view, not the filtered Dashboard / Status placements.
    return !this.isFilteredView && !this.isOpen;
  }

  get showEmptyOpen() {
    return !this.isFilteredView && this.isOpen && !this.hasApplications;
  }

  get showEmptyClosed() {
    return !this.isFilteredView && !this.isOpen && !this.hasApplications;
  }

  get hasMultipleTimelines() {
    return this.timelines.length > 1;
  }

  get pickerContinueDisabled() {
    return !this._pickerTimelineId;
  }

  get pickerOptions() {
    return this.timelines.map((tl) => {
      const isSelected = tl.id === this._pickerTimelineId;
      const openDate = tl.openDate
        ? new Date(tl.openDate).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric'
          })
        : '';
      const closeDate = tl.closeDate
        ? new Date(tl.closeDate).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
          })
        : 'Open';
      return {
        ...tl,
        isSelected,
        dateRange:
          openDate && closeDate ? `${openDate} \u2013 ${closeDate}` : '',
        pickerClass: `picker-option${isSelected ? ' picker-option--selected' : ''}`
      };
    });
  }

  // Eligible is checked before the generic isSubmitted -> 'applied' fallback:
  // an Eligible application has an AppliedDate (so isSubmitted is true), and we
  // want it to surface its own status/badge rather than collapse into 'applied'.
  _statusKey(app) {
    if (app.status === 'Withdrawn/Declined') return 'withdrawn';
    if (app.status === 'Eligible') return 'eligible';
    if (app.isSubmitted) return 'applied';
    return 'draft';
  }

  _statusLabel(app) {
    if (app.status === 'Withdrawn/Declined') return 'Withdrawn';
    if (app.status === 'Eligible') return 'Eligible';
    if (app.isSubmitted) return 'Applied';
    return 'In Progress';
  }

  _isWithdrawable(app) {
    return app.status === 'Draft' || app.status === 'Applied';
  }

  _buildDeadlineLookup(timelines) {
    const lookup = {};
    (timelines || []).forEach((tl) => {
      if (tl.name && tl.closeDate) {
        lookup[tl.name] = tl.closeDate;
      }
    });
    return lookup;
  }

  // Only in-progress (editable) applications surface a submission deadline,
  // and only when the timeline's close date is available in the payload.
  _deadlineDisplay(app, statusKey, timelineName, lookup) {
    if (statusKey !== 'draft') return '';
    const closeDate = lookup[timelineName];
    if (!closeDate) return '';
    const formatted = new Date(closeDate).toLocaleDateString('en-US', {
      month: '2-digit',
      day: '2-digit',
      year: 'numeric'
    });
    return `Submission deadline is ${formatted}`;
  }

  // "Other" reveals the free-text field; every other value hides it.
  get showWithdrawReasonText() {
    return this._withdrawPicklistValue === 'Other';
  }

  get withdrawConfirmDisabled() {
    if (this._isWithdrawing) return true;
    if (!this._withdrawPicklistValue) return true;
    // When "Other" is selected the free-text detail is also required.
    if (this.showWithdrawReasonText && !this._withdrawReason?.trim()) {
      return true;
    }
    return false;
  }

  get withdrawModalBody() {
    // Name the Application Timeline (enrollment cycle) being withdrawn from, not
    // the student — the withdraw is launched from a specific application card
    // that already shows the student's name.
    const timeline = this._withdrawTimelineName
      ? ` for ${this._withdrawTimelineName}`
      : '';
    return `This action cannot be undone. Your application${timeline} will be withdrawn.`;
  }

  handleStartNew() {
    if (this.hasMultipleTimelines) {
      this._pickerTimelineId = null;
      this.showTimelinePicker = true;
      return;
    }
    this._launchWizard(this.timelines[0]?.id);
  }

  handlePickTimeline(event) {
    this._pickerTimelineId = event.currentTarget.dataset.id;
  }

  handlePickerContinue() {
    if (!this._pickerTimelineId) return;
    this.showTimelinePicker = false;
    this._launchWizard(this._pickerTimelineId);
  }

  handleCloseTimelinePicker() {
    this.showTimelinePicker = false;
  }

  handleModalClick(event) {
    event.stopPropagation();
  }

  _launchWizard(timelineId) {
    const selectedTl = this.timelines.find((tl) => tl.id === timelineId);
    this._wizardApplicationId = undefined;
    this._wizardTimelineId = timelineId;
    this._wizardTimelineName = selectedTl ? selectedTl.name : '';
    this._wizardForceNew = true;
    this.showWizard = true;
  }

  handleOpenApplication(event) {
    this._wizardApplicationId = event.currentTarget.dataset.id;
    this._wizardForceNew = false;
    this._wizardTimelineId = undefined;
    this._wizardTimelineName = this.timelineName;
    this.showWizard = true;
  }

  handleBackToDashboard() {
    this.showWizard = false;
    this._wizardForceNew = false;
    this.loadDashboard();
  }

  handleKebabClick(event) {
    event.stopPropagation();
    const appId = event.currentTarget.dataset.id;
    this._openMenuAppId = this._openMenuAppId === appId ? null : appId;
  }

  handleMenuBackdropClick() {
    this._openMenuAppId = null;
  }

  handleWithdrawClick(event) {
    const appId = event.currentTarget.dataset.id;
    const app = this.applications.find((a) => a.id === appId);
    if (!app) return;
    this._openMenuAppId = null;
    this._withdrawAppId = appId;
    this._withdrawTimelineName = app.timelineName || '';
    this._withdrawReason = '';
    this._withdrawPicklistValue = '';
    this._withdrawError = null;
    this._isWithdrawing = false;
    this.showWithdrawModal = true;
  }

  handleWithdrawPicklistChange(event) {
    this._withdrawPicklistValue = event.detail.value;
    // Drop any stale free-text when switching away from "Other".
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
    if (this.withdrawConfirmDisabled) return;
    this._isWithdrawing = true;
    this._withdrawError = null;
    try {
      await withdrawApplication({
        applicationId: this._withdrawAppId,
        reason: this.showWithdrawReasonText
          ? this._withdrawReason.trim()
          : null,
        picklistReason: this._withdrawPicklistValue
      });
      this.showWithdrawModal = false;
      this._withdrawAppId = null;
      this._withdrawTimelineName = '';
      this._withdrawReason = '';
      this._withdrawPicklistValue = '';
      await this.loadDashboard();
    } catch (err) {
      this._withdrawError =
        err?.body?.message || err?.message || 'Unable to withdraw application.';
    } finally {
      this._isWithdrawing = false;
    }
  }

  handleWithdrawCancel() {
    if (this._isWithdrawing) return;
    this.showWithdrawModal = false;
    this._withdrawAppId = null;
    this._withdrawTimelineName = '';
    this._withdrawReason = '';
    this._withdrawPicklistValue = '';
    this._withdrawError = null;
  }
}