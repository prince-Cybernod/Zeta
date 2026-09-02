import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import PRIORITY_ITEM_OBJECT from '@salesforce/schema/Priority_Item__c';
import ZETA_SCHOOL_FIELD from '@salesforce/schema/Priority_Item__c.Zeta_School__c';
import addManualAttendingSibling from '@salesforce/apex/SiblingSectionController.addManualAttendingSibling';
import createPlaceholderApplications from '@salesforce/apex/SiblingSectionController.createPlaceholderApplications';
import getApplyingSiblingCandidates from '@salesforce/apex/SiblingSectionController.getApplyingSiblingCandidates';
import getAttendingSiblingCandidates from '@salesforce/apex/SiblingSectionController.getAttendingSiblingCandidates';
import getHouseholdSiblingCandidates from '@salesforce/apex/SiblingSectionController.getHouseholdSiblingCandidates';
import setApplyingSiblingSelected from '@salesforce/apex/SiblingSectionController.setApplyingSiblingSelected';
import setAttendingSiblingSelected from '@salesforce/apex/SiblingSectionController.setAttendingSiblingSelected';
import getGradeOptions from '@salesforce/apex/StudentSelectionController.getGradeOptions';
import labelAddAttendingNotListed from '@salesforce/label/c.AppUI_AddAttendingSiblingNotListed';
import labelAddSibling from '@salesforce/label/c.AppUI_AddSibling';
import labelAriaLoadingSiblings from '@salesforce/label/c.AppUI_AriaLoadingSiblings';
import labelHouseholdSiblings from '@salesforce/label/c.AppUI_HouseholdSiblings';
import labelHouseholdSiblingsCreateButton from '@salesforce/label/c.AppUI_HouseholdSiblingsCreateButton';
import labelHouseholdSiblingsGradeColumn from '@salesforce/label/c.AppUI_HouseholdSiblingsGradeColumn';
import labelHouseholdSiblingsHelp from '@salesforce/label/c.AppUI_HouseholdSiblingsHelp';
import labelHouseholdSiblingsNameColumn from '@salesforce/label/c.AppUI_HouseholdSiblingsNameColumn';
import labelHouseholdSiblingsSelectColumn from '@salesforce/label/c.AppUI_HouseholdSiblingsSelectColumn';
import labelHouseholdSiblingsSelectGrade from '@salesforce/label/c.AppUI_HouseholdSiblingsSelectGrade';
import labelHouseholdSiblingsSkipped from '@salesforce/label/c.AppUI_HouseholdSiblingsSkipped';
import labelSiblingsApplying from '@salesforce/label/c.AppUI_SiblingsApplying';
import labelSiblingsApplyingSubtitle from '@salesforce/label/c.AppUI_SiblingsApplyingSubtitle';
import labelSiblingsAttending from '@salesforce/label/c.AppUI_SiblingsAttending';
import labelSiblingsAttendingSubtitle from '@salesforce/label/c.AppUI_SiblingsAttendingSubtitle';

export default class SiblingSection extends LightningElement {
  @api recordId;

  // Retained for backward compatibility with existing markup bindings; neither
  // drives section visibility anymore. Both sibling sections are data-driven:
  // the applying section always shows; the attending section shows when
  // attending siblings are detected. The manual "Sibling Attending Zeta School?"
  // and "Sibling Also Applying?" checkboxes have been removed.
  _siblingAttending = true;
  _siblingApplying = true;

  // Attending: selectable list of siblings already attending a Zeta school,
  // detected from canonical relationship + enrollment data. Each row has a
  // selected flag reflecting an existing Pending "Sibling Attending" Priority_Item__c.
  // attendingCandidates[i] = { accountId, name, selected, rowClass, ariaChecked }
  attendingCandidates = [];

  // Applying: selectable candidate list from canonical Draft IndividualApplications.
  // applyingCandidates[i] = { applicationId, accountId, name, detail, selected, rowClass, ariaChecked }
  applyingCandidates = [];

  applyingFormVisible = false;

  // Household: Student Person Accounts the guardian already added on Step 1 that
  // have no IndividualApplication in this timeline yet (invisible to the applying
  // list because they have no app). Selecting them bulk-creates placeholder apps.
  // householdCandidates[i] = { accountId, displayLabel, checked, gradeApplyingTo,
  //                            gradeError, selectAriaLabel }
  householdCandidates = [];
  householdSubmitting = false;
  householdError = '';
  householdSkippedNames = [];
  gradeOptions = [];
  schoolOptions = [];

  // "Add attending not listed" inline form state
  attendingAddFormVisible = false;
  attendingDraft = {
    firstName: '',
    lastName: '',
    birthdate: '',
    zetaSchool: ''
  };
  attendingAddError = '';
  attendingAddSaving = false;

  isLoading = true;

  labels = {
    siblingsAttending: labelSiblingsAttending,
    siblingsApplying: labelSiblingsApplying,
    siblingsAttendingSubtitle: labelSiblingsAttendingSubtitle,
    siblingsApplyingSubtitle: labelSiblingsApplyingSubtitle,
    addAttendingNotListed: labelAddAttendingNotListed,
    ariaLoadingSiblings: labelAriaLoadingSiblings,
    addSibling: labelAddSibling,
    householdSiblings: labelHouseholdSiblings,
    householdSiblingsHelp: labelHouseholdSiblingsHelp,
    householdSiblingsNameColumn: labelHouseholdSiblingsNameColumn,
    householdSiblingsGradeColumn: labelHouseholdSiblingsGradeColumn,
    householdSiblingsSelectColumn: labelHouseholdSiblingsSelectColumn,
    householdSiblingsCreateButton: labelHouseholdSiblingsCreateButton,
    householdSiblingsSelectGrade: labelHouseholdSiblingsSelectGrade,
    householdSiblingsSkipped: labelHouseholdSiblingsSkipped
  };

  @wire(getGradeOptions)
  wiredGradeOptions({ data }) {
    if (data) {
      this.gradeOptions = data.map((o) => ({ label: o.label, value: o.value }));
    }
  }

  // School options for the "add attending not listed" form come straight from
  // the Priority_Item__c.Zeta_School__c picklist via the platform wire adapter
  // (no Apex). getObjectInfo supplies the default record type id that
  // getPicklistValues requires. N/A and Waitlisted are excluded from the portal.
  @wire(getObjectInfo, { objectApiName: PRIORITY_ITEM_OBJECT })
  priorityItemInfo;

  @wire(getPicklistValues, {
    recordTypeId: '$priorityItemInfo.data.defaultRecordTypeId',
    fieldApiName: ZETA_SCHOOL_FIELD
  })
  wiredSchoolOptions({ data }) {
    if (data) {
      this.schoolOptions = data.values
        .filter((v) => v.value !== 'N/A' && v.value !== 'Waitlisted')
        .map((v) => ({ label: v.label, value: v.value }));
    }
  }

  connectedCallback() {
    this._loadSiblings();
  }

  @api
  get siblingAttending() {
    return this._siblingAttending;
  }

  set siblingAttending(value) {
    this._siblingAttending =
      value === undefined || value === null ? true : value;
  }

  @api
  get siblingApplying() {
    return this._siblingApplying;
  }

  set siblingApplying(value) {
    this._siblingApplying =
      value === undefined || value === null ? true : value;
  }

  get showAttendingSection() {
    // Always show so the "add an attending sibling not listed" button stays
    // available even when no enrollment data is detected for this household —
    // that override exists precisely for the case where nothing is found.
    return true;
  }

  get showApplyingSection() {
    return true;
  }

  get showComponent() {
    return true;
  }

  get showSkeleton() {
    return this.isLoading && this.showComponent;
  }

  get hasAttendingCandidates() {
    return this.attendingCandidates.length > 0;
  }

  get hasApplyingCandidates() {
    return this.applyingCandidates.length > 0;
  }

  get attendingAddSaveDisabled() {
    return (
      this.attendingAddSaving ||
      !this.attendingDraft.firstName ||
      !this.attendingDraft.lastName ||
      !this.attendingDraft.birthdate
    );
  }

  async _loadSiblings() {
    if (!this.recordId) {
      this.isLoading = false;
      return;
    }

    try {
      const [attendingCands, applyingCands, householdCands] = await Promise.all(
        [
          getAttendingSiblingCandidates({ applicationId: this.recordId }),
          getApplyingSiblingCandidates({ applicationId: this.recordId }),
          getHouseholdSiblingCandidates({ applicationId: this.recordId })
        ]
      );

      this.attendingCandidates = attendingCands.map((c) =>
        this._buildAttendingRow(c)
      );

      this.applyingCandidates = applyingCands.map((c) =>
        this._buildApplyingRow(c)
      );

      this.householdCandidates = householdCands.map((c) =>
        this._buildHouseholdRow(c)
      );
    } catch (err) {
      console.error('Failed to load siblings:', err);
    } finally {
      this.isLoading = false;
    }
  }

  _buildAttendingRow(c) {
    const selected = c.selected === true;
    const parts = [];
    if (c.grade) parts.push(`Grade ${c.grade}`);
    if (c.school) parts.push(c.school);
    return {
      accountId: c.accountId,
      name: this._buildName(c.firstName, c.lastName),
      detail: parts.join(' · '),
      selected,
      rowClass: selected
        ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
        : 'candidate-row slds-p-vertical_xx-small',
      ariaChecked: selected ? 'true' : 'false',
      // carry originals for the Apex call
      firstName: c.firstName,
      lastName: c.lastName,
      ateId: c.ateId ?? null
    };
  }

  _buildApplyingRow(c) {
    const selected = c.selected === true;
    return {
      applicationId: c.applicationId,
      accountId: c.accountId,
      name: this._buildName(c.firstName, c.lastName),
      detail: c.gradeApplyingTo ? `Grade ${c.gradeApplyingTo}` : '',
      selected,
      rowClass: selected
        ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
        : 'candidate-row slds-p-vertical_xx-small',
      ariaChecked: selected ? 'true' : 'false',
      firstName: c.firstName,
      lastName: c.lastName,
      gradeApplyingTo: c.gradeApplyingTo
    };
  }

  _buildHouseholdRow(c) {
    const displayLabel = this._buildName(c.firstName, c.lastName);
    return {
      accountId: c.accountId,
      displayLabel,
      checked: false,
      gradeApplyingTo: '',
      gradeError: false,
      selectAriaLabel: `${this.labels.householdSiblingsSelectColumn} ${displayLabel}`
    };
  }

  _buildName(firstName, lastName) {
    const name = [firstName, lastName].filter(Boolean).join(' ').trim();
    return name || '(unnamed sibling)';
  }

  // --- Attending section: row selection ---

  handleAttendingRowClick(event) {
    const accountId = event.currentTarget.dataset.id;
    this._toggleAttendingRow(accountId);
  }

  handleAttendingKeydown(event) {
    if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault();
      const accountId = event.currentTarget.dataset.id;
      this._toggleAttendingRow(accountId);
    }
  }

  async _toggleAttendingRow(accountId) {
    const idx = this.attendingCandidates.findIndex(
      (c) => c.accountId === accountId
    );
    if (idx === -1) return;

    const current = this.attendingCandidates[idx];
    const newSelected = !current.selected;

    // Optimistic update
    const updated = { ...current, selected: newSelected };
    updated.rowClass = newSelected
      ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
      : 'candidate-row slds-p-vertical_xx-small';
    updated.ariaChecked = newSelected ? 'true' : 'false';
    this.attendingCandidates = [
      ...this.attendingCandidates.slice(0, idx),
      updated,
      ...this.attendingCandidates.slice(idx + 1)
    ];

    try {
      await setAttendingSiblingSelected({
        applicationId: this.recordId,
        attendingCandidateJson: JSON.stringify({
          accountId: current.accountId,
          firstName: current.firstName,
          lastName: current.lastName,
          ateId: current.ateId ?? null
        }),
        selected: newSelected
      });
    } catch (err) {
      console.error('Failed to update attending sibling selection:', err);
      // Rollback optimistic update
      const rolledBack = { ...updated, selected: current.selected };
      rolledBack.rowClass = current.selected
        ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
        : 'candidate-row slds-p-vertical_xx-small';
      rolledBack.ariaChecked = current.selected ? 'true' : 'false';
      this.attendingCandidates = [
        ...this.attendingCandidates.slice(0, idx),
        rolledBack,
        ...this.attendingCandidates.slice(idx + 1)
      ];
    }
  }

  // --- Applying section: row selection ---

  handleApplyingRowClick(event) {
    const applicationId = event.currentTarget.dataset.id;
    this._toggleApplyingRow(applicationId);
  }

  handleApplyingKeydown(event) {
    if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault();
      const applicationId = event.currentTarget.dataset.id;
      this._toggleApplyingRow(applicationId);
    }
  }

  async _toggleApplyingRow(applicationId) {
    const idx = this.applyingCandidates.findIndex(
      (c) => c.applicationId === applicationId
    );
    if (idx === -1) return;

    const current = this.applyingCandidates[idx];
    const newSelected = !current.selected;

    // Optimistic update
    const updated = { ...current, selected: newSelected };
    updated.rowClass = newSelected
      ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
      : 'candidate-row slds-p-vertical_xx-small';
    updated.ariaChecked = newSelected ? 'true' : 'false';
    this.applyingCandidates = [
      ...this.applyingCandidates.slice(0, idx),
      updated,
      ...this.applyingCandidates.slice(idx + 1)
    ];

    try {
      await setApplyingSiblingSelected({
        applicationId: this.recordId,
        applyingCandidateJson: JSON.stringify({
          applicationId: current.applicationId,
          firstName: current.firstName,
          lastName: current.lastName,
          gradeApplyingTo: current.gradeApplyingTo
        }),
        selected: newSelected
      });
    } catch (err) {
      console.error('Failed to update applying sibling selection:', err);
      // Rollback optimistic update
      const rolledBack = { ...updated, selected: current.selected };
      rolledBack.rowClass = current.selected
        ? 'candidate-row candidate-row--selected slds-p-vertical_xx-small'
        : 'candidate-row slds-p-vertical_xx-small';
      rolledBack.ariaChecked = current.selected ? 'true' : 'false';
      this.applyingCandidates = [
        ...this.applyingCandidates.slice(0, idx),
        rolledBack,
        ...this.applyingCandidates.slice(idx + 1)
      ];
    }
  }

  // --- Applying: inline subform for adding a new sibling with a draft app ---

  handleShowApplyingForm() {
    this.applyingFormVisible = true;
  }

  handleCancelApplyingForm() {
    this.applyingFormVisible = false;
  }

  async handleSiblingCreated() {
    // The subform already inserted Account + ACR + Draft IndividualApplication
    // + a Pending "Sibling Applying" Priority_Item__c.
    // Refresh candidates so the new one appears pre-selected.
    this.applyingFormVisible = false;
    await this._loadSiblings();
  }

  // --- Household roster: select existing students + bulk-create placeholder apps ---

  get hasHouseholdCandidates() {
    return this.householdCandidates.length > 0;
  }

  get showHouseholdSection() {
    return this.hasHouseholdCandidates;
  }

  get checkedHouseholdRows() {
    return this.householdCandidates.filter((r) => r.checked);
  }

  get householdSubmitLabel() {
    return `${this.labels.householdSiblingsCreateButton} (${this.checkedHouseholdRows.length})`;
  }

  get householdSubmitDisabled() {
    return this.householdSubmitting || this.checkedHouseholdRows.length === 0;
  }

  get hasSkippedNames() {
    return this.householdSkippedNames.length > 0;
  }

  get skippedNoticeText() {
    return `${this.labels.householdSiblingsSkipped} ${this.householdSkippedNames.join(', ')}`;
  }

  handleHouseholdCheckboxChange(event) {
    const accountId = event.target.dataset.accountId;
    const checked = event.target.checked;
    this.householdCandidates = this.householdCandidates.map((r) =>
      r.accountId === accountId
        ? { ...r, checked, gradeError: checked ? r.gradeError : false }
        : r
    );
  }

  handleHouseholdGradeChange(event) {
    const accountId = event.target.dataset.accountId;
    const gradeApplyingTo = event.detail.value;
    this.householdCandidates = this.householdCandidates.map((r) =>
      r.accountId === accountId
        ? { ...r, gradeApplyingTo, gradeError: false }
        : r
    );
  }

  async handleHouseholdCreateClick() {
    const checked = this.householdCandidates.filter((r) => r.checked);
    if (checked.length === 0) {
      return;
    }

    // Don't silently drop a checked-but-ungraded row — flag it inline and block.
    const missing = checked.filter((r) => !r.gradeApplyingTo);
    if (missing.length > 0) {
      const missingIds = new Set(missing.map((r) => r.accountId));
      this.householdCandidates = this.householdCandidates.map((r) =>
        missingIds.has(r.accountId) ? { ...r, gradeError: true } : r
      );
      return;
    }

    this.householdSubmitting = true;
    this.householdError = '';
    this.householdSkippedNames = [];

    try {
      const result = await createPlaceholderApplications({
        sourceApplicationId: this.recordId,
        selectionsJson: JSON.stringify(
          checked.map((r) => ({
            accountId: r.accountId,
            gradeApplyingTo: r.gradeApplyingTo
          }))
        )
      });

      const skippedIds = new Set((result && result.skippedAccountIds) || []);
      if (skippedIds.size > 0) {
        this.householdSkippedNames = this.householdCandidates
          .filter((r) => skippedIds.has(r.accountId))
          .map((r) => r.displayLabel);
      }

      // Reload so the new siblings drop out of the roster (they now have apps) and
      // appear pre-selected in the "Siblings Also Applying" list.
      await this._loadSiblings();
    } catch (err) {
      this.householdError =
        err?.body?.message ||
        err?.message ||
        'Failed to create applications. Please try again.';
      console.error('Failed to create placeholder applications:', err);
    } finally {
      this.householdSubmitting = false;
    }
  }

  // --- Attending: "add not listed" inline form ---

  handleShowAttendingAddForm() {
    this.attendingDraft = {
      firstName: '',
      lastName: '',
      birthdate: '',
      zetaSchool: ''
    };
    this.attendingAddError = '';
    this.attendingAddFormVisible = true;
  }

  handleAttendingAddCancel() {
    this.attendingAddFormVisible = false;
    this.attendingAddError = '';
  }

  handleAttendingDraftChange(event) {
    const field = event.target.dataset.field;
    this.attendingDraft = {
      ...this.attendingDraft,
      [field]: event.target.value
    };
  }

  handleSchoolChange(event) {
    this.attendingDraft = {
      ...this.attendingDraft,
      zetaSchool: event.detail.value
    };
  }

  async handleAttendingAddSave() {
    if (this.attendingAddSaveDisabled) return;

    this.attendingAddSaving = true;
    this.attendingAddError = '';

    try {
      await addManualAttendingSibling({
        applicationId: this.recordId,
        addAttendingJson: JSON.stringify(this.attendingDraft)
      });

      this.attendingAddFormVisible = false;
      // Re-query: the server surfaces the manually-added sibling as a selected row with
      // its real accountId (via its persisted Priority_Item__c), so it shows up
      // pre-selected and toggles uniformly through setAttendingSiblingSelected.
      await this._loadSiblings();
    } catch (err) {
      this.attendingAddError =
        err?.body?.message ||
        err?.message ||
        'Failed to add sibling. Please try again.';
      console.error('Failed to add attending sibling:', err);
    } finally {
      this.attendingAddSaving = false;
    }
  }

  @api
  async flushAndSave() {
    // No-op — each user action commits canonical data immediately.
  }
}