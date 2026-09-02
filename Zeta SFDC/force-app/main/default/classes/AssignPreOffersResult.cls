/**
 * Result of the assignPreOffers step in lottery orchestration.
 * Supports both single-call and batched execution modes.
 */
public class AssignPreOffersResult {
  @AuraEnabled
  public Integer preOfferCount { get; set; }
  @AuraEnabled
  public Id lastRecordId { get; set; }
  @AuraEnabled
  public Boolean hasMore { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }

  public AssignPreOffersResult() {
    this.preOfferCount = 0;
    this.lastRecordId = null;
    this.hasMore = false;
    this.isSuccess = true;
    this.errorMessage = null;
  }
}