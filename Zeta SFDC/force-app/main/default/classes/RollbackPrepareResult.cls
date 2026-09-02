/**
 * Result of the prepareRollback phase.
 * Contains capacity IDs needed for the batched AcademicInterest reset.
 */
public class RollbackPrepareResult {
  @AuraEnabled
  public List<Id> capacityIds { get; set; }
  @AuraEnabled
  public Integer capacitiesUnlinked { get; set; }
  @AuraEnabled
  public Integer waitlistHistoryDeleted { get; set; }
  @AuraEnabled
  public Integer runResultsDeleted { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }
  @AuraEnabled
  public Integer totalRecordsToReset { get; set; }

  public RollbackPrepareResult() {
    this.capacityIds = new List<Id>();
    this.capacitiesUnlinked = 0;
    this.waitlistHistoryDeleted = 0;
    this.runResultsDeleted = 0;
    this.isSuccess = true;
    this.errorMessage = null;
    this.totalRecordsToReset = 0;
  }
}