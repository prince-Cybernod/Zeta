/**
 * Result of {@link StaffPriorityCapService#removeForCharter}.
 */
public class StaffPriorityCapRemovalResult {
  @AuraEnabled
  public Integer removedCount { get; set; }
  @AuraEnabled
  public Integer residual { get; set; }

  public StaffPriorityCapRemovalResult() {
    this.removedCount = 0;
    this.residual = 0;
  }
}