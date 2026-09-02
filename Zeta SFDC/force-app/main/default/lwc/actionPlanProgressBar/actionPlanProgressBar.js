import { LightningElement, api } from 'lwc';

export default class ActionPlanProgressBar extends LightningElement {
    @api tasks = [];

    get chunks() {
        return [...this.tasks]
            .sort((a, b) => {
                if (a.isComplete === b.isComplete) {
                    return 0;
                }
                return a.isComplete ? -1 : 1;
            })
            .map((task, index) => ({
                id: task.id || index,
                className: `progress-chunk ${task.isComplete ? 'complete' : 'incomplete'}`
            }));
    }

    get completedCount() {
        return this.tasks.filter(task => task.isComplete).length;
    }

    get totalCount() {
        return this.tasks.length;
    }
}