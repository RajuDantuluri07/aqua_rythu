import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed/master_feed_engine.dart';

final smartFeedDebugProvider =
    StateNotifierProvider<SmartFeedDebugNotifier, OrchestratorResult?>((ref) {
  return SmartFeedDebugNotifier();
});

class SmartFeedDebugNotifier extends StateNotifier<OrchestratorResult?> {
  SmartFeedDebugNotifier() : super(null);

  void setResult(OrchestratorResult result) {
    state = result;
  }

  void clear() {
    state = null;
  }
}
