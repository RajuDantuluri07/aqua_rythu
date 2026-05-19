/// Deterministic ordering for mixed timeline events.
///
/// When multiple events share the same time slot, [TimelinePriority.of]
/// provides a stable sort key so the timeline never jumps or reorders.
///
/// Priority order (lower value = rendered first):
///   1. Water Treatments  — applied before feeding begins
///   2. Feed Supplements  — mixed into feed, resolved before the round
///   3. Feed Events       — the actual feeding round
///   4. Sampling          — post-feed data collection
///   5. Alerts            — informational, lowest visual precedence
enum TimelineEventType {
  waterTreatment,
  feedSupplement,
  feedEvent,
  sampling,
  alert,
}

class TimelinePriority {
  const TimelinePriority._();

  static int of(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.waterTreatment:
        return 1;
      case TimelineEventType.feedSupplement:
        return 2;
      case TimelineEventType.feedEvent:
        return 3;
      case TimelineEventType.sampling:
        return 4;
      case TimelineEventType.alert:
        return 5;
    }
  }
}
