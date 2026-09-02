import { LightningElement, api } from 'lwc';
import getAddressQuestionValues from '@salesforce/apex/ApplicationQuestionController.getAddressQuestionValues';
import saveAddressQuestion from '@salesforce/apex/ApplicationQuestionController.saveAddressQuestion';
import labelApartment from '@salesforce/label/c.AppUI_FieldApartment';
import labelCity from '@salesforce/label/c.AppUI_FieldCity';
import labelState from '@salesforce/label/c.AppUI_FieldState';
import labelStreet from '@salesforce/label/c.AppUI_FieldStreet';
import labelZipCode from '@salesforce/label/c.AppUI_FieldZipCode';

const SLOT_KEYS = [
  'street',
  'city',
  'province',
  'postalCode',
  'country',
  'subpremise'
];
const DEFAULT_COUNTRY = 'US';
const SAVE_DEBOUNCE_MS = 600;

// Minimal US state options. Picklists are not enabled in the org, so we provide a
// fixed list rather than relying on lightning-input-address to pull schema metadata.
const US_STATE_OPTIONS = [
  'AL',
  'AK',
  'AZ',
  'AR',
  'CA',
  'CO',
  'CT',
  'DE',
  'FL',
  'GA',
  'HI',
  'ID',
  'IL',
  'IN',
  'IA',
  'KS',
  'KY',
  'LA',
  'ME',
  'MD',
  'MA',
  'MI',
  'MN',
  'MS',
  'MO',
  'MT',
  'NE',
  'NV',
  'NH',
  'NJ',
  'NM',
  'NY',
  'NC',
  'ND',
  'OH',
  'OK',
  'OR',
  'PA',
  'RI',
  'SC',
  'SD',
  'TN',
  'TX',
  'UT',
  'VT',
  'VA',
  'WA',
  'WV',
  'WI',
  'WY',
  'DC'
].map((code) => ({ label: code, value: code }));

const COUNTRY_OPTIONS = [{ label: 'United States', value: 'US' }];

export default class QuestionAddress extends LightningElement {
  @api question;
  @api recordId;
  @api readOnly = false;

  addressValues = {
    street: '',
    city: '',
    province: '',
    postalCode: '',
    country: DEFAULT_COUNTRY,
    subpremise: ''
  };

  _saveTimerId;
  _initialized = false;
  // True once the user edits a field. Guards against an incoming parent value
  // (re)seeding over live keystrokes.
  _userTouched = false;
  _value;

  // The compound address answer pushed down from the parent (its in-memory
  // answers map). When it carries data we seed the inputs from it instead of
  // waiting on the lazy Apex round-trip, so values survive a section
  // collapse/expand cycle (the parent keeps the answer; the server may not have
  // persisted the debounced save yet).
  @api
  get value() {
    return this._value;
  }
  set value(incoming) {
    this._value = incoming;
    // An explicit null (not undefined) is the parent deliberately clearing this
    // address — e.g. the student now lives at a DIFFERENT address, so the value
    // copied from the guardian must be wiped. Blank the inputs immediately and
    // do NOT fall back to the lazy server fetch (which still holds the stale
    // guardian copy until the async clear lands). Never clobber live edits.
    if (incoming === null && !this._userTouched) {
      this._resetToBlank();
      return;
    }
    this._seedFromValue(incoming);
  }

  connectedCallback() {
    // If the parent already handed us a non-empty value, prefer it and skip the
    // server fetch entirely. Otherwise fall back to the lazy Apex load.
    if (this._hasAddressData(this._value)) {
      this._initialized = true;
      return;
    }
    // An explicit null means this address was deliberately cleared (see the
    // value setter): stay blank instead of lazy-loading the stale server value.
    if (this._value === null) {
      this._resetToBlank();
      return;
    }
    this._loadInitial();
  }

  disconnectedCallback() {
    // Flush a scheduled-but-not-yet-fired debounced save before tearing down.
    // Collapsing the section unmounts this component; without flushing, the
    // pending saveAddressQuestion would be cancelled and the entered address
    // would never reach the server.
    if (this._saveTimerId && !this.readOnly && this._initialized) {
      clearTimeout(this._saveTimerId);
      this._saveTimerId = undefined;
      // Fire-and-forget: the goal is that the DML gets sent. We can't await on
      // disconnect, but the imperative Apex call is dispatched synchronously.
      this._persist();
    } else {
      clearTimeout(this._saveTimerId);
    }
  }

  get streetLabel() {
    return labelStreet;
  }

  get cityLabel() {
    return labelCity;
  }

  get stateLabel() {
    return labelState;
  }

  get zipLabel() {
    return labelZipCode;
  }

  get countryLabel() {
    return 'Country';
  }

  get apartmentLabel() {
    return labelApartment;
  }

  get addressLabel() {
    return this.question?.label || '';
  }

  // Human-readable single-line address for the read-only display. Mirrors the
  // values the editable widget would show: street (+ apartment), then
  // "City, ST Zip". Country is omitted because it is always US for this org.
  get formattedAddress() {
    const a = this.addressValues || {};
    const streetLine = [a.street, a.subpremise].filter(Boolean).join(', ');
    const cityState = [a.city, a.province].filter(Boolean).join(', ');
    const cityStateZip = [cityState, a.postalCode].filter(Boolean).join(' ');
    return [streetLine, cityStateZip].filter(Boolean).join(', ');
  }

  get lookupPlaceholder() {
    return 'Search address';
  }

  get stateOptions() {
    return US_STATE_OPTIONS;
  }

  get countryOptions() {
    return COUNTRY_OPTIONS;
  }

  // True when the compound carries any meaningful address data (country alone
  // is the default and doesn't count).
  _hasAddressData(v) {
    if (!v || typeof v !== 'object') {
      return false;
    }
    return Boolean(
      v.street || v.city || v.province || v.postalCode || v.subpremise
    );
  }

  // Wipe the inputs back to the empty default (country stays US, the org's only
  // option). Called when the parent deliberately clears this address via an
  // explicit null — e.g. "student lives at a DIFFERENT address" — so the value
  // copied from the guardian is removed and the parent enters the real one.
  // Marks the component initialized so the lazy server fetch is skipped.
  _resetToBlank() {
    this.addressValues = {
      street: '',
      city: '',
      province: '',
      postalCode: '',
      country: DEFAULT_COUNTRY,
      subpremise: ''
    };
    this._initialized = true;
  }

  // Seed addressValues from a parent-supplied compound. A non-empty incoming
  // value wins over the current (blank) state, but never clobbers live user
  // edits.
  _seedFromValue(incoming) {
    if (this._userTouched || !this._hasAddressData(incoming)) {
      return;
    }
    this.addressValues = {
      ...this.addressValues,
      ...incoming
    };
    if (!this.addressValues.country) {
      this.addressValues.country = DEFAULT_COUNTRY;
    }
    // We have a usable value already; no need for the lazy server fetch.
    this._initialized = true;
  }

  async _loadInitial() {
    if (!this.recordId || !this.question?.developerName) {
      this._initialized = true;
      return;
    }
    try {
      const data = await getAddressQuestionValues({
        applicationId: this.recordId,
        questionDeveloperName: this.question.developerName
      });
      // A non-empty parent value (or in-progress user edit) takes precedence
      // over a server fetch that may be stale/blank.
      if (data && !this._userTouched && !this._hasAddressData(this._value)) {
        this.addressValues = {
          ...this.addressValues,
          ...data
        };
        if (!this.addressValues.country) {
          this.addressValues.country = DEFAULT_COUNTRY;
        }
        if (data.street || data.city || data.postalCode || data.subpremise) {
          this._dispatchAnswerChange();
        }
      }
    } catch (err) {
      // Surface but don't break the form.
      // eslint-disable-next-line no-console
      console.error('Failed to load address question values:', err);
    } finally {
      this._initialized = true;
    }
  }

  @api
  reportValidity() {
    const input = this.template.querySelector('lightning-input-address');
    return input ? input.reportValidity() : true;
  }

  handleAddressChange(event) {
    this._userTouched = true;
    const next = { ...this.addressValues };
    SLOT_KEYS.forEach((slot) => {
      if (slot === 'subpremise') {
        return;
      }
      if (event.detail && event.detail[slot] !== undefined) {
        next[slot] = event.detail[slot] || '';
      }
    });
    this.addressValues = next;
    this._dispatchAnswerChange();
    this._scheduleSave();
  }

  handleApartmentChange(event) {
    this._userTouched = true;
    this.addressValues = {
      ...this.addressValues,
      subpremise: event.target.value || ''
    };
    this._dispatchAnswerChange();
    this._scheduleSave();
  }

  _dispatchAnswerChange() {
    if (!this.question?.developerName) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent('answerchange', {
        detail: {
          developerName: this.question.developerName,
          value: { ...this.addressValues }
        },
        bubbles: true,
        composed: true
      })
    );
  }

  _scheduleSave() {
    if (this.readOnly || !this.recordId || !this._initialized) {
      return;
    }
    clearTimeout(this._saveTimerId);
    this._saveTimerId = setTimeout(() => {
      this._persist();
    }, SAVE_DEBOUNCE_MS);
  }

  async _persist() {
    if (this.readOnly || !this.recordId || !this.question?.developerName) {
      return;
    }
    try {
      await saveAddressQuestion({
        applicationId: this.recordId,
        questionDeveloperName: this.question.developerName,
        payloadJson: JSON.stringify(this.addressValues)
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('Failed to save address question:', err);
    }
  }
}