/**
 * {@link Mock} implementation of {@link SeatOfferWithdrawalService}.
 */
@IsTest
public class SeatOfferWithdrawalServiceMock extends Mock implements SeatOfferWithdrawalService {
  public final Method method = new Method();

  public List<AcademicInterest> withdrawLowerRankedApplications(
    List<AcademicInterest> offeredRecords,
    Set<Id> excludeRecordIds,
    List<LotteryStatusChange> transitions
  ) {
    return (List<AcademicInterest>) mockedCall(
      method.withdrawLowerRankedApplications(),
      new Map<String, Object>{
        'offeredRecords' => offeredRecords,
        'excludeRecordIds' => excludeRecordIds,
        'transitions' => transitions
      }
    );
  }

  public class Method {
    public String withdrawLowerRankedApplications() {
      return new ExecutionInfo().getFullName();
    }
  }
}