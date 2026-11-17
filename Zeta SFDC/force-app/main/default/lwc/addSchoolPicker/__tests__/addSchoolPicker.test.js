import { createElement } from 'lwc';
import AddSchoolPicker from 'c/addSchoolPicker';
import getEligibleSchools from '@salesforce/apex/SchoolSelectionController.getEligibleSchools';
import getRankedSchools from '@salesforce/apex/SchoolRankingController.getRankedSchools';
import addSchools from '@salesforce/apex/SchoolSelectionController.addSchools';

jest.mock(
  '@salesforce/apex/SchoolSelectionController.getEligibleSchools',
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  '@salesforce/apex/SchoolRankingController.getRankedSchools',
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  '@salesforce/apex/SchoolSelectionController.addSchools',
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const APPLICATION_ID = '0iT000000000001AAA';
// Gives pending promises eight turns to settle.
const flush = () => {
  let settled = Promise.resolve();
  for (let i = 0; i < 8; i++) settled = settled.then();
  return settled;
};

async function render() {
  const element = createElement('c-add-school-picker', { is: AddSchoolPicker });
  element.applicationId = APPLICATION_ID;
  document.body.appendChild(element);
  await flush();
  return element;
}

const checkboxes = (element) => [
  ...element.shadowRoot.querySelectorAll('lightning-input')
];
const saveButton = (element) =>
  [...element.shadowRoot.querySelectorAll('lightning-button')].find(
    (button) => button.label === 'c.AppUI_Save'
  );

async function chooseAndSave(element, schoolName) {
  const box = checkboxes(element).find((input) => input.label === schoolName);
  box.checked = true;
  box.dispatchEvent(new CustomEvent('change'));
  await flush();
  saveButton(element).click();
  await flush();
}

describe('c-add-school-picker', () => {
  beforeEach(() => {
    getEligibleSchools.mockResolvedValue({
      schools: [
        {
          schoolAccountId: '001A',
          lotteryCapacityId: 'a0X1',
          name: 'Zeta Bronx'
        },
        {
          schoolAccountId: '001B',
          lotteryCapacityId: 'a0X2',
          name: 'Zeta Harlem'
        }
      ]
    });
    getRankedSchools.mockResolvedValue([{ schoolAccountId: '001B' }]);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it('lists only the schools not on the application yet', async () => {
    const element = await render();

    expect(checkboxes(element).map((box) => box.label)).toEqual(['Zeta Bronx']);
    expect(saveButton(element).disabled).toBe(true);
  });

  it('says so when every school is already on the application', async () => {
    getRankedSchools.mockResolvedValue([
      { schoolAccountId: '001A' },
      { schoolAccountId: '001B' }
    ]);

    const element = await render();

    expect(element.shadowRoot.textContent).toContain('c.AppUI_AddSchoolsNone');
    expect(saveButton(element).disabled).toBe(true);
  });

  it('adds the chosen schools and tells the parent', async () => {
    addSchools.mockResolvedValue(undefined);
    const element = await render();
    const added = jest.fn();
    element.addEventListener('schoolsadded', added);

    await chooseAndSave(element, 'Zeta Bronx');

    expect(addSchools).toHaveBeenCalledWith({
      applicationId: APPLICATION_ID,
      lotteryCapacityIds: ['a0X1']
    });
    expect(added).toHaveBeenCalledTimes(1);
  });

  it('shows the error when adding fails', async () => {
    addSchools.mockRejectedValue({
      body: { message: 'The application window is closed.' }
    });
    const element = await render();

    await chooseAndSave(element, 'Zeta Bronx');

    expect(element.shadowRoot.textContent).toContain(
      'The application window is closed.'
    );
  });
});
