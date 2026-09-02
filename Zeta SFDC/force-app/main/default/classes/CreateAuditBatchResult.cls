/**
 * Result of a batch execution of the createAuditRecords step.
 * Used for chunked processing to avoid DML limits with large datasets.
 */
public class CreateAuditBatchResult {
  @AuraEnabled
  public Integer recordsCreated { get; set; }
  @AuraEnabled
  public Id lastRecordId { get; set; }
  @AuraEnabled
  public Boolean hasMore { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }
  @AuraEnabled
  public Integer nextLotteryNumber { get; set; }

  public CreateAuditBatchResult() {
    this.recordsCreated = 0;
    this.lastRecordId = null;
    this.hasMore = false;
    this.isSuccess = true;
    this.errorMessage = null;
    this.nextLotteryNumber = 1;
  }
}