import '../enums/tray_status.dart';

/// ARCHIVED: April 15, 2026 — Legacy pipeline, replaced by SmartFeedEngine.
/// This defines an older feed mode system (blind, transitional, smart).
/// Current system uses SmartFeedEngine with FeedMode (normal, trayHabit, smart).
/// 
/// Only used by TrayEngine (which is also archived).
/// Do NOT use this in new code.
enum FeedMode {
  blind,
  transitional,
  smart,
}

class FeedRoundState {
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showMarkFeed;
  final bool showTrayCTA;
  final bool showOptionalTray;
  final bool isTrayLogged;
  final List<TrayStatus>? trayResults;

  const FeedRoundState({
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showMarkFeed,
    required this.showTrayCTA,
    required this.showOptionalTray,
    required this.isTrayLogged,
    this.trayResults,
  });

  FeedRoundState copyWith({
    bool? isDone,
    bool? isCurrent,
    bool? isLocked,
    bool? showMarkFeed,
    bool? showTrayCTA,
    bool? showOptionalTray,
    bool? isTrayLogged,
    List<TrayStatus>? trayResults,
  }) {
    return FeedRoundState(
      isDone: isDone ?? this.isDone,
      isCurrent: isCurrent ?? this.isCurrent,
      isLocked: isLocked ?? this.isLocked,
      showMarkFeed: showMarkFeed ?? this.showMarkFeed,
      showTrayCTA: showTrayCTA ?? this.showTrayCTA,
      showOptionalTray: showOptionalTray ?? this.showOptionalTray,
      isTrayLogged: isTrayLogged ?? this.isTrayLogged,
      trayResults: trayResults ?? this.trayResults,
    );
  }

  static FeedMode getModeByDoc(int doc) {
    if (doc < 15) return FeedMode.blind;
    if (doc <= 30) return FeedMode.transitional;
    return FeedMode.smart;
  }
}

/// Legacy feed state engine — do not use.
class FeedStateEngine {
  /// MODE DECIDER (Smart Feed Activation + DOC-Based)
  /// 
  /// Business Rules (ARCHIVED):
  /// - Smart Feed activates ONLY when DOC > 30 AND isSmartFeedEnabled = true
  /// - Once activated → Smart Feed NEVER turns OFF
  /// - DOC ≤ 30: Blind Feed (Mark as Fed, Tray Optional)
  /// - DOC > 30 + Smart Feed Enabled: Smart Feed (Save Feed, Tray Mandatory)
  /// 
  /// REPLACED BY: SmartFeedEngine.getFeedMode()
  static FeedMode getMode(int doc, {bool isSmartFeedEnabled = false}) {
    // 🟡 DOC < 15: Blind Feed
    if (doc < 15) {
      return FeedMode.blind;
    }

    // 🟠 DOC 15-30: Transitional Feed
    if (doc <= 30) {
      return FeedMode.transitional;
    }

    // 🟣 DOC > 30: Smart Feed only when enabled
    return isSmartFeedEnabled ? FeedMode.smart : FeedMode.transitional;
  }

  /// Legacy method for backward compatibility
  static FeedMode getModeByDoc(int doc) {
    if (doc < 15) return FeedMode.blind;
    if (doc <= 30) return FeedMode.transitional;
    return FeedMode.smart;
  }

  /// Apply tray adjustment (archived implementation)
  static double applyTrayAdjustment(
    List<TrayStatus> trayStatuses,
    double plannedFeed,
    dynamic mode,
  ) {
    // Stub — was legacy implementation
    return plannedFeed;
  }
}
