import { LightningElement, api } from 'lwc';

export default class QuestionReadOnly extends LightningElement {
  @api question;
  @api value;

  // Checkbox answers are booleans/null, which render blank through
  // lightning-formatted-text. On the read-only review screen we instead show an
  // explicit Yes/No so parents can see their email/SMS opt-in choices before
  // submitting. Inversion mirrors questionCheckbox: some checkboxes display the
  // logical inverse of their backing field (Invert_Display__c = true).
  get isCheckbox() {
    return this.question?.inputType === 'Checkbox';
  }

  get invertDisplay() {
    return this.question?.invertDisplay === true;
  }

  get displayChecked() {
    return this.invertDisplay ? this.value !== true : this.value === true;
  }

  get displayValue() {
    return this.displayChecked ? 'Yes' : 'No';
  }

  @api
  reportValidity() {
    return true;
  }
}