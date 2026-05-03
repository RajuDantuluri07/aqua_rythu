import 'time_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/server_time_provider.dart';

/// Calculates DOC from stocking date using server time for tamper-proof calculation
/// Returns null if server time is not yet available (loading state)
/// Returns 1 for future dates or invalid dates (minimum valid DOC)
int? calculateDocFromStockingDate(
  DateTime stockingDate, {
  DateTime? now,
  Ref? ref,
}) {
  // Priority: explicit now parameter > server time from provider > device time fallback
  DateTime? currentTime;

  if (now != null) {
    currentTime = now;
  } else if (ref != null) {
    final serverTime = ref.read(serverDateTimeProvider);
    if (serverTime == null) {
      // Server time not ready yet, return null to indicate loading
      return null;
    }
    currentTime = serverTime;
  } else {
    // Fallback to device time (legacy behavior)
    currentTime = TimeProvider.now();
  }

  final todayUtc =
      DateTime.utc(currentTime.year, currentTime.month, currentTime.day);
  final stockingUtc = DateTime.utc(
    stockingDate.year,
    stockingDate.month,
    stockingDate.day,
  );

  final doc = todayUtc.difference(stockingUtc).inDays + 1;

  // Handle edge cases
  if (doc <= 0) return 1; // Future date or same day
  return doc;
}

/// Legacy version for backward compatibility - uses device time
/// @deprecated Use calculateDocFromStockingDate with ref parameter instead
int calculateDocFromStockingDateLegacy(DateTime stockingDate, {DateTime? now}) {
  final current = now ?? TimeProvider.now();
  final todayUtc = DateTime.utc(current.year, current.month, current.day);
  final stockingUtc = DateTime.utc(
    stockingDate.year,
    stockingDate.month,
    stockingDate.day,
  );

  final doc = todayUtc.difference(stockingUtc).inDays + 1;
  return doc > 0 ? doc : 1;
}
