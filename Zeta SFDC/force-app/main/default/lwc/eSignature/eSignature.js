import { LightningElement, api } from 'lwc';
import saveSignature from '@salesforce/apex/ZetaApplicationController.saveSignature';
import labelClear from '@salesforce/label/c.AppUI_Clear';
import labelDateLabel from '@salesforce/label/c.AppUI_ESignatureDateLabel';
import labelDisclaimer from '@salesforce/label/c.AppUI_ESignatureDisclaimer';
import labelNameLabel from '@salesforce/label/c.AppUI_ESignatureNameLabel';
import labelNamePlaceholder from '@salesforce/label/c.AppUI_ESignatureNamePlaceholder';
import labelNameRequired from '@salesforce/label/c.AppUI_ESignatureNameRequired';
import labelTitle from '@salesforce/label/c.AppUI_ESignatureTitle';

export default class ESignature extends LightningElement {
  @api recordId;

  signatureName = '';
  validationError = '';
  isSaving = false;

  labels = {
    title: labelTitle,
    nameLabel: labelNameLabel,
    namePlaceholder: labelNamePlaceholder,
    dateLabel: labelDateLabel,
    clear: labelClear
  };

  get disclaimerText() {
    return labelDisclaimer;
  }

  get formattedDate() {
    return new Date().toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric'
    });
  }

  get signatureDateIso() {
    return new Intl.DateTimeFormat('en-CA', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    }).format(new Date());
  }

  get hasSignatureName() {
    return this.signatureName.trim().length > 0;
  }

  get isComplete() {
    return this.signatureName.trim() !== '';
  }

  handleNameChange(event) {
    this.signatureName = event.target.value;
    this.validationError = '';
  }

  handleClear() {
    this.signatureName = '';
    this.validationError = '';
  }

  @api
  validate() {
    this.validationError = '';

    if (!this.signatureName.trim()) {
      this.validationError = labelNameRequired;
      return false;
    }

    return true;
  }

  @api
  getSignatureData() {
    return {
      name: this.signatureName.trim(),
      date: this.signatureDateIso
    };
  }

  @api
  async flushAndSave() {
    if (!this.recordId || !this.isComplete) {
      return;
    }

    this.isSaving = true;
    try {
      const data = this.getSignatureData();
      await saveSignature({
        applicationId: this.recordId,
        name: data.name,
        signatureDate: data.date
      });
    } catch (err) {
      console.error('Failed to save signature:', err);
      throw err;
    } finally {
      this.isSaving = false;
    }
  }
}