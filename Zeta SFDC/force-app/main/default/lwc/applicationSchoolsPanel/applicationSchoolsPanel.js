import { LightningElement, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import labelSave from '@salesforce/label/c.AppUI_Save';
import labelSaving from '@salesforce/label/c.AppUI_Saving';
import labelSchoolRankingsSaved from '@salesforce/label/c.AppUI_SchoolRankingsSaved';
import labelSchoolSelectionsSaved from '@salesforce/label/c.AppUI_SchoolSelectionsSaved';
import labelSchoolsRankingEmptyState from '@salesforce/label/c.AppUI_SchoolsRankingEmptyState';
import labelSelectionsLockedAfterSubmission from '@salesforce/label/c.AppUI_SelectionsLockedAfterSubmission';
import APPLICATION_TIMELINE_FIELD from '@salesforce/schema/IndividualApplication.Application_Timeline__c';
import APPLIED_DATE_FIELD from '@salesforce/schema/IndividualApplication.AppliedDate';
import GRADE_APPLYING_TO_FIELD from '@salesforce/schema/IndividualApplication.Grade_Applying_To__c';
import { ErrorHandler } from 'c/errorHandler';

const FIELDS = [
  GRADE_APPLYING_TO_FIELD,
  APPLICATION_TIMELINE_FIELD,
  APPLIED_DATE_FIELD
];

/**
 * Internal-record-page wrapper hosting the shared school selection + ranking
 * components (schoolSelection / schoolRanking) outside the community-scoped
 * zetaApplication wizard. Both children take only recordId and re-derive
 * eligibility server-side from Grade_Applying_To__c + Application_Timeline__c,
 * so this wrapper's only job is mount/save/refresh orchestration.
 */
export default class ApplicationSchoolsPanel extends LightningElement {
  @api recordId;

  isLoading = true;
  error;
  isSelectionSaving = false;
  isRankingSaving = false;

  _grade;
  _timeline;
  _appliedDate;
  _rankingRefreshNonce = 0;

  labels = {
    emptyState: labelSchoolsRankingEmptyState,
    selectionsLocked: labelSelectionsLockedAfterSubmission
  };

  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  wiredApplication({ data, error }) {
    if (data) {
      this._grade = getFieldValue(data, GRADE_APPLYING_TO_FIELD);
      this._timeline = getFieldValue(data, APPLICATION_TIMELINE_FIELD);
      this._appliedDate = getFieldValue(data, APPLIED_DATE_FIELD);
      this.error = undefined;
    } else if (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
    }
    this.isLoading = false;
  }

  get hasGradeAndTimeline() {
    return !!(this._grade && this._timeline);
  }

  get isPreSubmit() {
    return this._appliedDate == null;
  }

  get showEmptyState() {
    return !this.isLoading && !this.error && !this.hasGradeAndTimeline;
  }

  get showPanels() {
    return !this.isLoading && !this.error && this.hasGradeAndTimeline;
  }

  // Grade/timeline drive eligibility server-side (SchoolSelectionController.cls)
  // — re-key both children on either change so they refetch instead of saving
  // a selection against a stale eligibility set.
  get childrenKey() {
    return `${this._grade}::${this._timeline}`;
  }

  // Additionally bumped after a selection save so the ranking list picks up
  // added/removed schools without waiting on a grade/timeline change.
  get rankingKey() {
    return `${this.childrenKey}::${this._rankingRefreshNonce}`;
  }

  // Single-item arrays so the children render via for:each — LWC's keyed
  // diffing (which actually tears down and remounts on a key change) only
  // applies to for:each children, not a bare key= on a static sibling.
  get childrenKeys() {
    return [this.childrenKey];
  }

  get rankingKeys() {
    return [this.rankingKey];
  }

  get selectionSaveButtonLabel() {
    return this.isSelectionSaving ? labelSaving : labelSave;
  }

  get rankingSaveButtonLabel() {
    return this.isRankingSaving ? labelSaving : labelSave;
  }

  async handleSaveSelection() {
    const el = this.template.querySelector('c-school-selection');
    if (!el || !el.validate()) {
      return;
    }
    this.isSelectionSaving = true;
    try {
      await el.flushAndSave();
      this._rankingRefreshNonce += 1;
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: labelSchoolSelectionsSaved,
          variant: 'success'
        })
      );
    } catch (err) {
      ErrorHandler.toast(this, err);
    } finally {
      this.isSelectionSaving = false;
    }
  }

  async handleSaveRanking() {
    const el = this.template.querySelector('c-school-ranking');
    if (!el || !el.validate()) {
      return;
    }
    this.isRankingSaving = true;
    try {
      await el.flushAndSave();
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: labelSchoolRankingsSaved,
          variant: 'success'
        })
      );
    } catch (err) {
      ErrorHandler.toast(this, err);
    } finally {
      this.isRankingSaving = false;
    }
  }
}