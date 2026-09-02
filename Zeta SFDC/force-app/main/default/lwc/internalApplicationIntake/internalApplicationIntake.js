import { LightningElement, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import createGuardian from '@salesforce/apex/InternalApplicationController.createGuardian';
import createStudentForGuardian from '@salesforce/apex/InternalApplicationController.createStudentForGuardian';
import findPossibleDuplicates from '@salesforce/apex/InternalApplicationController.findPossibleDuplicates';
import getGuardianStudents from '@salesforce/apex/InternalApplicationController.getGuardianStudents';
import searchGuardians from '@salesforce/apex/InternalApplicationController.searchGuardians';
import startApplication from '@salesforce/apex/InternalApplicationController.startApplication';
import getAvailableTimelines from '@salesforce/apex/ZetaApplicationController.getAvailableTimelines';
import GENDER_FIELD from '@salesforce/schema/Contact.GenderIdentity';
import LANGUAGE_FIELD from '@salesforce/schema/Contact.Language_Preference__c';
import APP_INFO_SOURCE_FIELD from '@salesforce/schema/IndividualApplication.App_Info_Source_Staff_Internal__c';
import LEAD_SOURCE_FIELD from '@salesforce/schema/IndividualApplication.Lead_Source__c';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import USER_ID from '@salesforce/user/Id';

const SEARCH_DEBOUNCE_MS = 300;

// Mirrors the LIMIT in InternalApplicationController.searchGuardians. Hitting it
// exactly means the org may hold more matches than we are showing.
const SEARCH_RESULT_LIMIT = 25;

const TEAM_ASSISTED = 'Team-Assisted Conversion';

// Master record type id — Salesforce's sentinel for "the object has no record
// types", used as the getPicklistValues fallback when getObjectInfo reports no
// default. Same constant and reasoning as applicationDashboard.
const NULL_RECORD_TYPE_ID = '012000000000000AAA';

export default class InternalApplicationIntake extends LightningElement {
  @track newGuardian = {};
  @track newStudent = {};

  guardianMode = 'existing';
  guardianSearchTerm = '';
  guardianResults = [];
  selectedGuardian = null;
  duplicateWarnings = [];

  students = [];
  selectedStudentId = null;
  addingStudent = false;

  timelines = [];
  timelineId = null;

  leadSourceOptions = [];
  appInfoSourceOptions = [];
  languageOptions = [];
  genderOptions = [];
  currentUserName = '';

  leadSource = null;
  appInfoSource = null;

  applicationId = null;
  isBusy = false;
  errorMessage = '';

  _applicationRecordTypeId = NULL_RECORD_TYPE_ID;
  _contactRecordTypeId = NULL_RECORD_TYPE_ID;
  _searchTimer;

  @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
  wiredUser({ data }) {
    if (data) {
      this.currentUserName = data.fields.Name.value;
    }
  }

  @wire(getObjectInfo, { objectApiName: 'IndividualApplication' })
  wiredApplicationInfo({ data }) {
    if (data) {
      this._applicationRecordTypeId =
        data.defaultRecordTypeId || NULL_RECORD_TYPE_ID;
    }
  }

  // The guardian language and student gender picklists are person-account
  // fields. Those are Contact fields surfaced on Account, and getPicklistValues
  // resolves them only from Contact — asking for Account.Language_Preference__pc
  // errors. Apex still writes the __pc / Person* names; the value sets match.
  @wire(getObjectInfo, { objectApiName: 'Contact' })
  wiredContactInfo({ data }) {
    if (data) {
      this._contactRecordTypeId =
        data.defaultRecordTypeId || NULL_RECORD_TYPE_ID;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_applicationRecordTypeId',
    fieldApiName: LEAD_SOURCE_FIELD
  })
  wiredLeadSource({ data, error }) {
    if (data) {
      this.leadSourceOptions = this._toOptions(data.values);
    } else if (error) {
      this.errorMessage = this._message(error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_applicationRecordTypeId',
    fieldApiName: APP_INFO_SOURCE_FIELD
  })
  wiredAppInfoSource({ data, error }) {
    if (data) {
      // Optional field: without an explicit blank entry a lightning-combobox
      // cannot be un-picked once a value is chosen.
      this.appInfoSourceOptions = [
        { label: '--None--', value: '' },
        ...this._toOptions(data.values)
      ];
    } else if (error) {
      this.errorMessage = this._message(error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_contactRecordTypeId',
    fieldApiName: LANGUAGE_FIELD
  })
  wiredLanguage({ data, error }) {
    if (data) {
      // The field default is deliberately ignored: staff must pick the language
      // themselves so the value on the guardian record reflects the family.
      this.languageOptions = this._toOptions(data.values);
    } else if (error) {
      this.errorMessage = this._message(error);
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_contactRecordTypeId',
    fieldApiName: GENDER_FIELD
  })
  wiredGender({ data, error }) {
    if (data) {
      this.genderOptions = this._toOptions(data.values);
    } else if (error) {
      this.errorMessage = this._message(error);
    }
  }

  async connectedCallback() {
    try {
      this.timelines = await getAvailableTimelines();
      if (this.timelines.length === 1) {
        this.timelineId = this.timelines[0].id;
      }
    } catch (err) {
      this.errorMessage = this._message(err);
    }
  }

  disconnectedCallback() {
    clearTimeout(this._searchTimer);
  }

  get isExistingGuardian() {
    return this.guardianMode === 'existing';
  }

  get isNewGuardian() {
    return this.guardianMode === 'new';
  }

  get guardianModeOptions() {
    return [
      { label: 'Existing guardian', value: 'existing' },
      { label: 'New guardian', value: 'new' }
    ];
  }

  get hasGuardian() {
    return !!this.selectedGuardian;
  }

  get hasGuardianResults() {
    return this.guardianResults.length > 0;
  }

  get resultsWereCapped() {
    return this.guardianResults.length >= SEARCH_RESULT_LIMIT;
  }

  get resultCapText() {
    return `Showing the first ${SEARCH_RESULT_LIMIT} matches. Refine your search.`;
  }

  get hasDuplicateWarnings() {
    return this.duplicateWarnings.length > 0;
  }

  get duplicateWarningText() {
    const names = this.duplicateWarnings.map((d) => d.name).join(', ');
    return `A guardian with this email or phone already exists: ${names}. Check before creating a duplicate.`;
  }

  get hasStudents() {
    return this.students.length > 0;
  }

  get showStudentForm() {
    return this.addingStudent || (this.hasGuardian && !this.hasStudents);
  }

  // Cancel collapses back to the tile grid. With no students there is nothing to
  // collapse to, so the only way out would be to leave the screen.
  get showCancelStudent() {
    return this.hasStudents;
  }

  get showAddStudentTile() {
    return this.hasStudents && !this.addingStudent;
  }

  get studentTiles() {
    return this.students.map((s) => {
      const isSelected = s.id === this.selectedStudentId;
      return {
        ...s,
        displayName: `${s.firstName} ${s.lastName}`.trim(),
        birthdateLabel: s.birthdate ? `Born ${s.birthdate}` : '',
        isSelected,
        ariaChecked: isSelected ? 'true' : 'false',
        tileClass: isSelected ? 'tile tile--selected' : 'tile'
      };
    });
  }

  get timelineOptions() {
    return this.timelines.map((t) => ({
      label: this._timelineLabel(t),
      value: t.id
    }));
  }

  get leadInfoSummary() {
    return `Submitting as ${this.currentUserName} · ${TEAM_ASSISTED}`;
  }

  // Salesforce already draws navigation above this tab, so the wizard must not
  // stick its own header to the top of the viewport here. A bound getter, not a
  // bare attribute: `static-header` alone would set the empty string, which is
  // falsy.
  get hostSuppliesChrome() {
    return true;
  }

  get onBehalfOfText() {
    return `Submitting on behalf of ${this.selectedGuardian?.name || ''}`;
  }

  get showIntake() {
    return !this.applicationId;
  }

  get hasError() {
    return !!this.errorMessage;
  }

  get canStartDisabled() {
    return !(
      this.selectedGuardian &&
      this.selectedStudentId &&
      this.timelineId &&
      this.leadSource &&
      !this.isBusy
    );
  }

  handleGuardianMode(event) {
    this.guardianMode = event.detail.value;
    this.selectedGuardian = null;
    this.students = [];
    this.selectedStudentId = null;
    this.duplicateWarnings = [];
  }

  handleGuardianSearch(event) {
    this.guardianSearchTerm = event.target.value;
    clearTimeout(this._searchTimer);
    this._searchTimer = setTimeout(async () => {
      try {
        this.guardianResults = await searchGuardians({
          term: this.guardianSearchTerm
        });
      } catch (err) {
        this.errorMessage = this._message(err);
      }
    }, SEARCH_DEBOUNCE_MS);
  }

  async handleGuardianPick(event) {
    const id = event.currentTarget.dataset.id;
    this.selectedGuardian = this.guardianResults.find((g) => g.id === id);
    this.guardianResults = [];
    await this._loadStudents();
  }

  handleNewGuardianChange(event) {
    this.newGuardian = {
      ...this.newGuardian,
      [event.target.name]: event.target.value
    };
  }

  handleAddressChange(event) {
    const { street, city, province, postalCode } = event.detail;
    this.newGuardian = {
      ...this.newGuardian,
      street: street || '',
      city: city || '',
      state: province || '',
      zip: postalCode || ''
    };
  }

  async handleDuplicateCheck() {
    if (!this.newGuardian.email && !this.newGuardian.phone) {
      return;
    }
    try {
      this.duplicateWarnings = await findPossibleDuplicates({
        email: this.newGuardian.email || null,
        phone: this.newGuardian.phone || null
      });
    } catch (err) {
      this.errorMessage = this._message(err);
    }
  }

  async handleCreateGuardian() {
    this.errorMessage = '';
    if (!this._validate('.new-guardian-field')) {
      return;
    }
    this.isBusy = true;
    try {
      const created = await createGuardian({
        guardianJson: JSON.stringify(this.newGuardian)
      });
      this.selectedGuardian = {
        id: created.accountId,
        name: `${this.newGuardian.firstName || ''} ${this.newGuardian.lastName}`.trim(),
        email: this.newGuardian.email
      };
      this.duplicateWarnings = [];
      this.addingStudent = true;
      await this._loadStudents();
    } catch (err) {
      this.errorMessage = this._message(err);
    } finally {
      this.isBusy = false;
    }
  }

  handleStudentSelect(event) {
    this.selectedStudentId = event.currentTarget.dataset.id;
  }

  handleTileKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.selectedStudentId = event.currentTarget.dataset.id;
    }
  }

  handleAddStudent() {
    this.addingStudent = true;
    this.selectedStudentId = null;
  }

  handleAddKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.handleAddStudent();
    }
  }

  handleCancelStudent() {
    this.addingStudent = false;
    this.newStudent = {};
  }

  handleNewStudentChange(event) {
    this.newStudent = {
      ...this.newStudent,
      [event.target.name]: event.target.value
    };
  }

  async handleCreateStudent() {
    this.errorMessage = '';
    if (!this._validate('.new-student-field')) {
      return;
    }
    this.isBusy = true;
    try {
      const studentId = await createStudentForGuardian({
        guardianAccountId: this.selectedGuardian.id,
        studentJson: JSON.stringify(this.newStudent)
      });
      this.newStudent = {};
      this.addingStudent = false;
      await this._loadStudents();
      this.selectedStudentId = studentId;
    } catch (err) {
      this.errorMessage = this._message(err);
    } finally {
      this.isBusy = false;
    }
  }

  handleTimelineChange(event) {
    this.timelineId = event.detail.value;
  }

  handleLeadSourceChange(event) {
    this.leadSource = event.detail.value;
  }

  handleAppInfoSourceChange(event) {
    this.appInfoSource = event.detail.value;
  }

  async handleStart() {
    this.errorMessage = '';
    this.isBusy = true;
    try {
      const result = await startApplication({
        requestJson: JSON.stringify({
          guardianAccountId: this.selectedGuardian.id,
          studentAccountId: this.selectedStudentId,
          timelineId: this.timelineId,
          leadSource: this.leadSource,
          appInfoSource: this.appInfoSource
        })
      });
      this.applicationId = result.applicationId;
    } catch (err) {
      this.errorMessage = this._message(err);
    } finally {
      this.isBusy = false;
    }
  }

  // The wizard's Return Home button dispatches this. In the parent portal the
  // dashboard hosts the wizard and handles it; here the intake screen is home.
  handleReturnToIntake() {
    this.applicationId = null;
    this.selectedStudentId = null;
    this.addingStudent = false;
    this.newStudent = {};
    this.leadSource = null;
    this.appInfoSource = null;
  }

  _timelineLabel(timeline) {
    const range = [timeline.openDate, timeline.closeDate]
      .filter(Boolean)
      .join(' – ');
    return range ? `${timeline.name} (${range})` : timeline.name;
  }

  _toOptions(values) {
    return (values || []).map((v) => ({ label: v.label, value: v.value }));
  }

  async _loadStudents() {
    if (!this.selectedGuardian) {
      return;
    }
    this.students = await getGuardianStudents({
      guardianAccountId: this.selectedGuardian.id
    });
    if (this.students.length === 1) {
      this.selectedStudentId = this.students[0].id;
    }
  }

  _validate(selector) {
    const fields = [...this.template.querySelectorAll(selector)];
    return fields.reduce((valid, f) => f.reportValidity() && valid, true);
  }

  _message(err) {
    // Apex errors reach the client in several shapes depending on whether they
    // came from a thrown exception, a DML failure or a validation rule. Staff
    // need the real text: "Something went wrong" gives them nothing to act on.
    const body = err?.body;
    const fromDml = body?.output?.errors?.map((e) => e.message).join(' ');
    const fromFields = body?.output?.fieldErrors
      ? Object.values(body.output.fieldErrors)
          .flat()
          .map((e) => e.message)
          .join(' ')
      : '';
    return (
      body?.message ||
      (Array.isArray(body) && body[0]?.message) ||
      body?.pageErrors?.[0]?.message ||
      fromDml ||
      fromFields ||
      err?.message ||
      'Something went wrong. Please try again.'
    );
  }
}