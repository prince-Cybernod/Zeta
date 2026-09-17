import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import Toast from "lightning/toast";
import {
  registerRefreshHandler,
  unregisterRefreshHandler,
  RefreshEvent
} from "lightning/refresh";
import getMatches from "@salesforce/apex/LeadSiblingFlagsController.getMatches";
import getLeadComparison from "@salesforce/apex/LeadSiblingFlagsController.getLeadComparison";
import mergeLeads from "@salesforce/apex/LeadSiblingFlagsController.mergeLeads";

const FIELDS = [
  ["FirstName", "Child First Name"],
  ["LastName", "Child Last Name"],
  ["Email", "Email"],
  ["Phone", "Phone"],
  ["MobilePhone", "Mobile"],
  ["Guardian_First_Name__c", "Guardian First Name"],
  ["Guardian_Last_Name__c", "Guardian Last Name"],
  ["Status", "Lead Status"]
];

const GROUPS = [
  {
    key: "leads",
    icon: "standard:lead",
    title: "Possible Siblings or Duplicate Leads",
    help: "These leads share the same contact information. When reaching out, you must log outreach attempts across all related leads to avoid duplicate reach out."
  },
  {
    key: "applicants",
    icon: "standard:account",
    title: "Possible Siblings or Duplicate Applicants",
    help: "These leads may have applied siblings or duplicates. Check for duplicates before converting a lead to an applicant."
  },
  {
    key: "enrolled",
    icon: "standard:contact",
    title: "Possible Siblings or Duplicate Enrolled",
    help: "These leads may have enrolled siblings or duplicates. Check for duplicates before converting a lead to an applicant."
  }
];

export default class LeadSiblingFlags extends NavigationMixin(
  LightningElement
) {
  leadId;
  matches;
  error;
  modalError;
  loading = true;
  busy = false;
  isOpen = false;
  modalSession = 0;
  step = "select";
  lastStep;
  selectedIds = [];
  comparison = [];
  fieldSources = {};
  primaryId;
  confirmed = false;
  collapsedSections = new Set();
  wiredResult;
  refreshRegistration;

  @api
  get recordId() {
    return this.leadId;
  }
  set recordId(value) {
    if (value !== this.leadId) {
      this.modalSession++;
      if (this.isOpen) this.refs.dialog.close();
      this.isOpen = false;
      this.busy = false;
      this.leadId = value;
      this.matches = undefined;
      this.error = undefined;
      this.loading = true;
    }
  }

  @wire(getMatches, { leadId: "$recordId" })
  loadMatches(result) {
    this.wiredResult = result;
    if (result.data || result.error) {
      this.matches = result.data;
      this.error = result.error
        ? result.error.body?.message ||
          "Unable to check related records. Try refreshing."
        : undefined;
      this.loading = false;
    }
  }
  connectedCallback() {
    this.refreshRegistration = registerRefreshHandler(
      this,
      this.refresh.bind(this)
    );
  }
  disconnectedCallback() {
    this.modalSession++;
    this.isOpen = false;
    this.busy = false;
    unregisterRefreshHandler(this.refreshRegistration);
  }
  renderedCallback() {
    if (!this.isOpen) return;
    if (!this.refs.dialog.open) this.refs.dialog.showModal();
    if (this.lastStep !== this.step) {
      this.refs.heading.focus();
      this.lastStep = this.step;
    }
  }

  get hasMatches() {
    return GROUPS.some((group) => this.matches?.[group.key]?.length);
  }
  get showResults() {
    return this.hasMatches || this.matches?.limited;
  }
  get isSelecting() {
    return this.step === "select";
  }
  get isComparing() {
    return this.step === "compare";
  }
  get previousStep() {
    return this.isComparing ? "select" : "compare";
  }
  get cannotCompare() {
    return this.busy || this.selectedIds.length < 2;
  }
  get cannotMerge() {
    return this.busy || !this.confirmed;
  }
  get primaryRecord() {
    return this.comparison.find((record) => record.Id === this.primaryId);
  }
  get removedRecords() {
    return this.comparison.filter((record) => record.Id !== this.primaryId);
  }
  get leadHeaders() {
    return this.comparison.map((record) => ({
      ...record,
      isPrimary: record.Id === this.primaryId,
      isCurrent: record.Id === this.recordId
    }));
  }
  get comparisonRows() {
    return FIELDS.map(([name, label]) => ({
      name,
      label,
      choices: this.comparison.map((record) => ({
        id: record.Id,
        value: record[name] || "—",
        label: `${record.Name}: ${record[name] || "Blank"}`,
        selected: this.fieldSources[name] === record.Id
      }))
    }));
  }

  async refresh() {
    this.loading = true;
    try {
      await refreshApex(this.wiredResult);
      return !this.error;
    } catch (error) {
      this.error =
        error.body?.message || "Unable to refresh related records. Try again.";
      return false;
    } finally {
      this.loading = false;
    }
  }
  openMatches() {
    this.modalSession++;
    this.lastStep = undefined;
    this.selectedIds = this.matches?.currentLead
      ? [this.matches.currentLead.Id]
      : [];
    this.comparison = [];
    this.modalError = undefined;
    this.confirmed = false;
    this.collapsedSections = new Set();
    this.step = "select";
    this.isOpen = true;
  }
  toggleSection(event) {
    const sectionKey = event.currentTarget.dataset.section;
    const collapsedSections = new Set(this.collapsedSections);
    if (collapsedSections.has(sectionKey)) collapsedSections.delete(sectionKey);
    else collapsedSections.add(sectionKey);
    this.collapsedSections = collapsedSections;
  }
  closeModal(event) {
    event?.preventDefault();
    if (this.busy) return;
    this.modalSession++;
    this.refs.dialog.close();
    this.isOpen = false;
    this.template.querySelector('[data-action="view"]')?.focus();
  }
  changeStep(event) {
    this.step = event.target.dataset.step;
    this.confirmed = false;
    this.modalError = undefined;
  }
  selectLead(event) {
    if (this.busy) return;
    const id = event.target.dataset.select;
    if (event.detail.checked && this.selectedIds.length < 3)
      this.selectedIds = [...new Set([...this.selectedIds, id])];
    else if (!event.detail.checked && id !== this.recordId)
      this.selectedIds = this.selectedIds.filter((selected) => selected !== id);
  }
  setPrimary(id) {
    this.primaryId = id;
    this.fieldSources = Object.fromEntries(FIELDS.map(([name]) => [name, id]));
  }
  choosePrimary(event) {
    this.setPrimary(event.target.dataset.record);
  }
  chooseValue(event) {
    this.fieldSources = {
      ...this.fieldSources,
      [event.target.dataset.field]: event.target.dataset.record
    };
  }
  acknowledge(event) {
    this.confirmed = event.detail.checked;
  }

  async runModalAction(operation, onSuccess, fallback) {
    const session = this.modalSession;
    this.busy = true;
    this.modalError = undefined;
    try {
      const result = await operation();
      if (session === this.modalSession && this.isOpen) await onSuccess(result);
    } catch (error) {
      if (session === this.modalSession && this.isOpen) {
        this.confirmed = false;
        this.modalError = error.body?.message || fallback;
      }
    } finally {
      if (session === this.modalSession) this.busy = false;
    }
  }
  compareLeads() {
    if (this.cannotCompare) return;
    this.runModalAction(
      () =>
        getLeadComparison({
          leadId: this.recordId,
          selectedIds: this.selectedIds
        }),
      (records) => {
        this.comparison = this.selectedIds.map((id) => ({
          ...records.find((record) => record.Id === id),
          url: `/lightning/r/Lead/${id}/view`
        }));
        this.setPrimary(this.recordId);
        this.step = "compare";
      },
      "Unable to compare Leads. Refresh and try again."
    );
  }
  mergeSelectedLeads() {
    if (this.cannotMerge || this.step !== "confirm") return;
    this.runModalAction(
      () =>
        mergeLeads({
          leadId: this.recordId,
          primaryId: this.primaryId,
          selectedIds: this.selectedIds,
          fieldSources: this.fieldSources,
          versions: Object.fromEntries(
            this.comparison.map((record) => [
              record.Id,
              record.LastModifiedDate
            ])
          )
        }),
      (primaryId) => this.finishMerge(primaryId),
      "Unable to merge Leads. Go back and compare again."
    );
  }
  async finishMerge(primaryId) {
    this.busy = false;
    this.closeModal();
    const session = this.modalSession;
    Toast.show(
      { label: "Leads merged successfully", variant: "success" },
      this
    );
    try {
      await notifyRecordUpdateAvailable([{ recordId: primaryId }]);
    } catch {
      if (this.isConnected && session === this.modalSession) {
        this.error =
          "Leads were merged. Refresh the page to see the updated record.";
      }
    }
    if (!this.isConnected || session !== this.modalSession) return;
    if (primaryId !== this.recordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: primaryId,
          objectApiName: "Lead",
          actionName: "view"
        }
      });
    } else {
      await this.refresh();
      this.dispatchEvent(new RefreshEvent());
    }
  }

  get sections() {
    const contactIds = new Set(this.matches?.contactIds || []);
    return GROUPS.map((group) => {
      const records = [...(this.matches?.[group.key] || [])];
      if (group.key === "leads" && this.matches?.currentLead) {
        records.unshift(this.matches.currentLead);
      }
      const rows = records.map((record) => {
        const guardian =
          contactIds.has(record.Secondary_Guardian__c) &&
          !contactIds.has(record.Primary_Guardian__c)
            ? record.Secondary_Guardian__r
            : record.Primary_Guardian__r || record.Secondary_Guardian__r;
        return {
          id: record.Id,
          name: record.Name,
          isCurrent: record.Id === this.matches?.currentLead?.Id,
          selected: this.selectedIds.includes(record.Id),
          selectionDisabled:
            record.Id === this.matches?.currentLead?.Id ||
            (!this.selectedIds.includes(record.Id) &&
              this.selectedIds.length >= 3),
          url: `/lightning/r/${group.key === "leads" ? "Lead" : "Account"}/${record.Id}/view`,
          phone:
            record.Phone ||
            record.PersonMobilePhone ||
            guardian?.PersonMobilePhone ||
            guardian?.Phone,
          email: record.Email || record.PersonEmail || guardian?.PersonEmail,
          guardian:
            group.key === "leads"
              ? [record.Guardian_First_Name__c, record.Guardian_Last_Name__c]
                  .filter(Boolean)
                  .join(" ")
              : guardian?.Name,
          status:
            record.Status ||
            record.AcademicTermEnrollments?.[0]?.EnrollmentStatus ||
            record.IndividualApplicationAccount?.[0]?.Status
        };
      });
      return {
        ...group,
        expanded: !this.collapsedSections.has(group.key),
        chevron: this.collapsedSections.has(group.key)
          ? "utility:chevronright"
          : "utility:chevrondown",
        bodyId: `${group.key}-records`,
        rows,
        count: rows.length,
        nameHeading: group.key === "leads" ? "Child Name" : "Account Name",
        canSelect:
          group.key === "leads" &&
          rows.length > 1 &&
          !!this.matches?.currentLead,
        hasRows: rows.length > 0
      };
    });
  }
}
