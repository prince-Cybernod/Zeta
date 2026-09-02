/**
 * Result of a batch execution of the rollbackAcademicInterests step.
 * Used for chunked processing to avoid CPU timeouts with large datasets.
 */
public class RollbackBatchResult {
  @AuraEnabled
  public Integer resetCount { get; set; }
  @AuraEnabled
  public Id lastRecordId { get; set; }
  @AuraEnabled
  public Boolean hasMore { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }

  public RollbackBatchResult() {
    this.resetCount = 0;
    this.lastRecordId = null;
    this.hasMore = false;
    this.isSuccess = true;
    this.errorMessage = null;
  }
}