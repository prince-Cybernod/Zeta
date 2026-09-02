import { LightningElement, api, wire } from 'lwc';
import createSiblingDraftApplication from '@salesforce/apex/SiblingSectionController.createSiblingDraftApplication';
import getGradeOptions from '@salesforce/apex/StudentSelectionController.getGradeOptions';

const GENDER_OPTIONS = [
  { label: 'Male', value: 'M' },
  { label: 'Female', value: 'F' }
];

export default class SiblingNewStudentForm extends LightningElement {
  @api recordId;

  draft = {
    firstName: '',
    lastName: '',
    birthdate: '',
    gender: '',
    currentGrade: '',
    gradeApplyingTo: ''
  };
  gradeOptions = [];
  saving = false;
  errorMessage = '';

  @wire(getGradeOptions)
  wiredGradeOptions({ data }) {
    if (data) {
      this.gradeOptions = data.map((g) => ({ label: g.label, value: g.value }));
    }
  }

  get genderOptions() {
    return GENDER_OPTIONS;
  }

  get saveDisabled() {
    return (
      this.saving ||
      !this.draft.firstName ||
      !this.draft.lastName ||
      !this.draft.birthdate ||
      !this.draft.gradeApplyingTo
    );
  }

  handleChange(event) {
    const field = event.target.dataset.field;
    this.draft = { ...this.draft, [field]: event.target.value };
  }

  handleCancel() {
    this.dispatchEvent(
      new CustomEvent('cancel', { bubbles: true, composed: true })
    );
  }

  async handleSave() {
    if (this.saveDisabled) {
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      const result = await createSiblingDraftApplication({
        applicationId: this.recordId,
        studentJson: JSON.stringify(this.draft)
      });
      this.dispatchEvent(
        new CustomEvent('siblingcreated', {
          detail: {
            accountId: result.accountId,
            applicationId: result.applicationId,
            firstName: this.draft.firstName,
            lastName: this.draft.lastName
          },
          bubbles: true,
          composed: true
        })
      );
    } catch (err) {
      this.errorMessage =
        err?.body?.message ||
        err?.message ||
        'Failed to create sibling application.';
      console.error('Failed to create sibling draft application:', err);
    } finally {
      this.saving = false;
    }
  }
}