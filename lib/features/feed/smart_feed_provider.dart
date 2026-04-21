import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pond/controllers/pond_dashboard_controller.dart';

/// ⚠️ DEPRECATED: Use [PondDashboardController] directly instead.
///
/// This provider is kept for backward compatibility but now delegates
/// to the controller to prevent duplicate feed engine calls.
///
/// The controller is the single source of truth for feed orchestration.
@Deprecated(
    'Use PondDashboardController.load() instead. This provider will be removed.')
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

/// DEPRECATED: Use [PondDashboardController] directly.
///
/// This provider now delegates to the controller to ensure:
/// - Feed engine runs exactly once per pond+doc
/// - No flickering from competing calculations
/// - Consistent feed values across the app
@Deprecated(
    'Use pondDashboardController.load(pondId) instead. This provider will be removed.')
final smartFeedProvider =
    FutureProvider.family<SmartFeedOutput?, String>((ref, pondId) async {
  // ✅ DELEGATE TO CONTROLLER: Prevents duplicate orchestrator calls
  final viewState = await pondDashboardController.load(pondId);

  if (viewState.feedResult == null) return null;

  final result = viewState.feedResult!;

  final isStop = result.decision.action == 'Stop Feeding';
  if (isStop) {
    return SmartFeedOutput(
      recommendedFeed: 0,
      roundDistribution: const [],
      isStopFeeding: true,
      stopReason: result.decision.reason,
    );
  }

  final total = result.finalFeed;
  const rounds = 4;
  final perRound = double.parse((total / rounds).toStringAsFixed(2));
  final remainder = double.parse(
    (total - perRound * rounds).toStringAsFixed(2),
  );
  final distribution = List<double>.generate(
    rounds,
    (i) => i == 0 ? perRound + remainder : perRound,
  );

  return SmartFeedOutput(
    recommendedFeed: total,
    roundDistribution: distribution,
  );
});
