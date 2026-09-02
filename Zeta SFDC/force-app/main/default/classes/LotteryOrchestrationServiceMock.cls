/**
 * {@link Mock} implementation of {@link LotteryOrchestrationService}.
 */
@IsTest
public class LotteryOrchestrationServiceMock extends Mock implements LotteryOrchestrationService {
  public final Method method = new Method();

  public LotteryRunResult runLottery(Set<Id> lotteryCapacityIds) {
    return runLottery(lotteryCapacityIds, null, null);
  }

  public LotteryRunResult runLottery(Set<Id> lotteryCapacityIds, Date startDate, Date endDate) {
    return (LotteryRunResult) mockedCall(
      method.runLottery(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'startDate' => startDate,
        'endDate' => endDate
      }
    );
  }

  public Integer randomizeApplications(Set<Id> lotteryCapacityIds, Date startDate, Date endDate) {
    return (Integer) mockedCall(
      method.randomizeApplications(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'startDate' => startDate,
        'endDate' => endDate
      }
    );
  }

  public AssignPreOffersResult assignPreOffers(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate
  ) {
    return (AssignPreOffersResult) mockedCall(
      method.assignPreOffers(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'startDate' => startDate,
        'endDate' => endDate
      }
    );
  }

  public OptimizeOffersResult optimizeOffers(Id runLogId) {
    return (OptimizeOffersResult) mockedCall(
      method.optimizeOffers(),
      new Map<String, Object>{ 'runLogId' => runLogId }
    );
  }

  public FinalizeResult finalizeLottery(Set<Id> lotteryCapacityIds, Id runLogId) {
    return (FinalizeResult) mockedCall(
      method.finalizeLottery(),
      new Map<String, Object>{ 'lotteryCapacityIds' => lotteryCapacityIds, 'runLogId' => runLogId }
    );
  }

  public RandomizeBatchResult randomizeApplicationsBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    return (RandomizeBatchResult) mockedCall(
      method.randomizeApplicationsBatch(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'startDate' => startDate,
        'endDate' => endDate,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize
      }
    );
  }

  public AssignPreOffersResult assignPreOffersBatch(
    Set<Id> lotteryCapacityIds,
    Date startDate,
    Date endDate,
    Id lastRecordId,
    Integer batchSize
  ) {
    return (AssignPreOffersResult) mockedCall(
      method.assignPreOffersBatch(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'startDate' => startDate,
        'endDate' => endDate,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize
      }
    );
  }

  public OptimizeOffersResult optimizeOffersBatch(Id runLogId, Id lastRecordId, Integer batchSize) {
    return (OptimizeOffersResult) mockedCall(
      method.optimizeOffersBatch(),
      new Map<String, Object>{
        'runLogId' => runLogId,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize
      }
    );
  }

  public FinalizeResult finalizeLotteryBatch(
    Set<Id> lotteryCapacityIds,
    Id runLogId,
    Id lastRecordId,
    Integer batchSize
  ) {
    return (FinalizeResult) mockedCall(
      method.finalizeLotteryBatch(),
      new Map<String, Object>{
        'lotteryCapacityIds' => lotteryCapacityIds,
        'runLogId' => runLogId,
        'lastRecordId' => lastRecordId,
        'batchSize' => batchSize
      }
    );
  }

  public class Method {
    public String runLottery() {
      return new ExecutionInfo().getFullName();
    }

    public String randomizeApplications() {
      return new ExecutionInfo().getFullName();
    }

    public String assignPreOffers() {
      return new ExecutionInfo().getFullName();
    }

    public String optimizeOffers() {
      return new ExecutionInfo().getFullName();
    }

    public String finalizeLottery() {
      return new ExecutionInfo().getFullName();
    }

    public String randomizeApplicationsBatch() {
      return new ExecutionInfo().getFullName();
    }

    public String assignPreOffersBatch() {
      return new ExecutionInfo().getFullName();
    }

    public String optimizeOffersBatch() {
      return new ExecutionInfo().getFullName();
    }

    public String finalizeLotteryBatch() {
      return new ExecutionInfo().getFullName();
    }
  }
}