import { LightningElement, api } from 'lwc';
import labelCommPrefsOptOutWarning from '@salesforce/label/c.AppUI_CommPrefsOptOutWarning';
import labelCommPrefsValidationError from '@salesforce/label/c.AppUI_CommPrefsValidationError';
import labelPrivacyPolicyText from '@salesforce/label/c.AppUI_PrivacyPolicyText';
import labelPrivacyPolicyUrl from '@salesforce/label/c.AppUI_PrivacyPolicyUrl';
import labelTextMessageConsentBody from '@salesforce/label/c.AppUI_TextMessageConsentBody';
import { renderSummary } from './summaryTemplateRenderer';

export default class ApplicationSection extends LightningElement {
  @api section;
  @api answers = {};
  @api recordId;
  @api readOnly = false;
  @api visibilityMap = {};
  @api visibilityResolved = false;

  _commPrefsError = false;
  // Sections never auto-collapse on completion (that jump was jarring). They
  // render expanded by default; the parent may click "Collapse" to tuck a
  // finished section into its summary, and "Edit" to bring it back.
  // _userCollapsed tracks that explicit choice (false = expanded).
  _userCollapsed = false;

  get isCommPrefsSection() {
    return this.section?.developerName === 'Communication_Preferences';
  }

  get showCommPrefsError() {
    return this._commPrefsError;
  }

  get commPrefsValidationMessage() {
    return labelCommPrefsValidationError;
  }

  get showEmailOptOutWarning() {
    return this.isCommPrefsSection && this.answers.Email_Opt_Out === true;
  }

  get emailOptOutWarningMessage() {
    return labelCommPrefsOptOutWarning.replace(
      '{0}',
      'email communications with more information'
    );
  }

  get showTextOptOutWarning() {
    return (
      this.isCommPrefsSection && this.answers.Text_Message_Opt_Out === true
    );
  }

  get textOptOutWarningMessage() {
    return labelCommPrefsOptOutWarning.replace('{0}', 'text message updates');
  }

  get showTextOptInConsent() {
    return this.isCommPrefsSection && this.answers.Text_Message_Opt_In === true;
  }

  get textOptInConsentMessage() {
    return labelTextMessageConsentBody;
  }

  get showPrivacyLink() {
    return this.isCommPrefsSection;
  }

  get privacyPolicyUrl() {
    return labelPrivacyPolicyUrl;
  }

  get privacyPolicyText() {
    return labelPrivacyPolicyText;
  }

  get gridClass() {
    const cols = this.section?.columns;
    const variant = this.section?.variant;
    let cls;
    if (cols === 3) cls = 'question-grid three-column';
    else if (cols === 2) cls = 'question-grid two-column';
    else cls = 'question-grid one-column';
    if (variant === 'toggle-grid') cls += ' toggle-grid';
    return cls;
  }

  get enrichedQuestions() {
    if (!this.section?.questions) {
      return [];
    }
    const sectionColumns = this.section?.columns || 1;
    return this.section.questions
      .filter((q) => this._isQuestionVisible(q))
      .map((q) => {
        const requestedSpan = Number(q.columnSpan) || 1;
        const span = Math.min(Math.max(requestedSpan, 1), sectionColumns);
        let itemClass = 'question-item';
        if (span === 2) itemClass += ' span-2';
        else if (span >= 3) itemClass += ' span-3';
        return {
          ...q,
          // Address inputs need to distinguish "never set" (undefined -> lazy
          // load from the server) from "deliberately cleared" (null -> render
          // blank). Coalescing null to '' would collapse the two, so pass the
          // raw answer through for Address questions only.
          currentValue:
            q.inputType === 'Address'
              ? this.answers[q.developerName]
              : (this.answers[q.developerName] ?? q.defaultValue ?? ''),
          itemClass
        };
      });
  }

  _isQuestionVisible(question) {
    if (!question.hasVisibilityRule) {
      return true;
    }
    if (!this.visibilityResolved) {
      return false;
    }
    const visibility = this.visibilityMap[question.developerName];
    return visibility !== false;
  }

  get _stateQuestions() {
    return this.enrichedQuestions;
  }

  get sectionState() {
    if (!this.section?.collapsible) {
      return 'always-expanded';
    }
    const qs = this._stateQuestions;
    if (qs.length === 0) {
      return 'untouched';
    }
    const requiredQs = qs.filter((q) => q.isRequired);
    let filledRequired = 0;
    let anyFilled = false;
    for (const q of qs) {
      const value = this.answers[q.developerName];
      const blank = isAnswerBlank(value);
      if (!blank) {
        anyFilled = true;
        if (q.isRequired) {
          filledRequired += 1;
        }
      }
    }
    if (!anyFilled) {
      return 'untouched';
    }
    // A section with no required questions has nothing left to complete once it
    // has been touched — treat it as complete. Without this, a collapsible
    // section that is required only by custom logic (e.g. Communication
    // Preferences, whose questions aren't flagged required) would fall through
    // to 'incomplete' the moment the parent fills it, silently blocking the
    // wizard's validateForm() with no inline error.
    if (filledRequired === requiredQs.length) {
      return 'complete';
    }
    return 'incomplete';
  }

  get isCollapsedRender() {
    return (
      this.section?.collapsible === true &&
      this.sectionState === 'complete' &&
      this._userCollapsed === true &&
      !this.readOnly
    );
  }

  get isExpandedRender() {
    return !this.isCollapsedRender;
  }

  get canCollapse() {
    // Offer the manual Collapse button once a collapsible section is complete
    // and currently expanded.
    return (
      this.section?.collapsible === true &&
      this.sectionState === 'complete' &&
      this._userCollapsed === false &&
      !this.readOnly
    );
  }

  handleCollapseClick(event) {
    event?.stopPropagation();
    this._userCollapsed = true;
  }

  get summaryText() {
    const template = this.section?.summaryTemplate;
    if (template) {
      const rendered = renderSummary(template, this.answers || {});
      if (rendered) {
        return rendered;
      }
    }
    return this.section?.label || '';
  }

  @api
  forceExpand() {
    this._userCollapsed = false;
  }

  handleEditClick(event) {
    event?.stopPropagation();
    this._userCollapsed = false;
  }

  handleSummaryKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this._userCollapsed = false;
    }
  }

  @api
  getSectionState() {
    return this.sectionState;
  }

  @api
  reportValidity() {
    const inputs = this.template.querySelectorAll('c-question-input');
    let allValid = true;
    inputs.forEach((input) => {
      if (!input.reportValidity()) {
        allValid = false;
      }
    });

    if (this.isCommPrefsSection) {
      const emailChosen =
        this.answers.Email_Consent === true ||
        this.answers.Email_Opt_Out === true;
      const textChosen =
        this.answers.Text_Message_Opt_In === true ||
        this.answers.Text_Message_Opt_Out === true;
      if (!emailChosen || !textChosen) {
        this._commPrefsError = true;
        allValid = false;
      } else {
        this._commPrefsError = false;
      }
    }

    return allValid;
  }
}

function isAnswerBlank(value) {
  if (value === null || value === undefined) return true;
  if (typeof value === 'string') return value === '';
  if (Array.isArray(value)) return value.length === 0;
  if (typeof value === 'object') {
    // Address compound: blank when no street / city / postal code is set.
    // (A default country alone isn't user input — don't count it.)
    if ('street' in value || 'city' in value || 'postalCode' in value) {
      return !value.street && !value.city && !value.postalCode;
    }
    return !Object.values(value).some(
      (v) => v !== null && v !== undefined && v !== ''
    );
  }
  return false;
}