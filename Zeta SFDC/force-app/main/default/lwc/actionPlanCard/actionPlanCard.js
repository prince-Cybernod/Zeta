import { LightningElement, api } from 'lwc';
import labelViewAllTasks from '@salesforce/label/c.Action_Plan_View_All_Tasks';
import labelCompleted from '@salesforce/label/c.Action_Plan_Completed';

export default class ActionPlanCard extends LightningElement {
    @api actionPlan;
    error;
    isExpanded = true;

    labels = {
        viewAllTasks: labelViewAllTasks,
        completed: labelCompleted
    };

    connectedCallback() {
        if (this.actionPlan) {
            // Default collapsed if all tasks are complete
            if (this.completedCount === this.totalCount && this.totalCount > 0) {
                this.isExpanded = false;
            } else {
                this.isExpanded = true;
            }
        }
    }

    get data() {
        return this.actionPlan;
    }

    handleToggleExpand() {
        this.isExpanded = !this.isExpanded;
    }

    get viewAllIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get completedCount() {
        return this.data?.tasks?.filter(task => task.isComplete).length || 0;
    }

    get totalCount() {
        return this.data?.tasks?.length || 0;
    }

    get hasTasks() {
        return this.totalCount > 0;
    }
}