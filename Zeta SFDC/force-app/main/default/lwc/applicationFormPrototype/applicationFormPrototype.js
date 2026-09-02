import { LightningElement, track } from 'lwc';

export default class ApplicationFormPrototype extends LightningElement {
  @track inputPageDevName = 'Framework_Verification';
  @track inputVariant = '';
  @track inputRecordId = '';
  @track inputReadOnly = false;

  @track activePageDevName;
  @track activeVariant;
  @track activeRecordId;
  @track activeReadOnly = false;

  isFormVisible = false;

  get variantOptions() {
    return [
      { label: '(none)', value: '' },
      { label: 'Elementary', value: 'Elementary' },
      { label: 'Middle', value: 'Middle' },
      { label: 'High', value: 'High' }
    ];
  }

  handlePageDevNameChange(event) {
    this.inputPageDevName = event.detail.value;
  }

  handleVariantChange(event) {
    this.inputVariant = event.detail.value;
  }

  handleRecordIdChange(event) {
    this.inputRecordId = event.detail.value;
  }

  handleReadOnlyChange(event) {
    this.inputReadOnly = event.target.checked;
  }

  handleLoad() {
    this.isFormVisible = false;
    this.activePageDevName = this.inputPageDevName;
    this.activeVariant = this.inputVariant || undefined;
    this.activeRecordId = this.inputRecordId || undefined;
    this.activeReadOnly = this.inputReadOnly;
    // Force re-render by toggling visibility in next microtask
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this.isFormVisible = true;
    }, 0);
  }
}