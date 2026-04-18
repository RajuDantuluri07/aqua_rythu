import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed/master_feed_engine.dart';

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

final smartFeedProvider = FutureProvider.family<SmartFeedOutput?, String>((ref, pondId) async {
  final result = await MasterFeedEngine.orchestrateForPond(pondId);

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
