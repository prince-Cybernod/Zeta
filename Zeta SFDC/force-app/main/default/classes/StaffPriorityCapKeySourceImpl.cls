/**
 * Implementation of {@link StaffPriorityCapKeySource}.
 * Uses the same Math.random() approach as {@link LotterySortServiceImpl}.
 */
public class StaffPriorityCapKeySourceImpl implements StaffPriorityCapKeySource {
  public Decimal nextKey() {
    return Math.random();
  }
}