/**
 * Result of a lottery run containing summary statistics.
 */
public class LotteryRunResult {
  public Integer totalEligible { get; set; }
  public Integer preOffersAssigned { get; set; }
  public Integer offersRescinded { get; set; }
  public Integer waitlisted { get; set; }
  public List<Id> capacitiesProcessed { get; set; }
  public List<LotteryStatusChange> transitions { get; set; }
  public Boolean isSuccess { get; set; }
  public String errorMessage { get; set; }
  public Integer withdrawnCount { get; set; }

  public LotteryRunResult() {
    this.totalEligible = 0;
    this.preOffersAssigned = 0;
    this.offersRescinded = 0;
    this.waitlisted = 0;
    this.capacitiesProcessed = new List<Id>();
    this.transitions = new List<LotteryStatusChange>();
    this.isSuccess = true;
    this.errorMessage = null;
    this.withdrawnCount = 0;
  }
}