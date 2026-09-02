import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class LotteryRunAction extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  @api invoke() {
    this[NavigationMixin.Navigate]({
      type: 'standard__navItemPage',
      attributes: {
        apiName: 'Run_Lottery'
      },
      state: {
        c__timelineId: this.recordId
      }
    });
  }
}