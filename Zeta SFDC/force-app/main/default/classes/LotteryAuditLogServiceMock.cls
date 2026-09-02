/**
 * {@link Mock} implementation of {@link LotteryAuditLogService}.
 */
@IsTest
public class LotteryAuditLogServiceMock extends Mock implements LotteryAuditLogService {
  public final Method method = new Method();

  public Id createLotteryRunLog(Id applicationTimelineId) {
    return (Id) mockedCall(
      method.createLotteryRunLog(),
      new Map<String, Object>{ 'applicationTimelineId' => applicationTimelineId }
    );
  }

  public Integer createLotteryRunResults(Id runLogId, LotteryRunResult result) {
    return (Integer) mockedCall(
      method.createLotteryRunResults(),
      new Map<String, Object>{ 'runLogId' => runLogId, 'result' => result }
    );
  }

  public void linkCapacitiesToRun(Id runLogId, Set<Id> capacityIds) {
    mockedCall(
      method.linkCapacitiesToRun(),
      new Map<String, Object>{ 'runLogId' => runLogId, 'capacityIds' => capacityIds }
    );
  }

  public void publishLotteryRun(Id runLogId) {
    mockedCall(method.publishLotteryRun(), new Map<String, Object>{ 'runLogId' => runLogId });
  }

  public LotteryRollbackResult rollbackLotteryRun(Id runLogId) {
    return (LotteryRollbackResult) mockedCall(
      method.rollbackLotteryRun(),
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
  }

  public RollbackPrepareResult prepareRollback(Id runLogId) {
    return (RollbackPrepareResult) mockedCall(
      method.prepareRollback(),
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
  }

  public RollbackBatchResult rollbackAcademicInterestsBatch(
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize
  ) {
    return (RollbackBatchResult) mockedCall(
      method.rollbackAcademicInterestsBatch(),
      new Map<String, Object>{
        'capacityIds' => capacityIds,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize
      }
    );
  }

  public Integer createAuditRecords(Id runLogId, Set<Id> capacityIds) {
    return (Integer) mockedCall(
      method.createAuditRecords(),
      new Map<String, Object>{ 'runLogId' => runLogId, 'capacityIds' => capacityIds }
    );
  }

  public CreateAuditBatchResult createAuditRecordsBatch(
    Id runLogId,
    Set<Id> capacityIds,
    Id lastRecordId,
    Integer batchSize,
    Integer startLotteryNumber
  ) {
    return (CreateAuditBatchResult) mockedCall(
      method.createAuditRecordsBatch(),
      new Map<String, Object>{
        'runLogId' => runLogId,
        'capacityIds' => capacityIds,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize,
        'startLotteryNumber' => startLotteryNumber
      }
    );
  }

  public class Method {
    public String createLotteryRunLog() {
      return new ExecutionInfo().getFullName();
    }

    public String createLotteryRunResults() {
      return new ExecutionInfo().getFullName();
    }

    public String linkCapacitiesToRun() {
      return new ExecutionInfo().getFullName();
    }

    public String publishLotteryRun() {
      return new ExecutionInfo().getFullName();
    }

    public String rollbackLotteryRun() {
      return new ExecutionInfo().getFullName();
    }

    public String prepareRollback() {
      return new ExecutionInfo().getFullName();
    }

    public String rollbackAcademicInterestsBatch() {
      return new ExecutionInfo().getFullName();
    }

    public String createAuditRecords() {
      return new ExecutionInfo().getFullName();
    }

    public String createAuditRecordsBatch() {
      return new ExecutionInfo().getFullName();
    }
  }
}