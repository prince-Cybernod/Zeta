/**
 * Result of the finalizeLottery step in lottery orchestration.
 * Supports both single-call and batched execution modes.
 */
public class FinalizeResult {
  @AuraEnabled
  public Integer waitlistCount { get; set; }
  @AuraEnabled
  public Integer eventsPublished { get; set; }
  @AuraEnabled
  public Id lastRecordId { get; set; }
  @AuraEnabled
  public Boolean hasMore { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }

  public FinalizeResult() {
    this.waitlistCount = 0;
    this.eventsPublished = 0;
    this.lastRecordId = null;
    this.hasMore = false;
    this.isSuccess = true;
    this.errorMessage = null;
  }
}