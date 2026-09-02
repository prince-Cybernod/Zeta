import { LightningElement, api } from 'lwc';

export default class QuestionTextArea extends LightningElement {
  @api question;
  @api value;
  @api readOnly = false;

  @api
  reportValidity() {
    const textarea = this.template.querySelector('lightning-textarea');
    return textarea ? textarea.reportValidity() : true;
  }

  handleChange(event) {
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: {
          developerName: this.question.developerName,
          value: event.target.value
        },
        bubbles: true,
        composed: true
      })
    );
  }
}