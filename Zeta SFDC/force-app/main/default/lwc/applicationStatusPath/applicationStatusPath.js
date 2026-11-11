import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import APPLICATION_STATUS_FIELD from '@salesforce/schema/IndividualApplication.Status';
import SCHOOL_APPLICATION_STATUS_FIELD from '@salesforce/schema/AcademicInterest.Status';

// The color each status lights up in (SFR-188 ticket, plus Mercedes's answer for the
// School Application statuses).
const COLORS = {
  Draft: 'yellow',
  Applied: 'blue',
  Submitted: 'blue',
  Eligible: 'green',
  'Withdrawn/Declined': 'red',
  'Pre-Offer': 'blue',
  'Seat Offered': 'green',
  Waitlisted: 'red',
  'Seat Accepted': 'green',
  'Offer Rescinded due to Seat Optimization': 'red',
  Rescinded: 'red'
};

// Each page's status field, and its statuses in the order they show.
const PAGES = {
  IndividualApplication: {
    field: APPLICATION_STATUS_FIELD,
    statuses: ['Draft', 'Applied', 'Eligible', 'Withdrawn/Declined']
  },
  AcademicInterest: {
    field: SCHOOL_APPLICATION_STATUS_FIELD,
    statuses: [
      'Draft',
      'Submitted',
      'Applied',
      'Eligible',
      'Waitlisted',
      'Pre-Offer',
      'Seat Offered',
      'Seat Accepted',
      'Offer Rescinded due to Seat Optimization',
      'Rescinded',
      'Withdrawn/Declined'
    ]
  }
};

/**
 * Display-only status row for Individual and School Application pages: shows every status
 * and lights up the current one in its color. It has no button and nothing to click, so
 * the status only changes by editing the field.
 */
export default class ApplicationStatusPath extends LightningElement {
  @api recordId;
  @api objectApiName;

  status;

  get page() {
    return PAGES[this.objectApiName];
  }

  get fields() {
    return this.page ? [this.page.field] : undefined;
  }

  @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
  wiredApplication({ data }) {
    this.status = data ? getFieldValue(data, this.page.field) : undefined;
  }

  get statuses() {
    return this.page.statuses.map((value) => {
      const isCurrent = value === this.status;
      return {
        value,
        className: isCurrent ? `step current ${COLORS[value]}` : 'step',
        ariaCurrent: String(isCurrent)
      };
    });
  }
}
