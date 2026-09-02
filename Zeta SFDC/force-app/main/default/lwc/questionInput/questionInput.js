import { LightningElement, api } from 'lwc';

const TEXT_INPUT_TYPES = new Set(['Text', 'Email', 'Phone', 'Number', 'Date']);
const DROPDOWN_INPUT_TYPES = new Set(['Dropdown']);
const CHECKBOX_INPUT_TYPES = new Set(['Checkbox']);
const MULTI_CHECKBOX_INPUT_TYPES = new Set(['MultiCheckbox']);
const TEXTAREA_INPUT_TYPES = new Set(['TextArea']);
const ADDRESS_INPUT_TYPES = new Set(['Address']);

export default class QuestionInput extends LightningElement {
  @api question;
  @api value;
  @api recordId;
  @api readOnly = false;

  get isReadOnly() {
    return this.readOnly === true;
  }

  // Read-only scalar questions (everything except Address) render as plain
  // formatted text. Address is handled separately by isReadOnlyAddress because
  // its value is loaded lazily and is a compound object, not a scalar.
  get isReadOnlyScalar() {
    return (
      this.isReadOnly && !ADDRESS_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  get isText() {
    return !this.isReadOnly && TEXT_INPUT_TYPES.has(this.question?.inputType);
  }

  get isDropdown() {
    return (
      !this.isReadOnly && DROPDOWN_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  get isCheckbox() {
    return (
      !this.isReadOnly && CHECKBOX_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  get isMultiCheckbox() {
    return (
      !this.isReadOnly &&
      MULTI_CHECKBOX_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  get isTextArea() {
    return (
      !this.isReadOnly && TEXTAREA_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  get isAddress() {
    return (
      !this.isReadOnly && ADDRESS_INPUT_TYPES.has(this.question?.inputType)
    );
  }

  // Address questions load their own value lazily via Apex
  // (ApplicationQuestionController.getAddressQuestionValues) rather than through
  // the answers map, so they can't route through c-question-read-only (which
  // would render blank). Instead keep them on c-question-address, which renders
  // a formatted, non-editable display when read-only.
  get isReadOnlyAddress() {
    return this.isReadOnly && ADDRESS_INPUT_TYPES.has(this.question?.inputType);
  }

  @api
  reportValidity() {
    const leaf =
      this.template.querySelector('c-question-text') ||
      this.template.querySelector('c-question-dropdown') ||
      this.template.querySelector('c-question-checkbox') ||
      this.template.querySelector('c-question-checkbox-group') ||
      this.template.querySelector('c-question-text-area') ||
      this.template.querySelector('c-question-address') ||
      this.template.querySelector('c-question-read-only');
    return leaf ? leaf.reportValidity() : true;
  }
}