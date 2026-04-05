import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ DEPRECATED - DO NOT USE
// This provider is disabled for MVP stabilization
// All feed amounts come from database (feed_plans table)

/// ✨ TODAY'S SMART FEED (DEACTIVATED for MVP)
/// 
/// For MVP: Returns null to disable smart feed calculations
/// Feed amounts come directly from database (feed_plans table)

class SmartFeedOutput {
  final double recommendedFeed;
  final List<double> roundDistribution;
  final bool isStopFeeding;
  final String? stopReason;

  SmartFeedOutput({
    required this.recommendedFeed,
    required this.roundDistribution,
    this.isStopFeeding = false,
    this.stopReason,
  });
}

/// Smart feed provider — returns null (disabled for MVP, smart engine activates post-DOC 30)
final smartFeedProvider = FutureProvider.family<SmartFeedOutput?, String>((ref, pondId) async {
  return null;
});
