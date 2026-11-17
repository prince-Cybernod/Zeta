/**
 * Enforces the per-Charter staff priority cap (NY Ed Law §2854(2)(a)) before a lottery run.
 */
public interface StaffPriorityCapService {
  /**
   * Pre-run staff priority cap stats, one row per Charter with staff applicants
   * among the given capacities. A Charter with no staff applicants is omitted.
   * @param capacityIds Lottery_Capacity__c IDs selected for the run
   * @param startDate Optional start date filter for Application_Submitted_Date__c
   * @param endDate Optional end date filter for Application_Submitted_Date__c
   */
  List<StaffPriorityCapCharterStats> getCharterStats(
    List<Id> capacityIds,
    Date startDate,
    Date endDate
  );

  /**
   * Recomputes one Charter's stats server-side and randomly removes staff priority
   * from that Charter's pool applicants until it is at or under the cap.
   * @param charterId The Charter (Account) to remove staff priority for
   * @param capacityIds Lottery_Capacity__c IDs selected for the run
   * @param runLogId The Lottery_Run_Log__c this removal belongs to
   * @param startDate Optional start date filter for Application_Submitted_Date__c
   * @param endDate Optional end date filter for Application_Submitted_Date__c
   */
  StaffPriorityCapRemovalResult removeForCharter(
    Id charterId,
    List<Id> capacityIds,
    Id runLogId,
    Date startDate,
    Date endDate
  );
}