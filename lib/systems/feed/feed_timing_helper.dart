/// Clean, minimal helper for feed timing calculations.
/// Replaces the complex feed_status_engine.dart with simple logic.
class FeedTimingHelper {
  /// Calculate the next feed time based on last feed time and interval.
  ///
  /// Parameters:
  /// - lastFeedTime: When the last feed was given
  /// - feedIntervalMinutes: Minutes between feeds
  ///
  /// Returns:
  /// - DateTime of next feed, or null if calculation fails
  static DateTime? nextFeedAt({
    required DateTime lastFeedTime,
    required int feedIntervalMinutes,
  }) {
    try {
      if (feedIntervalMinutes <= 0) {
        return null;
      }
      return lastFeedTime.add(Duration(minutes: feedIntervalMinutes));
    } catch (e) {
      return null; // fail safe
    }
  }
}
