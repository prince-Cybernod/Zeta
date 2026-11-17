/**
 * {@link Mock} implementation of {@link StaffPriorityCapService}.
 */
@IsTest
public class StaffPriorityCapServiceMock extends Mock implements StaffPriorityCapService {
  public final Method method = new Method();

  public List<StaffPriorityCapCharterStats> getCharterStats(
    List<Id> capacityIds,
    Date startDate,
    Date endDate
  ) {
    return (List<StaffPriorityCapCharterStats>) mockedCall(
      method.getCharterStats(),
      new Map<String, Object>{
        'capacityIds' => capacityIds,
        'startDate' => startDate,
        'endDate' => endDate
      }
    );
  }

  public StaffPriorityCapRemovalResult removeForCharter(
    Id charterId,
    List<Id> capacityIds,
    Id runLogId,
    Date startDate,
    Date endDate
  ) {
    return (StaffPriorityCapRemovalResult) mockedCall(
      method.removeForCharter(),
      new Map<String, Object>{
        'charterId' => charterId,
        'capacityIds' => capacityIds,
        'runLogId' => runLogId,
        'startDate' => startDate,
        'endDate' => endDate
      }
    );
  }

  public class Method {
    public String getCharterStats() {
      return new ExecutionInfo().getFullName();
    }

    public String removeForCharter() {
      return new ExecutionInfo().getFullName();
    }
  }
}