// Feed Orchestrator — thin wrapper over MasterFeedEngine (SSOT)
//
// All pipeline logic lives in master_feed_engine.dart.
// This file exists only for import compatibility.
// Prefer calling MasterFeedEngine.orchestrate() directly.

export '../../../features/feed/models/correction_result.dart';
export '../../../features/feed/models/orchestrator_result.dart';

import 'master_feed_engine.dart';
import '../../../features/feed/models/feed_input.dart';

class FeedOrchestrator {
  static OrchestratorResult compute(FeedInput input) =>
      MasterFeedEngine.orchestrate(input);

  static Future<OrchestratorResult> computeForPond(String pondId) =>
      MasterFeedEngine.orchestrateForPond(pondId);
}
