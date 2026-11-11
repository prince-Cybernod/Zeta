import { createElement } from 'lwc';
import ApplicationStatusPath from 'c/applicationStatusPath';
import { getRecord } from 'lightning/uiRecordApi';

const record = (objectApiName, status) => ({
  apiName: objectApiName,
  fields: { Status: { value: status } }
});

function render(objectApiName) {
  const element = createElement('c-application-status-path', {
    is: ApplicationStatusPath
  });
  element.recordId = '0iT000000000001AAA';
  element.objectApiName = objectApiName;
  document.body.appendChild(element);
  return element;
}

async function renderWithStatus(objectApiName, status) {
  const element = render(objectApiName);
  getRecord.emit(record(objectApiName, status));
  await Promise.resolve();
  return element;
}

const steps = (element) => [...element.shadowRoot.querySelectorAll('li')];
const labels = (element) =>
  steps(element).map((step) => step.textContent.trim());
const current = (element) =>
  steps(element).filter((step) => step.getAttribute('aria-current') === 'true');
function apiName(field) {
  return typeof field === 'string'
    ? field
    : `${field.objectApiName}.${field.fieldApiName}`;
}

describe('c-application-status-path', () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it('shows the four statuses in order on the Individual Application page', async () => {
    const element = await renderWithStatus('IndividualApplication', 'Applied');

    expect(labels(element)).toEqual([
      'Draft',
      'Applied',
      'Eligible',
      'Withdrawn/Declined'
    ]);
  });

  it('shows the eleven statuses in order on the School Application page', async () => {
    const element = await renderWithStatus('AcademicInterest', 'Applied');

    expect(labels(element)).toEqual([
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
    ]);
  });

  // Colors from the SFR-188 ticket, plus Mercedes's answer for the School Application statuses.
  it.each([
    ['IndividualApplication', 'Draft', 'yellow'],
    ['IndividualApplication', 'Applied', 'blue'],
    ['IndividualApplication', 'Eligible', 'green'],
    ['IndividualApplication', 'Withdrawn/Declined', 'red'],
    ['AcademicInterest', 'Draft', 'yellow'],
    ['AcademicInterest', 'Applied', 'blue'],
    ['AcademicInterest', 'Submitted', 'blue'],
    ['AcademicInterest', 'Eligible', 'green'],
    ['AcademicInterest', 'Withdrawn/Declined', 'red'],
    ['AcademicInterest', 'Pre-Offer', 'blue'],
    ['AcademicInterest', 'Seat Offered', 'green'],
    ['AcademicInterest', 'Waitlisted', 'red'],
    ['AcademicInterest', 'Seat Accepted', 'green'],
    ['AcademicInterest', 'Offer Rescinded due to Seat Optimization', 'red'],
    ['AcademicInterest', 'Rescinded', 'red']
  ])(
    'on the %s page lights up only %s, in %s',
    async (objectApiName, status, color) => {
      const element = await renderWithStatus(objectApiName, status);

      const lit = current(element);
      expect(lit).toHaveLength(1);
      expect(lit[0].textContent.trim()).toBe(status);
      expect(lit[0].classList).toContain(color);
    }
  );

  // Field requests are compared by their API names, so the test checks the real fields.
  it.each([
    ['IndividualApplication', 'IndividualApplication.Status'],
    ['AcademicInterest', 'AcademicInterest.Status']
  ])('reads the status field of the %s page', async (objectApiName, field) => {
    render(objectApiName);
    await Promise.resolve();

    const config = getRecord.getLastConfig();
    expect(config.recordId).toBe('0iT000000000001AAA');
    expect(config.fields.map(apiName)).toEqual([field]);
  });

  it("asks for no record on a page it wasn't built for", async () => {
    render('Lead');
    await Promise.resolve();

    expect(getRecord.getLastConfig().fields).toBeUndefined();
  });

  it('has no button to change the status', async () => {
    const element = await renderWithStatus('IndividualApplication', 'Applied');

    expect(
      element.shadowRoot.querySelector('button, lightning-button')
    ).toBeNull();
  });

  it("lights up nothing for a status the page doesn't show", async () => {
    const element = await renderWithStatus(
      'IndividualApplication',
      'Submitted'
    );

    expect(steps(element)).toHaveLength(4);
    expect(current(element)).toHaveLength(0);
  });

  it('shows nothing before the record loads', () => {
    const element = render('IndividualApplication');

    expect(steps(element)).toHaveLength(0);
  });

  it("shows nothing when the record can't be read", async () => {
    const element = render('IndividualApplication');
    getRecord.error();
    await Promise.resolve();

    expect(steps(element)).toHaveLength(0);
  });
});
