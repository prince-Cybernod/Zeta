import { createElement } from "lwc";
import LeadSiblingFlags from "c/leadSiblingFlags";
import getMatches from "@salesforce/apex/LeadSiblingFlagsController.getMatches";
import getLeadComparison from "@salesforce/apex/LeadSiblingFlagsController.getLeadComparison";
import mergeLeads from "@salesforce/apex/LeadSiblingFlagsController.mergeLeads";
import { refreshApex } from "@salesforce/apex";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import Toast from "lightning/toast";

jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn() }), {
  virtual: true
});
jest.mock(
  "@salesforce/apex/LeadSiblingFlagsController.getMatches",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LeadSiblingFlagsController.getLeadComparison",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/LeadSiblingFlagsController.mergeLeads",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock("lightning/uiRecordApi", () => ({
  notifyRecordUpdateAvailable: jest.fn()
}));
jest.mock("lightning/toast", () => ({
  __esModule: true,
  default: { show: jest.fn() }
}));
const mockNavigate = jest.fn();
jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](page) {
        mockNavigate(page);
      }
    };
  NavigationMixin.Navigate = Navigate;
  return { NavigationMixin };
});

const comparison = [
  {
    Id: "current",
    Name: "Current child",
    FirstName: "Current",
    LastName: "Child",
    Phone: "111",
    LastModifiedDate: "2026-09-16T12:00:00.000Z"
  },
  {
    Id: "sibling",
    Name: "Duplicate child",
    FirstName: "Duplicate",
    LastName: "Child",
    Phone: "222",
    LastModifiedDate: "2026-09-16T12:00:00.000Z"
  }
];
const empty = {
  currentLead: comparison[0],
  leads: [],
  applicants: [],
  enrolled: [],
  limited: false
};
const household = {
  ...empty,
  leads: [comparison[1]],
  applicants: [
    {
      Id: "student",
      Name: "Applicant",
      RecordType: { Name: "Student" },
      IndividualApplicationAccount: [{ Status: "Applied" }]
    }
  ]
};
const flush = async () => {
  for (let i = 0; i < 8; i++) await Promise.resolve();
};
const find = (element, selector) => element.shadowRoot.querySelector(selector);
const endAnimation = async (element, selector) => {
  find(element, selector).dispatchEvent(
    new Event("animationend", { bubbles: true })
  );
  await flush();
};
const click = async (element, action) => {
  find(element, `[data-action="${action}"]`).click();
  await flush();
};
const change = async (element, selector, checked = true) => {
  find(element, selector).dispatchEvent(
    new CustomEvent("change", { detail: { checked } })
  );
  await flush();
};

async function mount(data = household, open = true) {
  const element = createElement("c-lead-sibling-flags", {
    is: LeadSiblingFlags
  });
  element.recordId = "current";
  document.body.appendChild(element);
  getMatches.emit(data);
  await flush();
  if (open) await click(element, "view");
  return element;
}
async function confirm(element, primaryId) {
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  if (primaryId) {
    const primary = [
      ...element.shadowRoot.querySelectorAll(`[data-record="${primaryId}"]`)
    ].find((input) => input.name === "primaryLead");
    primary.dispatchEvent(
      new CustomEvent("change", { detail: { checked: true } })
    );
    await flush();
  }
  await click(element, "confirm");
  await change(element, "[data-confirm]");
}

beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute("open", "");
  };
  HTMLDialogElement.prototype.close = function () {
    this.removeAttribute("open");
  };
});
beforeEach(() => {
  refreshApex.mockResolvedValue();
  notifyRecordUpdateAvailable.mockResolvedValue();
  getLeadComparison.mockResolvedValue(comparison);
  mergeLeads.mockResolvedValue("current");
});
afterEach(() => {
  document.body.replaceChildren();
  jest.resetAllMocks();
});

it("opens all three groups in the same component and uses a larger banner heading", async () => {
  const element = await mount();
  expect(find(element, "dialog").open).toBe(true);
  expect(find(element, ".banner-title").className).toContain(
    "slds-text-heading_small"
  );
  expect(find(element, ".banner-title").textContent).toContain(
    "It looks as if duplicates or siblings exist for this Lead."
  );
  const sections = element.shadowRoot.querySelectorAll("dialog section");
  expect(sections).toHaveLength(3);
  expect(sections[0].textContent).toContain(
    "Possible Siblings or Duplicate Leads"
  );
  expect(sections[0].textContent).toContain("Current Lead");
  expect(sections[0].textContent).toContain(
    "These leads share the same contact information. When reaching out, you must log outreach attempts across all related leads to avoid duplicate reach out."
  );
  expect(sections[0].textContent).not.toContain("Applicant");
  expect(sections[0].textContent).not.toContain("Account Record Type");
  expect(sections[0].textContent).toContain("Child Name");
  expect(sections[0].textContent).not.toContain("Account Name");
  expect(sections[1].textContent).toContain("Applicant");
  expect(sections[1].textContent).not.toContain("Account Record Type");
  expect(sections[1].textContent).toContain("Account Name");
  expect(sections[1].textContent).not.toContain("Child Name");
  expect(sections[2].textContent).toContain("No related records found");
});

it("renders the related-record alert as a hero with a clear action", async () => {
  const element = await mount(household, false);
  const hero = find(element, ".hero-banner");
  const action = find(element, '[data-action="view"]');

  expect(hero).not.toBeNull();
  expect(action.className).toContain("hero-action");
  expect(action.textContent).toContain("View Here");
  expect(action.querySelector("lightning-icon").iconName).toBe(
    "utility:forward"
  );
});

it("renders the modal as a matching animated workspace", async () => {
  const element = await mount();
  const modalHeader = find(element, ".modal-hero");
  const sections = element.shadowRoot.querySelectorAll(".record-section");

  expect(modalHeader).not.toBeNull();
  expect(modalHeader.querySelector("lightning-icon").iconName).toBe(
    "standard:lead"
  );
  expect(find(element, ".modal-progress")).not.toBeNull();
  expect(sections).toHaveLength(3);
  expect(
    element.shadowRoot.querySelectorAll(".record-section-icon-pulse")
  ).toHaveLength(3);
  expect(find(element, ".modal-footer")).not.toBeNull();
});

it("collapses and reopens one record group independently", async () => {
  const element = await mount();
  const sections = element.shadowRoot.querySelectorAll("dialog section");
  const buttons = element.shadowRoot.querySelectorAll("[data-section]");

  expect(buttons).toHaveLength(3);
  expect(buttons[0].getAttribute("aria-expanded")).toBe("true");

  buttons[0].click();
  await flush();

  expect(buttons[0].getAttribute("aria-expanded")).toBe("false");
  expect(sections[0].querySelector("[data-section-body]")).toBeNull();
  expect(sections[1].querySelector("[data-section-body]")).not.toBeNull();

  buttons[0].click();
  await flush();

  expect(buttons[0].getAttribute("aria-expanded")).toBe("true");
  expect(sections[0].querySelector("[data-section-body]")).not.toBeNull();
});

it("selects only Leads and requires confirmation before merging selected field values", async () => {
  const element = await mount();
  expect(element.shadowRoot.querySelectorAll("[data-select]")).toHaveLength(2);
  expect(find(element, '[data-action="compare"]').disabled).toBe(true);
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  expect(getLeadComparison).toHaveBeenCalledWith({
    leadId: "current",
    selectedIds: ["current", "sibling"]
  });
  expect(element.shadowRoot.activeElement).toBe(
    find(element, "dialog header h2")
  );
  await change(element, '[data-field="Phone"][data-record="sibling"]');
  await click(element, "confirm");
  expect(find(element, '[data-action="merge"]').disabled).toBe(true);
  expect(mergeLeads).not.toHaveBeenCalled();
  await change(element, "[data-confirm]");
  await click(element, "merge");
  expect(mergeLeads).toHaveBeenCalledWith(
    expect.objectContaining({
      fieldSources: expect.objectContaining({ Phone: "sibling" }),
      versions: {
        current: comparison[0].LastModifiedDate,
        sibling: comparison[1].LastModifiedDate
      }
    })
  );
  expect(find(element, "dialog")).toBeNull();
  expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([
    { recordId: "current" }
  ]);
  expect(refreshApex).toHaveBeenCalled();
  expect(Toast.show).toHaveBeenCalledWith(
    expect.objectContaining({ variant: "success" }),
    expect.any(Object)
  );
});

it("limits selection to three including the current Lead", async () => {
  const element = await mount({
    ...household,
    leads: [...household.leads, { Id: "third" }, { Id: "fourth" }]
  });
  await change(element, '[data-select="sibling"]');
  await change(element, '[data-select="third"]');
  expect(find(element, '[data-select="current"]').disabled).toBe(true);
  expect(find(element, '[data-select="fourth"]').disabled).toBe(true);
  await change(element, '[data-select="sibling"]', false);
  expect(find(element, '[data-select="fourth"]').disabled).toBe(false);
});

it("keeps merge failures visible and allows going back", async () => {
  mergeLeads.mockRejectedValue({
    body: { message: "Records changed. Compare again." }
  });
  const element = await mount();
  await confirm(element);
  await click(element, "merge");
  expect(find(element, 'dialog [role="alert"]').textContent).toContain(
    "Compare again"
  );
  await click(element, "back");
  expect(find(element, '[data-action="confirm"]')).not.toBeNull();
  expect(mergeLeads).toHaveBeenCalledTimes(1);
});

it("blocks Escape and repeated submission while merging, then navigates to another survivor", async () => {
  let finish;
  mergeLeads.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  const element = await mount();
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  const primary = [
    ...element.shadowRoot.querySelectorAll('[data-record="sibling"]')
  ].find((input) => input.name === "primaryLead");
  primary.dispatchEvent(
    new CustomEvent("change", { detail: { checked: true } })
  );
  await flush();
  await click(element, "confirm");
  await change(element, "[data-confirm]");
  await click(element, "merge");
  await click(element, "merge");
  const escape = new CustomEvent("cancel", { cancelable: true });
  find(element, "dialog").dispatchEvent(escape);
  await flush();
  expect(escape.defaultPrevented).toBe(true);
  expect(find(element, "dialog").open).toBe(true);
  expect(mergeLeads).toHaveBeenCalledTimes(1);
  finish("sibling");
  await flush();
  expect(find(element, "dialog")).toBeNull();
  expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([
    { recordId: "sibling" }
  ]);
  expect(mockNavigate).toHaveBeenCalledWith(
    expect.objectContaining({
      attributes: {
        recordId: "sibling",
        objectApiName: "Lead",
        actionName: "view"
      }
    })
  );
});

it("closes on Escape and resets selections when reopened", async () => {
  const element = await mount();
  await change(element, '[data-select="sibling"]');
  find(element, "dialog").dispatchEvent(
    new CustomEvent("cancel", { cancelable: true })
  );
  await flush();
  expect(find(element, "dialog").className).toContain("is-minimising");
  await endAnimation(element, "dialog");
  expect(find(element, "dialog")).toBeNull();
  await click(element, "view");
  expect(find(element, '[data-select="sibling"]').checked).toBe(false);
  expect(mergeLeads).not.toHaveBeenCalled();
});

it("closes the old household on navigation and ignores a pending comparison", async () => {
  let finish;
  getLeadComparison.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  const element = await mount();
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  element.recordId = "another";
  await flush();
  finish(comparison);
  await flush();
  expect(find(element, "dialog")).toBeNull();
  expect(find(element, '[data-action="view"]')).toBeNull();
  expect(find(element, "lightning-spinner")).not.toBeNull();
});

it("does not claim duplicates for only the current Lead", async () => {
  const element = await mount(empty, false);
  expect(find(element, '[data-action="view"]')).toBeNull();
  expect(element.shadowRoot.textContent).toContain(
    "No possible siblings or duplicates found"
  );
});

it("ignores a merge response after the component is disconnected", async () => {
  let finish;
  mergeLeads.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  const element = await mount();
  await confirm(element, "sibling");
  await click(element, "merge");
  element.remove();
  finish("sibling");
  await flush();
  expect(mockNavigate).not.toHaveBeenCalled();
  expect(Toast.show).not.toHaveBeenCalledWith(
    expect.objectContaining({ label: "Leads merged successfully" }),
    expect.anything()
  );
});

it("does not navigate away from a new Lead while the merged record cache refreshes", async () => {
  let finish;
  notifyRecordUpdateAvailable.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  mergeLeads.mockResolvedValueOnce("sibling");
  const element = await mount();
  await confirm(element, "sibling");
  await click(element, "merge");
  element.recordId = "another";
  finish();
  await flush();
  expect(mockNavigate).not.toHaveBeenCalled();
  expect(refreshApex).not.toHaveBeenCalled();
});

it("does not put an old comparison into a newly reopened popup", async () => {
  let finish;
  getLeadComparison.mockImplementationOnce(
    () =>
      new Promise((resolve) => {
        finish = resolve;
      })
  );
  const element = await mount();
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  element.recordId = "another";
  await flush();
  element.recordId = "current";
  getMatches.emit(household);
  await flush();
  await click(element, "view");
  finish(comparison);
  await flush();
  expect(find(element, '[data-action="compare"]')).not.toBeNull();
  expect(find(element, '[data-action="confirm"]')).toBeNull();
});

it("warns when results are limited instead of claiming a complete empty list", async () => {
  const element = await mount({ ...empty, limited: true });
  expect(find(element, 'dialog [role="status"]').textContent).toContain(
    "limited"
  );
});

it("shows access errors instead of empty results", async () => {
  const element = await mount(empty, false);
  getMatches.error({ message: "Check your access." });
  await flush();
  expect(find(element, '[role="alert"]').textContent).toContain(
    "Check your access"
  );
});

it("refreshes results and handles refresh failure", async () => {
  const element = await mount(household, false);
  refreshApex.mockImplementationOnce(() => {
    getMatches.emit(empty);
    return Promise.resolve();
  });
  await click(element, "refresh");
  expect(find(element, '[data-action="view"]')).toBeNull();
  refreshApex.mockRejectedValueOnce(new Error("Offline"));
  await click(element, "refresh");
  expect(find(element, '[role="alert"]').textContent).toContain(
    "Unable to refresh"
  );
});

it("shows comparison failures without advancing or merging", async () => {
  getLeadComparison.mockRejectedValue({
    body: { message: "Check Lead access." }
  });
  const element = await mount();
  await change(element, '[data-select="sibling"]');
  await click(element, "compare");
  expect(find(element, 'dialog [role="alert"]').textContent).toContain(
    "Check Lead access"
  );
  expect(find(element, '[data-action="compare"]')).not.toBeNull();
  expect(mergeLeads).not.toHaveBeenCalled();
});

it("shows the matching secondary guardian without adding guardian rows", async () => {
  const element = await mount({
    ...empty,
    contactIds: ["secondary"],
    applicants: [
      {
        Id: "student",
        Name: "Student",
        Primary_Guardian__c: "primary",
        Secondary_Guardian__c: "secondary",
        Primary_Guardian__r: { Name: "Other parent" },
        Secondary_Guardian__r: {
          Name: "Matching parent",
          PersonEmail: "match@example.invalid"
        }
      }
    ]
  });
  const section = element.shadowRoot.querySelectorAll("dialog section")[1];
  expect(section.querySelectorAll("tbody tr")).toHaveLength(1);
  expect(section.textContent).toContain("Matching parent");
  expect(section.querySelector("lightning-formatted-email").value).toBe(
    "match@example.invalid"
  );
});

it("shows its own toast when matches exist and opens the modal in place", async () => {
  const element = await mount(household, false);
  expect(find(element, ".sibling-toast")).not.toBeNull();
  expect(Toast.show).not.toHaveBeenCalled();
  await click(element, "toast-view");
  expect(find(element, "dialog").open).toBe(true);
  expect(find(element, ".sibling-toast").className).toContain("is-minimising");
  await endAnimation(element, ".sibling-toast");
  expect(find(element, ".sibling-toast")).toBeNull();
  expect(mockNavigate).not.toHaveBeenCalled();
});

it("stays silent when no siblings or duplicates exist", async () => {
  const element = await mount(empty, false);
  expect(find(element, ".sibling-toast")).toBeNull();
});

it("keeps the toast dismissed once closed", async () => {
  const element = await mount(household, false);
  find(element, '[data-action="toast-close"]').click();
  await flush();
  await endAnimation(element, ".sibling-toast");
  expect(find(element, ".sibling-toast")).toBeNull();
  expect(find(element, "dialog")).toBeNull();
});
