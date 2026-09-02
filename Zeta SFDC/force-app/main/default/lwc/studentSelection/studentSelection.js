import { LightningElement, api } from 'lwc';
import createStudent from '@salesforce/apex/StudentSelectionController.createStudent';
import getApplicationStudent from '@salesforce/apex/StudentSelectionController.getApplicationStudent';
import getGradeBirthYearGuidance from '@salesforce/apex/StudentSelectionController.getGradeBirthYearGuidance';
import getGradeOptions from '@salesforce/apex/StudentSelectionController.getGradeOptions';
import getStudents from '@salesforce/apex/StudentSelectionController.getStudents';
import selectStudent from '@salesforce/apex/StudentSelectionController.selectStudent';
import updateStudentBirthdate from '@salesforce/apex/StudentSelectionController.updateStudentBirthdate';
import checkAlreadyEnrolled from '@salesforce/apex/ZetaApplicationController.checkAlreadyEnrolled';
import labelAddAnotherStudent from '@salesforce/label/c.AppUI_AddAnotherStudent';
import labelAddAStudent from '@salesforce/label/c.AppUI_AddAStudent';
import labelAddStudent from '@salesforce/label/c.AppUI_AddStudent';
import labelAlreadyEnrolled from '@salesforce/label/c.AppUI_AlreadyEnrolled';
import labelAriaLoadingStudents from '@salesforce/label/c.AppUI_AriaLoadingStudents';
import labelAriaSelectStudent from '@salesforce/label/c.AppUI_AriaSelectStudent';
import labelCancel from '@salesforce/label/c.AppUI_Cancel';
import labelContactUsLinkText from '@salesforce/label/c.AppUI_ContactUsLinkText';
import labelCreateStudentFailed from '@salesforce/label/c.AppUI_CreateStudentFailed';
import labelEditBirthday from '@salesforce/label/c.AppUI_EditBirthday';
import labelCurrentGrade from '@salesforce/label/c.AppUI_FieldCurrentGrade';
import labelDateOfBirth from '@salesforce/label/c.AppUI_FieldDateOfBirth';
import labelFirstName from '@salesforce/label/c.AppUI_FieldFirstName';
import labelGender from '@salesforce/label/c.AppUI_FieldGender';
import labelGradeApplyingTo from '@salesforce/label/c.AppUI_FieldGradeApplyingTo';
import labelLastName from '@salesforce/label/c.AppUI_FieldLastName';
// labelCity/State/Street/ZipCode imports removed: address is captured separately
// in the Student Address application section (via questionAddress LWC).
import labelGradeInfo from '@salesforce/label/c.AppUI_GradeInfo';
import labelGradeProgressionWarning from '@salesforce/label/c.AppUI_GradeProgressionWarning';
import labelKindergartenBirthYearNote from '@salesforce/label/c.AppUI_KindergartenBirthYearNote';
import labelNewStudent from '@salesforce/label/c.AppUI_NewStudent';
import labelPreKBirthYearNote from '@salesforce/label/c.AppUI_PreKBirthYearNote';
import labelSave from '@salesforce/label/c.AppUI_Save';
import labelSelectStudent from '@salesforce/label/c.AppUI_SelectStudent';
import labelSelectStudentDesc from '@salesforce/label/c.AppUI_SelectStudentDesc';
import labelUpdateBirthdayFailed from '@salesforce/label/c.AppUI_UpdateBirthdayFailed';
import labelValidateSelectCurrentGrade from '@salesforce/label/c.AppUI_ValidateSelectCurrentGrade';
import labelValidateSelectGrade from '@salesforce/label/c.AppUI_ValidateSelectGrade';
import labelValidateSelectStudent from '@salesforce/label/c.AppUI_ValidateSelectStudent';
import labelZipCodeError from '@salesforce/label/c.AppUI_ZipCodeError';

const GENDER_OPTIONS = [
  { label: 'Male', value: 'M' },
  { label: 'Female', value: 'F' }
];

const VALID_NEXT_GRADES = {
  // A student with no prior schooling (current grade "N/A") may enter at
  // Pre-K, Kindergarten, or First Grade without triggering the progression warning.
  'N/A': ['PK', 'K', '1'],
  PK: ['TK', 'K'],
  TK: ['K'],
  K: ['1'],
  1: ['2'],
  2: ['3'],
  3: ['4'],
  4: ['5'],
  5: ['6'],
  6: ['7'],
  7: ['8'],
  8: ['9'],
  9: ['10'],
  10: ['11'],
  11: ['12']
};
// Resolved from the host rather than @salesforce/community/basePath: that module
// can only load inside Experience Builder, so importing it here made the whole
// bundle unconstructable on an internal Lightning page.
const PORTAL_CONTACT_SUPPORT_URL = '/parents/s/contactsupport';

export default class StudentSelection extends LightningElement {
  @api recordId;
  @api isLocked = false;
  @api contactSupportUrl;
  // Set by the host wizard when the selected student already has a submitted
  // application for this timeline. Hides the grade pickers so the parent isn't
  // prompted to fill in grade info for an application they cannot create.
  @api duplicateBlocked = false;

  students = [];
  gradePicklistOptions = [];
  selectedStudentId = null;
  selectedGrade = '';
  selectedCurrentGrade = '';
  // Birth-year guidance for the Pre-K / Kindergarten note under "Grade Applying
  // To". Sourced server-side (placeholder today, ApplicationTimeline fields once
  // they exist — see StudentSelectionController.getGradeBirthYearGuidance).
  preKBirthYear = '';
  kindergartenBirthYear = '';
  gradeInconsistency = false;
  isAlreadyEnrolled = false;
  isLoading = true;
  isSaving = false;
  // True while a grade/student selection is being persisted server-side (and the
  // age/grade inconsistency flag re-evaluated). Surfaced to the host via
  // completionchange so Continue can be disabled until validation lands.
  isSavingSelection = false;
  showAddForm = false;
  createError = '';
  validationError = '';
  editingStudentId = null;
  editBirthdate = '';
  editError = '';
  isSavingEdit = false;
  newStudent = {
    firstName: '',
    lastName: '',
    birthdate: '',
    gender: ''
  };

  labels = {
    selectStudent: labelSelectStudent,
    selectStudentDesc: labelSelectStudentDesc,
    addAnotherStudent: labelAddAnotherStudent,
    newStudent: labelNewStudent,
    firstName: labelFirstName,
    lastName: labelLastName,
    dateOfBirth: labelDateOfBirth,
    gender: labelGender,
    cancel: labelCancel,
    save: labelSave,
    editBirthday: labelEditBirthday,
    addStudent: labelAddStudent,
    gradeInfo: labelGradeInfo,
    currentGrade: labelCurrentGrade,
    gradeApplyingTo: labelGradeApplyingTo,
    ariaLoadingStudents: labelAriaLoadingStudents,
    ariaSelectStudent: labelAriaSelectStudent
  };

  get genderOptions() {
    return GENDER_OPTIONS;
  }

  // "Grade applying to" never includes the no-prior-schooling sentinel ("N/A");
  // that value only makes sense as a CURRENT grade. The current-grade picker
  // (gradePicklistOptions) keeps it.
  get gradeApplyingToOptions() {
    return this.gradePicklistOptions.filter((o) => o.value !== 'N/A');
  }

  get showContent() {
    return !this.isLoading;
  }

  get showAddButton() {
    return !this.isLocked;
  }

  get addStudentLabel() {
    return this.students.length > 0 ? labelAddAnotherStudent : labelAddAStudent;
  }

  get studentTiles() {
    return this.students.map((s) => {
      const isSelected = s.id === this.selectedStudentId;
      const isEditing = s.id === this.editingStudentId;
      let tileClass = 'tile';
      if (isSelected) tileClass += ' tile--selected';
      if (this.isLocked && !isSelected) tileClass += ' tile--locked';
      if (this.isLocked && isSelected) tileClass += ' tile--locked-selected';
      if (isEditing) tileClass += ' tile--editing';
      return {
        ...s,
        displayName: `${s.firstName || ''} ${s.lastName || ''}`.trim(),
        birthdateFormatted: s.birthdate
          ? new Date(s.birthdate + 'T00:00:00').toLocaleDateString('en-US', {
              month: 'long',
              day: 'numeric',
              year: 'numeric'
            })
          : '',
        gradeLabel:
          isSelected && this.selectedGrade ? this.selectedGradeLabel : '',
        isSelected,
        isEditing,
        showEditButton: !s.hasSubmittedApplication && !isEditing,
        showLockIcon: this.isLocked && isSelected,
        ariaChecked: isSelected ? 'true' : 'false',
        tileClass
      };
    });
  }

  get selectedGradeLabel() {
    if (!this.selectedGrade) return '';
    const match = this.gradePicklistOptions.find(
      (o) => o.value === this.selectedGrade
    );
    return match ? match.label : this.selectedGrade;
  }

  get selectedCurrentGradeLabel() {
    if (!this.selectedCurrentGrade) return '';
    const match = this.gradePicklistOptions.find(
      (o) => o.value === this.selectedCurrentGrade
    );
    return match ? match.label : this.selectedCurrentGrade;
  }

  get isStepComplete() {
    return (
      !!this.selectedStudentId &&
      !!this.selectedCurrentGrade &&
      !!this.selectedGrade &&
      !this.isAlreadyEnrolled
    );
  }

  get showGradeSection() {
    return (
      this.selectedStudentId &&
      !this.isAlreadyEnrolled &&
      !this.duplicateBlocked
    );
  }

  // The embedded address capture (application-form-page filtered to the
  // Guardian 1 / student address sections + the living-status checkbox) renders
  // as soon as the draft application exists. The wizard creates the
  // IndividualApplication the moment a student is selected — grade is no longer
  // required — and re-feeds the real recordId reactively. So the address is live
  // and editable the instant a student is picked, independent of the grade
  // fields and with no disabled state; questionAddress's lazy-load + debounced
  // save still never fire against a null recordId.
  get showAddressCapture() {
    return (
      !!this.recordId && !!this.selectedStudentId && !this.isAlreadyEnrolled
    );
  }

  connectedCallback() {
    this._loadData();
  }

  async _loadData() {
    try {
      const [students, grades, appStudent, guidance] = await Promise.all([
        getStudents(),
        getGradeOptions(),
        this.recordId
          ? getApplicationStudent({ applicationId: this.recordId })
          : Promise.resolve({}),
        getGradeBirthYearGuidance({ applicationId: this.recordId })
      ]);

      this.students = students;
      this.gradePicklistOptions = grades.map((g) => ({
        label: g.label,
        value: g.value
      }));
      this.preKBirthYear = guidance?.preKBirthYear || '';
      this.kindergartenBirthYear = guidance?.kindergartenBirthYear || '';

      if (appStudent.studentAccountId) {
        // Internal/record-page mode: an internal user has no parent Contact, so
        // getStudents() returns []. Synthesize the application's student from the
        // record so it still renders as a (selected) tile. Reassign — never mutate
        // — so studentTiles recomputes. Parents are unaffected: their getStudents()
        // already includes the student, so this guard skips.
        if (!this.students.some((s) => s.id === appStudent.studentAccountId)) {
          this.students = [
            {
              id: appStudent.studentAccountId,
              firstName: appStudent.firstName,
              lastName: appStudent.lastName,
              birthdate: appStudent.birthdate,
              hasSubmittedApplication: false
            },
            ...this.students
          ];
        }

        this.selectedStudentId = appStudent.studentAccountId;
        this.selectedGrade = appStudent.grade || '';
        this.selectedCurrentGrade = appStudent.currentGrade || '';
        this._checkGradeProgression();
        await this._checkEnrollment();
      }
    } catch (err) {
      console.error('Failed to load student data:', err);
    } finally {
      this.isLoading = false;
      this._dispatchCompletionStatus();
    }
  }

  // The already-enrolled message is one sentence ending in the link text
  // ("…please contact us."). To hyperlink only that phrase without rewording the
  // (translated) label, split the full message around the link-text label and
  // render before + <a> + after in the template. If the link text isn't found
  // (e.g. an unmocked label in a test), the full sentence still renders as plain
  // text — no link, no crash.
  get enrolledMessageParts() {
    const full = labelAlreadyEnrolled;
    const linkText = labelContactUsLinkText;
    const idx = full.indexOf(linkText);
    if (idx === -1) {
      return { before: full, linkText: '', after: '' };
    }
    return {
      before: full.slice(0, idx),
      linkText,
      after: full.slice(idx + linkText.length)
    };
  }

  get contactUsUrl() {
    return this.contactSupportUrl || PORTAL_CONTACT_SUPPORT_URL;
  }

  get gradeInconsistencyMessage() {
    return labelGradeProgressionWarning;
  }

  // The Pre-K / Kindergarten birth-year note only renders when the parent picks
  // that exact grade value (the picklist API value, not the label) and a year is
  // available from the server.
  get showPreKBirthYearNote() {
    return this.selectedGrade === 'PK' && !!this.preKBirthYear;
  }

  get showKindergartenBirthYearNote() {
    return this.selectedGrade === 'K' && !!this.kindergartenBirthYear;
  }

  get preKBirthYearNote() {
    return labelPreKBirthYearNote.replace('{0}', this.preKBirthYear);
  }

  get kindergartenBirthYearNote() {
    return labelKindergartenBirthYearNote.replace(
      '{0}',
      this.kindergartenBirthYear
    );
  }

  async handleSelectStudent(event) {
    if (this.isLocked) return;
    const studentId = event.currentTarget.dataset.id;
    if (this.editingStudentId === studentId) return;
    if (studentId === this.selectedStudentId) {
      return;
    }

    this.selectedStudentId = studentId;
    this.selectedGrade = '';
    this.selectedCurrentGrade = '';
    this.gradeInconsistency = false;
    this.isAlreadyEnrolled = false;
    this.validationError = '';

    await this._checkEnrollment();
    // If a draft application already exists (the parent is switching students
    // after one was created on the first selection), reparent it to the newly
    // selected student so the address widget and downstream saves target the
    // right account. selectStudent always rewrites AccountId.
    if (this.recordId && !this.isAlreadyEnrolled) {
      await this._saveSelection();
    }
    this._dispatchCompletionStatus();
  }

  stopEvent(event) {
    event.stopPropagation();
  }

  handleEditBirthdate(event) {
    event.stopPropagation();
    const studentId = event.currentTarget.dataset.id;
    const student = this.students.find((s) => s.id === studentId);
    if (student && student.hasSubmittedApplication) return;
    if (!student) return;
    this.editingStudentId = studentId;
    this.editBirthdate = student.birthdate || '';
    this.editError = '';
  }

  handleEditButtonKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      event.stopPropagation();
      this.handleEditBirthdate(event);
    }
  }

  handleEditBirthdateChange(event) {
    this.editBirthdate = event.target.value;
  }

  handleEditKeydown(event) {
    if (event.key === 'Escape') {
      event.stopPropagation();
      this.handleCancelBirthdate(event);
    }
  }

  handleCancelBirthdate(event) {
    if (event) event.stopPropagation();
    this.editingStudentId = null;
    this.editBirthdate = '';
    this.editError = '';
  }

  async handleSaveBirthdate(event) {
    event.stopPropagation();
    const input = this.template.querySelector('.tile-edit-row lightning-input');
    if (input && !input.reportValidity()) return;
    if (!this.editBirthdate) return;

    this.isSavingEdit = true;
    this.editError = '';
    const editedId = this.editingStudentId;
    try {
      await updateStudentBirthdate({
        studentAccountId: editedId,
        birthdate: this.editBirthdate
      });
      this.students = this.students.map((s) => {
        return s.id === editedId ? { ...s, birthdate: this.editBirthdate } : s;
      });
      this.editingStudentId = null;
      this.editBirthdate = '';
      if (this.selectedStudentId === editedId) {
        await this._saveSelection();
      }
    } catch (err) {
      this.editError =
        err.body?.message || err.message || labelUpdateBirthdayFailed;
    } finally {
      this.isSavingEdit = false;
    }
  }

  handleTileKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.handleSelectStudent(event);
    }
  }

  handleAddKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.handleToggleAddForm();
    }
  }

  handleToggleAddForm() {
    if (this.isLocked) return;
    if (this.editingStudentId) {
      this.editingStudentId = null;
      this.editBirthdate = '';
      this.editError = '';
    }
    this.showAddForm = !this.showAddForm;
    if (this.showAddForm) {
      this.newStudent = {
        firstName: '',
        lastName: '',
        birthdate: '',
        gender: ''
      };
      this.createError = '';
    }
  }

  handleCancelAdd() {
    this.showAddForm = false;
  }

  handleNewStudentChange(event) {
    const field = event.target.dataset.field;
    this.newStudent = { ...this.newStudent, [field]: event.target.value };
  }

  async handleCreateStudent() {
    const inputs = this.template.querySelectorAll(
      '.add-form lightning-input, .add-form lightning-combobox'
    );
    let allValid = true;
    inputs.forEach((input) => {
      if (!input.reportValidity()) {
        allValid = false;
      }
    });
    if (!allValid) {
      return;
    }

    this.isSaving = true;
    this.createError = '';
    try {
      const newId = await createStudent({
        studentJson: JSON.stringify(this.newStudent)
      });

      const refreshed = await getStudents();
      this.students = refreshed;

      this.selectedStudentId = newId;
      this.selectedGrade = '';
      this.selectedCurrentGrade = '';
      this.isAlreadyEnrolled = false;
      this.gradeInconsistency = false;
      this.validationError = '';
      this.showAddForm = false;
      await this._checkEnrollment();
      this._dispatchCompletionStatus();
    } catch (err) {
      this.createError =
        err.body?.message || err.message || labelCreateStudentFailed;
    } finally {
      this.isSaving = false;
    }
  }

  async handleCurrentGradeChange(event) {
    this.selectedCurrentGrade = event.detail.value;
    this.validationError = '';
    this._checkGradeProgression();
    this._dispatchCompletionStatus();

    if (this.selectedStudentId) {
      await this._saveSelection();
    }
  }

  async handleGradeChange(event) {
    this.selectedGrade = event.detail.value;
    this.validationError = '';
    this._checkGradeProgression();
    this._dispatchCompletionStatus();

    if (this.selectedStudentId) {
      await this._saveSelection();
    }
  }

  _checkGradeProgression() {
    if (this.selectedCurrentGrade && this.selectedGrade) {
      const validNext = VALID_NEXT_GRADES[this.selectedCurrentGrade];
      this.gradeInconsistency =
        !validNext || !validNext.includes(this.selectedGrade);
    } else {
      this.gradeInconsistency = false;
    }
  }

  async _saveSelection() {
    if (!this.recordId) {
      return;
    }
    // Flag the save as in-flight and re-dispatch completion BEFORE awaiting the
    // server. The age/grade inconsistency warning is driven by the backend
    // Age_Inconsistency_Flag_c__c formula re-read inside selectStudent, so the
    // result isn't known client-side until this round trip resolves. Disabling
    // Continue for the duration keeps the parent on the step until the warning
    // (if any) has had a chance to render.
    this.isSavingSelection = true;
    this._dispatchCompletionStatus();
    this._dispatchSaveStatus('saving');
    try {
      await selectStudent({
        applicationId: this.recordId,
        studentAccountId: this.selectedStudentId,
        grade: this.selectedGrade,
        currentGrade: this.selectedCurrentGrade
      });
      this._dispatchSaveStatus('saved');
    } catch (err) {
      console.error('Failed to save student selection:', err);
      this._dispatchSaveStatus('failed');
    } finally {
      this.isSavingSelection = false;
      this._dispatchCompletionStatus();
    }
  }

  async _checkEnrollment() {
    if (!this.selectedStudentId) {
      this.isAlreadyEnrolled = false;
      return;
    }
    try {
      const result = await checkAlreadyEnrolled({
        studentAccountId: this.selectedStudentId
      });
      this.isAlreadyEnrolled = result.isEnrolled === true;
    } catch (err) {
      console.error('Failed to check enrollment:', err);
      this.isAlreadyEnrolled = false;
    }
  }

  get _selectedStudentName() {
    if (!this.selectedStudentId) return '';
    const student = this.students.find((s) => s.id === this.selectedStudentId);
    return student
      ? `${student.firstName || ''} ${student.lastName || ''}`.trim()
      : '';
  }

  _dispatchCompletionStatus() {
    this.dispatchEvent(
      new CustomEvent('completionchange', {
        detail: {
          complete: this.isStepComplete,
          saving: this.isSavingSelection,
          studentAccountId: this.selectedStudentId,
          studentName: this._selectedStudentName,
          grade: this.selectedGrade,
          gradeLabel: this.selectedGradeLabel,
          currentGrade: this.selectedCurrentGrade,
          currentGradeLabel: this.selectedCurrentGradeLabel,
          isEnrolled: this.isAlreadyEnrolled
        },
        bubbles: true,
        composed: true
      })
    );
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

  @api
  validate() {
    if (this.isAlreadyEnrolled) {
      return false;
    }
    if (this.isStepComplete) {
      this.validationError = '';
      return true;
    }
    if (!this.selectedStudentId) {
      this.validationError = labelValidateSelectStudent;
    } else if (!this.selectedCurrentGrade) {
      this.validationError = labelValidateSelectCurrentGrade;
    } else if (!this.selectedGrade) {
      this.validationError = labelValidateSelectGrade;
    }
    return false;
  }

  @api
  async flushAndSave() {
    if (this.recordId && this.selectedStudentId && this.selectedGrade) {
      await this._saveSelection();
    }
    // Flush the embedded address form page so any debounced address edits are
    // persisted before the wizard advances off step 1.
    const addressForm = this.template.querySelector('c-application-form-page');
    if (addressForm && typeof addressForm.flushAndSave === 'function') {
      await addressForm.flushAndSave();
    }
  }
}