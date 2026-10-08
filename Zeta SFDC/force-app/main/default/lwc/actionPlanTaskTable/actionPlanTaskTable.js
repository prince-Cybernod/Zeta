import { LightningElement, api } from 'lwc';
import labelCompleteForm from '@salesforce/label/c.Action_Plan_Button_Complete_Form';
import labelDueByDate from '@salesforce/label/c.Action_Plan_Due_By_Date';
import LANG from '@salesforce/i18n/lang';

export default class ActionPlanTaskTable extends LightningElement {
    @api tasks = [];

    labels = {
        completeForm: labelCompleteForm,
        dueBy: labelDueByDate
    };

    get processedTasks() {
        return [...this.tasks]
            .sort((a, b) => {
                if (a.isComplete === b.isComplete) {
                    return 0;
                }
                return a.isComplete ? 1 : -1;
            })
            .map(task => {
                let formattedDueDate = null;
                if (task.dueDate && !task.isComplete) {
                    const dateParts = task.dueDate.split('-');
                    if (dateParts.length === 3) {
                        const dueDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]).toLocaleDateString(LANG, {
                            month: '2-digit',
                            day: '2-digit',
                            year: 'numeric'
                        });
                        formattedDueDate = this.labels.dueBy.replace('{0}', dueDate);
                    }
                }

                return {
                    ...task,
                    cardClass: `task-card ${task.isComplete ? 'complete-card disabled-link' : 'incomplete-card clickable'}`,
                    iconName: task.isComplete ? 'standard:task2' : 'standard:task',
                    iconClass: task.isComplete ? 'complete-icon' : 'incomplete-icon',
                    buttonLabel: this.labels.completeForm,
                    buttonClass: 'slds-button task-button complete-button',
                    displayDueDate: formattedDueDate
                };
            });
    }

    handleAnchorClick(event) {
        if (event.currentTarget.classList.contains('disabled-link')) {
            event.preventDefault();
        }
    }
}