/**
 * Mock implementation of {@link LotteryCapacityRollupService} for testing.
 */
@IsTest
public class LotteryCapacityRollupServiceMock extends Mock implements LotteryCapacityRollupService {
  public final Method method = new Method();

  public void recalculate(Set<Id> lotteryCapacityIds) {
    mockedCall(
      method.recalculate(),
      new Map<String, Object>{ 'lotteryCapacityIds' => lotteryCapacityIds }
    );
  }

  public class Method {
    public String recalculate() {
      return new ExecutionInfo().getFullName();
    }
  }
}