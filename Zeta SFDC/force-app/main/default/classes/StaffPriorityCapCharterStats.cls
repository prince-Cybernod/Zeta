/**
 * Per-Charter staff priority cap stats, shown in the Run Lottery confirmation modal.
 */
public class StaffPriorityCapCharterStats {
  public static final String STATUS_OVER = 'Over';
  public static final String STATUS_UNDER = 'Under';
  public static final String STATUS_BLOCKED = 'Blocked';

  @AuraEnabled
  public Id charterId { get; set; }
  @AuraEnabled
  public String charterName { get; set; }
  @AuraEnabled
  public Integer staffApplicantCount { get; set; }
  @AuraEnabled
  public Integer seats { get; set; }
  @AuraEnabled
  public Decimal capPercent { get; set; }
  @AuraEnabled
  public Integer maxAllowed { get; set; }
  @AuraEnabled
  public Decimal currentPercent { get; set; }
  @AuraEnabled
  public String status { get; set; }
  @AuraEnabled
  public String message { get; set; }
  @AuraEnabled
  public Integer toRemove { get; set; }
}