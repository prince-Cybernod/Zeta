import { LightningElement, api } from 'lwc';

export default class QuestionDropdown extends LightningElement {
  @api question;
  @api value;

  @api
  reportValidity() {
    const combobox = this.template.querySelector('lightning-combobox');
    return combobox ? combobox.reportValidity() : true;
  }

  get dropdownOptions() {
    const opts = this.question?.options || [];
    if (!this.question?.isRequired) {
      return [{ label: '--None--', value: '' }, ...opts];
    }
    return opts;
  }

  get placeholderText() {
    return this.question?.placeholder || 'Select an option';
  }

  handleChange(event) {
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: {
          developerName: this.question.developerName,
          value: event.detail.value
        },
        bubbles: true,
        composed: true
      })
    );
  }
}