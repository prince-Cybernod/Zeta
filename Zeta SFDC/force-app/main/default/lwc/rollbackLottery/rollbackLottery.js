import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import prepareRollback from '@salesforce/apex/RunLotteryController.prepareRollback';
import rollbackAcademicInterestsBatch from '@salesforce/apex/RunLotteryController.rollbackAcademicInterestsBatch';
import TIMELINE_FIELD from '@salesforce/schema/Lottery_Run_Log__c.Application_Timeline__c';
import TEST_FIELD from '@salesforce/schema/Lottery_Run_Log__c.Application_Timeline__r.Test__c';
import STATUS_FIELD from '@salesforce/schema/Lottery_Run_Log__c.Status__c';
import { ErrorHandler } from 'c/errorHandler';

const STATES = {
  LOADING: 'loading',
  READY: 'ready',
  INVALID: 'invalid',
  ROLLING_BACK: 'rolling_back',
  ERROR: 'error'
};

// Smaller batch size for rollback due to heavier trigger overhead on status changes
const ROLLBACK_BATCH_SIZE = 50;

export default class RollbackLottery extends NavigationMixin(LightningElement) {
  @api recordId;

  state = STATES.LOADING;
  error;
  progressMessage = '';
  timelineId;
  validationError;

  @wire(getRecord, {
    recordId: '$recordId',
    fields: [STATUS_FIELD, TIMELINE_FIELD, TEST_FIELD]
  })
  wiredRecord({ data, error }) {
    if (data) {
      const status = getFieldValue(data, STATUS_FIELD);
      const isTestMode = getFieldValue(data, TEST_FIELD) === true;
      this.timelineId = getFieldValue(data, TIMELINE_FIELD);

      // Validate rollback eligibility
      if (status === 'Published') {
        this.validationError =
          'Cannot rollback a published lottery run. Only unpublished runs can be rolled back.';
        this.state = STATES.INVALID;
      } else if (!isTestMode) {
        this.validationError =
          'Cannot rollback production lottery runs. Rollback is only available for test mode timelines.';
        this.state = STATES.INVALID;
      } else {
        this.state = STATES.READY;
      }
    } else if (error) {
      this.error = ErrorHandler.parse(error).messages.join(', ');
      this.state = STATES.ERROR;
    }
  }

  get isLoading() {
    return this.state === STATES.LOADING;
  }

  get isReady() {
    return this.state === STATES.READY;
  }

  get isInvalid() {
    return this.state === STATES.INVALID;
  }

  get isRollingBack() {
    return this.state === STATES.ROLLING_BACK;
  }

  get isError() {
    return this.state === STATES.ERROR;
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  async handleRollback() {
    this.state = STATES.ROLLING_BACK;
    this.progressMessage = 'Preparing rollback...';

    try {
      // Phase A: Prepare rollback (unlink capacities, delete audit records, delete run log)
      const prepareResult = await prepareRollback({ runLogId: this.recordId });

      if (!prepareResult.isSuccess) {
        throw new Error(
          prepareResult.errorMessage || 'Failed to prepare rollback'
        );
      }

      const capacityIds = prepareResult.capacityIds;
      const totalRecords = prepareResult.totalRecordsToReset || 0;
      const totalBatches = Math.ceil(totalRecords / ROLLBACK_BATCH_SIZE) || 1;

      // Phase B: Reset AcademicInterests in batches
      let lastRecordId = null;
      let hasMore = true;
      let totalReset = 0;
      let batchNumber = 0;

      while (hasMore) {
        batchNumber++;
        this.progressMessage = `Resetting records: Batch ${batchNumber} of ${totalBatches}...`;

        // eslint-disable-next-line no-await-in-loop -- Sequential batch pagination
        const result = await rollbackAcademicInterestsBatch({
          capacityIds,
          lastRecordId,
          batchSize: ROLLBACK_BATCH_SIZE
        });

        if (!result.isSuccess) {
          throw new Error(result.errorMessage || 'Batch rollback failed');
        }

        totalReset += result.resetCount || 0;
        lastRecordId = result.lastRecordId;
        hasMore = result.hasMore;
      }

      // Show success toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Success',
          message: `Lottery rolled back. ${totalReset} records reset.`,
          variant: 'success'
        })
      );

      // Close the quick action modal
      this.dispatchEvent(new CloseActionScreenEvent());

      // Navigate to the ApplicationTimeline record (since run log is deleted)
      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: this.timelineId,
          objectApiName: 'ApplicationTimeline',
          actionName: 'view'
        }
      });
    } catch (err) {
      this.error = ErrorHandler.parse(err).messages.join(', ');
      this.state = STATES.ERROR;
    }
  }
}