import { LightningElement, api } from 'lwc';

const INPUT_TYPE_MAP = {
  Text: 'text',
  Email: 'email',
  Phone: 'tel',
  Number: 'number',
  Date: 'date'
};

export default class QuestionText extends LightningElement {
  @api question;
  @api value;

  get inputType() {
    return INPUT_TYPE_MAP[this.question?.inputType] || 'text';
  }

  @api
  reportValidity() {
    const input = this.template.querySelector('lightning-input');
    return input ? input.reportValidity() : true;
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