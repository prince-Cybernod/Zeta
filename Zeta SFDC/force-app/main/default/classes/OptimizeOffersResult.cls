/**
 * Result of the optimizeOffers step in lottery orchestration.
 * Supports both single-call and batched execution modes.
 */
public class OptimizeOffersResult {
  @AuraEnabled
  public Integer rescindedCount { get; set; }
  @AuraEnabled
  public Id lastRecordId { get; set; }
  @AuraEnabled
  public Boolean hasMore { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }
  @AuraEnabled
  public Integer withdrawnCount { get; set; }

  public OptimizeOffersResult() {
    this.rescindedCount = 0;
    this.lastRecordId = null;
    this.hasMore = false;
    this.isSuccess = true;
    this.errorMessage = null;
    this.withdrawnCount = 0;
  }
}