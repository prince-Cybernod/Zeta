import { LightningElement, api } from 'lwc';

export default class QuestionCheckboxGroup extends LightningElement {
  @api question;
  @api value;
  @api readOnly = false;

  get selectedValues() {
    if (!this.value) {
      return [];
    }
    if (Array.isArray(this.value)) {
      return this.value;
    }
    return String(this.value).split(';').filter(Boolean);
  }

  @api
  reportValidity() {
    const group = this.template.querySelector('lightning-checkbox-group');
    return group ? group.reportValidity() : true;
  }

  handleChange(event) {
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: {
          developerName: this.question.developerName,
          value: event.detail.value.join(';')
        },
        bubbles: true,
        composed: true
      })
    );
  }
}