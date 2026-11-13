import { LightningElement, api } from 'lwc';
import addSchools from '@salesforce/apex/SchoolSelectionController.addSchools';
import getEligibleSchools from '@salesforce/apex/SchoolSelectionController.getEligibleSchools';
import getRankedSchools from '@salesforce/apex/SchoolRankingController.getRankedSchools';
import labelAddSchoolsNone from '@salesforce/label/c.AppUI_AddSchoolsNone';
import labelCancel from '@salesforce/label/c.AppUI_Cancel';
import labelSave from '@salesforce/label/c.AppUI_Save';
import { ErrorHandler } from 'c/errorHandler';

/**
 * SFR-216: adds schools to a submitted application (portal review and staff record page).
 * Lists the offered schools not on the application yet; fires `schoolsadded` or `cancel`.
 */
export default class AddSchoolPicker extends LightningElement {
  @api applicationId;

  schools;
  selectedIds = [];
  isSaving = false;
  error;
  labels = { none: labelAddSchoolsNone, cancel: labelCancel, save: labelSave };

  async connectedCallback() {
    try {
      const [eligible, ranked] = await Promise.all([
        getEligibleSchools({ applicationId: this.applicationId }),
        getRankedSchools({ applicationId: this.applicationId })
      ]);
      const onApplication = new Set(
        ranked.map((choice) => choice.schoolAccountId)
      );
      this.schools = eligible.schools.filter(
        (school) => !onApplication.has(school.schoolAccountId)
      );
    } catch (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
    }
  }

  get hasSchools() {
    return this.schools?.length > 0;
  }

  get isSaveDisabled() {
    return this.isSaving || this.selectedIds.length === 0;
  }

  handleToggle(event) {
    const { id } = event.target.dataset;
    this.selectedIds = event.target.checked
      ? [...this.selectedIds, id]
      : this.selectedIds.filter((selected) => selected !== id);
  }

  async handleSave() {
    this.isSaving = true;
    this.error = undefined;
    try {
      await addSchools({
        applicationId: this.applicationId,
        lotteryCapacityIds: this.selectedIds
      });
      this.dispatchEvent(new CustomEvent('schoolsadded'));
    } catch (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
    } finally {
      this.isSaving = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent('cancel'));
  }
}
