// Feed phase for a given DOC — used by FeedService to gate smart adjustments.
//
//   NORMAL     (DOC 1–14)  : no tray/smart adjustment
//   TRAY_HABIT (DOC 15–30) : collect tray data; NO feed correction
//   SMART      (DOC ≥ 31)  : full corrections active; tray MANDATORY
enum FeedMode { normal, trayHabit, smart }

/// Returns the [FeedMode] for [doc].
/// Authoritative boundary: smart_feeding = (doc >= 31)
/// DOC 30 is tray-habit (data collected, no corrections) matching the product
/// rule "DOC 1–30 → blind feeding ONLY, DOC > 30 → smart feeding enabled."
FeedMode feedModeForDoc(int doc) {
  if (doc <= 14) return FeedMode.normal;
  if (doc <= 30) return FeedMode.trayHabit;
  return FeedMode.smart;
}
