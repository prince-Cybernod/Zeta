import { LightningElement, api } from 'lwc';

const PICKLIST_INPUT_TYPES = new Set(['Dropdown', 'MultiCheckbox']);
const MULTI_VALUE_DELIMITER = ';';

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

  get isPicklist() {
    return PICKLIST_INPUT_TYPES.has(this.question?.inputType);
  }

  // Options carry the schema labels (AppQuestionOption.fromDescribe). Until they
  // arrive with the question the control stays empty rather than falling back to
  // the stored API value, which would show e.g. "3" instead of "3rd Grade".
  get isResolvedPicklist() {
    return this.isPicklist && this._optionLabels.size > 0;
  }

  get isPlainValue() {
    return !this.isCheckbox && !this.isPicklist;
  }

  get picklistDisplayValue() {
    if (this.value === null || this.value === undefined || this.value === '') {
      return '';
    }
    const labels = this._optionLabels;
    return String(this.value)
      .split(MULTI_VALUE_DELIMITER)
      .filter(Boolean)
      .map((v) => (labels.has(v) ? labels.get(v) : v))
      .join(', ');
  }

  get _optionLabels() {
    const options = this.question?.options;
    if (!Array.isArray(options)) {
      return new Map();
    }
    return new Map(options.map((o) => [o.value, o.label]));
  }

  @api
  reportValidity() {
    return true;
  }
}