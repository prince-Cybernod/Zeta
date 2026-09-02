import { LightningElement, api } from 'lwc';

export default class QuestionCheckbox extends LightningElement {
  @api question;
  @api value;
  @api readOnly = false;

  // Some checkboxes display the logical INVERSE of their backing boolean field
  // (Application_Question.Invert_Display__c = true). e.g. "Student lives at a
  // different address" is checked precisely when Lives_With_Guardian_1__c is
  // false. The answers map always stores the REAL field value, so visibility
  // rules and companion writeback are unaffected — only the rendered box flips.
  get invertDisplay() {
    return this.question?.invertDisplay === true;
  }

  get displayChecked() {
    return this.invertDisplay ? this.value !== true : this.value;
  }

  @api
  reportValidity() {
    const input = this.template.querySelector('lightning-input');
    return input ? input.reportValidity() : true;
  }

  handleChange(event) {
    const checked = event.target.checked;
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: {
          developerName: this.question.developerName,
          value: this.invertDisplay ? !checked : checked
        },
        bubbles: true,
        composed: true
      })
    );
  }
}