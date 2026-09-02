/**
 * Custom exception for lottery lock errors.
 *
 * Thrown when lock acquisition fails or lock verification detects
 * a different job has taken control of the capacity records.
 */
public class LotteryLockException extends Exception {
}