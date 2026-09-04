import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class LotteryRunRouter extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  _hasNavigated = false;

  connectedCallback() {
    if (this._hasNavigated || !this.recordId) {
      return;
    }
    this._hasNavigated = true;

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