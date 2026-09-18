import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import createSiblingDraftApplication from '@salesforce/apex/SiblingSectionController.createSiblingDraftApplication';
import getGradeOptions from '@salesforce/apex/StudentSelectionController.getGradeOptions';
import GENDER_FIELD from '@salesforce/schema/Contact.GenderIdentity';

// Master record type id — Salesforce's sentinel for "the object has no record
// types", used as the getPicklistValues fallback when getObjectInfo reports no
// default.
const NULL_RECORD_TYPE_ID = '012000000000000AAA';

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
  genderOptions = [];
  saving = false;
  errorMessage = '';

  _contactRecordTypeId = NULL_RECORD_TYPE_ID;

  @wire(getGradeOptions)
  wiredGradeOptions({ data }) {
    if (data) {
      this.gradeOptions = data.map((g) => ({ label: g.label, value: g.value }));
    }
  }

  // The sibling gender picklist is a person-account field. Those are Contact
  // fields surfaced on Account, and getPicklistValues resolves them only from
  // Contact — asking for Account.PersonGenderIdentity errors. Apex still writes
  // PersonGenderIdentity (and the matching Priority_Item__c.Gender__c); the
  // value sets match.
  @wire(getObjectInfo, { objectApiName: 'Contact' })
  wiredContactInfo({ data }) {
    if (data) {
      this._contactRecordTypeId =
        data.defaultRecordTypeId || NULL_RECORD_TYPE_ID;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: '$_contactRecordTypeId',
    fieldApiName: GENDER_FIELD
  })
  wiredGender({ data }) {
    if (data) {
      this.genderOptions = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    }
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