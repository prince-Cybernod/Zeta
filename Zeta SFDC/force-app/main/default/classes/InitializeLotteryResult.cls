/**
 * Result of the initializeLottery step in sequential lottery execution.
 * Contains the jobId for lock verification and runLog details.
 */
public class InitializeLotteryResult {
  @AuraEnabled
  public String jobId { get; set; }
  @AuraEnabled
  public Id runLogId { get; set; }
  @AuraEnabled
  public String runLogName { get; set; }
  @AuraEnabled
  public Boolean isSuccess { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }

  public InitializeLotteryResult() {
    this.isSuccess = true;
    this.errorMessage = null;
  }
}