import { createElement } from 'lwc';
import InactiveTimelineBanner from 'c/inactiveTimelineBanner';
import { getRecord } from 'lightning/uiRecordApi';

function timeline(name, active) {
  if (name === undefined) {
    return null;
  }
  return {
    apiName: 'ApplicationTimeline',
    fields: { Name: { value: name }, Active__c: { value: active } }
  };
}

const individualApplication = (name, active) => ({
  apiName: 'IndividualApplication',
  fields: { Application_Timeline__r: { value: timeline(name, active) } }
});

const schoolApplication = (name, active) => ({
  apiName: 'AcademicInterest',
  fields: {
    IndividualApplication: { value: individualApplication(name, active) }
  }
});

function render(objectApiName) {
  const element = createElement('c-inactive-timeline-banner', {
    is: InactiveTimelineBanner
  });
  element.recordId = '0iT000000000001AAA';
  element.objectApiName = objectApiName;
  document.body.appendChild(element);
  return element;
}

const banner = (element) => element.shadowRoot.querySelector('[role="alert"]');
function apiName(field) {
  return typeof field === 'string'
    ? field
    : `${field.objectApiName}.${field.fieldApiName}`;
}

describe('c-inactive-timeline-banner', () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it.each([
    ['IndividualApplication', individualApplication],
    ['AcademicInterest', schoolApplication]
  ])(
    'shows the red banner with the timeline name when the %s timeline is inactive',
    async (objectApiName, build) => {
      const element = render(objectApiName);
      getRecord.emit(build('SY 2025-2026', false));
      await Promise.resolve();

      expect(banner(element).textContent).toContain(
        'Inactive Application Timeline: SY 2025-2026'
      );
    }
  );

  it('hides the banner when the timeline is active', async () => {
    const element = render('IndividualApplication');
    getRecord.emit(individualApplication('E2E: 2027-2028', true));
    await Promise.resolve();

    expect(banner(element)).toBeNull();
  });

  it('hides the banner when the application has no timeline', async () => {
    const element = render('IndividualApplication');
    getRecord.emit(individualApplication());
    await Promise.resolve();

    expect(banner(element)).toBeNull();
  });

  // Field requests are compared by their API names, so the test checks the real fields.
  it.each([
    [
      'IndividualApplication',
      [
        'IndividualApplication.Application_Timeline__r.Name',
        'IndividualApplication.Application_Timeline__r.Active__c'
      ]
    ],
    [
      'AcademicInterest',
      [
        'AcademicInterest.IndividualApplication.Application_Timeline__r.Name',
        'AcademicInterest.IndividualApplication.Application_Timeline__r.Active__c'
      ]
    ]
  ])(
    'asks only for the timeline fields on the %s page',
    async (objectApiName, fields) => {
      render(objectApiName);
      await Promise.resolve();

      const config = getRecord.getLastConfig();
      expect(config.recordId).toBe('0iT000000000001AAA');
      expect(config.optionalFields.map(apiName)).toEqual(fields);
    }
  );

  it('shows nothing before the record loads', () => {
    const element = render('IndividualApplication');

    expect(banner(element)).toBeNull();
  });

  it("shows nothing when the record can't be read", async () => {
    const element = render('IndividualApplication');
    getRecord.error();
    await Promise.resolve();

    expect(banner(element)).toBeNull();
  });

  it("shows nothing on a page it wasn't built for", () => {
    const element = render('Lead');

    expect(banner(element)).toBeNull();
  });
});
