import { LightningElement, wire } from 'lwc';
import getAllActionPlanData from '@salesforce/apex/ActionPlanController.getAllActionPlanData';
import labelNoTasks from '@salesforce/label/c.Action_Plan_No_Tasks';
import { ErrorHandler } from 'c/errorHandler';

export default class ActionPlanContainer extends LightningElement {
  actionPlans = [];

  labels = {
    noTasks: labelNoTasks
  };

  @wire(getAllActionPlanData)
  wiredActionPlans({ error, data }) {
    if (data) {
      this.actionPlans = data;
    } else if (error) {
      ErrorHandler.toast(this, error);
    }
  }

  get hasTasks() {
    return this.actionPlans.some(plan => plan.tasks && plan.tasks.length > 0);
  }
}