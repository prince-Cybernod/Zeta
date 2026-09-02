/**
 * Immutable DTO representing a status transition for a lottery record.
 */
public class LotteryStatusChange {
  public Id recordId { get; private set; }
  public String fromStatus { get; private set; }
  public String toStatus { get; private set; }
  public String reason { get; private set; }
  public Datetime timestamp { get; private set; }
  public Decimal priorityGroup { get; private set; }

  public LotteryStatusChange(Id recordId, String fromStatus, String toStatus, String reason) {
    this.recordId = recordId;
    this.fromStatus = fromStatus;
    this.toStatus = toStatus;
    this.reason = reason;
    this.timestamp = Datetime.now();
  }

  public LotteryStatusChange(
    Id recordId,
    String fromStatus,
    String toStatus,
    String reason,
    Decimal priorityGroup
  ) {
    this(recordId, fromStatus, toStatus, reason);
    this.priorityGroup = priorityGroup;
  }
}