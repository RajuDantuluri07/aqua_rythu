import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  static final CrashlyticsService instance = CrashlyticsService._();
  CrashlyticsService._();

  /// Log a non-fatal (default) or fatal error to Crashlytics.
  ///
  /// Fire-and-forget: Crashlytics errors are never allowed to propagate.
  /// Always rethrow [error] at the call site when the UI must react.
  void logError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: fatal)
        .catchError((_) {});
  }

  /// Attach pond/cycle context to subsequent crash reports.
  ///
  /// Keys persist until overwritten — call with null-only args to clear.
  void setContext({
    String? pondId,
    String? cropCycleId,
    String? farmId,
    int? doc,
    String? screenName,
  }) {
    final crashlytics = FirebaseCrashlytics.instance;
    if (pondId != null) crashlytics.setCustomKey('pond_id', pondId).catchError((_) {});
    if (cropCycleId != null) crashlytics.setCustomKey('crop_cycle_id', cropCycleId).catchError((_) {});
    if (farmId != null) crashlytics.setCustomKey('farm_id', farmId).catchError((_) {});
    if (doc != null) crashlytics.setCustomKey('doc', doc).catchError((_) {});
    if (screenName != null) crashlytics.setCustomKey('screen_name', screenName).catchError((_) {});
  }
}
