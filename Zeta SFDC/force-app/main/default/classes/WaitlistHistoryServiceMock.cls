/**
 * {@link Mock} implementation of {@link WaitlistHistoryService}.
 */
@IsTest
public class WaitlistHistoryServiceMock extends Mock implements WaitlistHistoryService {
  public final Method method = new Method();

  public void createHistoryRecords(
    Map<Id, AcademicInterest> oldRecordsById,
    List<AcademicInterest> newRecords
  ) {
    mockedCall(
      method.createHistoryRecords(),
      new Map<String, Object>{ 'oldRecordsById' => oldRecordsById, 'newRecords' => newRecords }
    );
  }

  public class Method {
    public String createHistoryRecords() {
      return new ExecutionInfo().getFullName();
    }
  }
}