/**
 * {@link Mock} implementation of {@link LotteryLockService}.
 */
@IsTest
public class LotteryLockServiceMock extends Mock implements LotteryLockService {
  public final Method method = new Method();

  public String acquireLock(Set<Id> capacityIds) {
    return (String) mockedCall(
      method.acquireLock(),
      new Map<String, Object>{ 'capacityIds' => capacityIds }
    );
  }

  public void verifyLock(Set<Id> capacityIds, String jobId) {
    mockedCall(
      method.verifyLock(),
      new Map<String, Object>{ 'capacityIds' => capacityIds, 'jobId' => jobId }
    );
  }

  public void releaseLock(Set<Id> capacityIds, String jobId) {
    mockedCall(
      method.releaseLock(),
      new Map<String, Object>{ 'capacityIds' => capacityIds, 'jobId' => jobId }
    );
  }

  public class Method {
    public String acquireLock() {
      return new ExecutionInfo().getFullName();
    }

    public String verifyLock() {
      return new ExecutionInfo().getFullName();
    }

    public String releaseLock() {
      return new ExecutionInfo().getFullName();
    }
  }
}