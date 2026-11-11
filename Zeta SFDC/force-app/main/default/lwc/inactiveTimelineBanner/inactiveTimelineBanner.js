import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import APPLICATION_TIMELINE_ACTIVE_FIELD from '@salesforce/schema/IndividualApplication.Application_Timeline__r.Active__c';
import APPLICATION_TIMELINE_NAME_FIELD from '@salesforce/schema/IndividualApplication.Application_Timeline__r.Name';
import SCHOOL_APPLICATION_TIMELINE_ACTIVE_FIELD from '@salesforce/schema/AcademicInterest.IndividualApplication.Application_Timeline__r.Active__c';
import SCHOOL_APPLICATION_TIMELINE_NAME_FIELD from '@salesforce/schema/AcademicInterest.IndividualApplication.Application_Timeline__r.Name';

// The timeline each page reads: its own, or its application's for a School Application.
const TIMELINE_FIELDS = {
  IndividualApplication: {
    name: APPLICATION_TIMELINE_NAME_FIELD,
    active: APPLICATION_TIMELINE_ACTIVE_FIELD
  },
  AcademicInterest: {
    name: SCHOOL_APPLICATION_TIMELINE_NAME_FIELD,
    active: SCHOOL_APPLICATION_TIMELINE_ACTIVE_FIELD
  }
};

/**
 * Red banner naming the application timeline when that timeline is inactive, shown at
 * the top of Individual and School Application pages (SFR-188).
 */
export default class InactiveTimelineBanner extends LightningElement {
  @api recordId;
  @api objectApiName;

  record;

  get timelineFields() {
    return TIMELINE_FIELDS[this.objectApiName];
  }

  // optionalFields, so someone who can't see the timeline gets no banner instead of an error.
  get fields() {
    const timeline = this.timelineFields;
    return timeline ? [timeline.name, timeline.active] : undefined;
  }

  @wire(getRecord, { recordId: '$recordId', optionalFields: '$fields' })
  wiredRecord({ data }) {
    this.record = data;
  }

  get timelineName() {
    return getFieldValue(this.record, this.timelineFields.name);
  }

  get isInactive() {
    return (
      Boolean(this.record && this.timelineName) &&
      getFieldValue(this.record, this.timelineFields.active) === false
    );
  }
}
