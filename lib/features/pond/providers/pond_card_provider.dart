import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pond_card_data.dart';
import '../controllers/pond_dashboard_controller.dart';
import '../../farm/farm_provider.dart';
// import '../../../systems/feed/feed_calculations.dart'; // Bypassed - controller handles calculations

/// Computes PondCardData for a given pondId.
/// Auto-disposes when no card is watching — safe to use in list views.
final pondCardProvider = FutureProvider.autoDispose
    .family<PondCardData, String>((ref, pondId) async {
  // ── 1. Pond metadata from local state ─────────────────────────────────────
  final farmState = ref.watch(farmProvider);
  final pond = farmState.farms
      .expand((f) => f.ponds)
      .cast<Pond?>()
      .firstWhere((p) => p?.id == pondId, orElse: () => null);

  if (pond == null) throw ArgumentError('Pond $pondId not found in farm state');

  // ── 2. Feed intelligence from controller ──────────────────────────────────
  final viewState = await pondDashboardController.load(pondId);
  final feedResult = viewState.feedResult;

  // Use server time for tamper-proof DOC calculation
  final serverDoc = pond.calculateDocWithRef(ref);
  final doc =
      serverDoc ?? pond.doc; // Fallback to device time if server not ready

  // ── 3. Sampling freshness ─────────────────────────────────────────────────
  final hasSampling = pond.latestSampleDate != null &&
      DateTime.now().difference(pond.latestSampleDate!).inDays <= 7;

  // ── 4. ABW & growth factor ────────────────────────────────────────────────
  final abw = pond.currentAbw ?? 0.0;
  // Simplified: growth factor set to 1.0 since controller doesn't expose expected ABW
  const growthFactor = 1.0;

  // ── 5. Feed values ────────────────────────────────────────────────────────
  final todayFeed = feedResult?.baseFeed ?? 0.0;
  final rawSuggested = feedResult?.finalFeed ?? todayFeed;
  // Clamp suggested to [0, ∞) — never feed negative
  final suggestedFeed = rawSuggested.clamp(0.0, double.infinity);

  final trayFactor = feedResult?.correction.trayFactor ?? 1.0;
  // Tray is considered active if its factor deviated meaningfully from 1.0
  final hasTray = (trayFactor - 1.0).abs() > 0.01;

  // Standardized finalFactor from engine: trayFactor * envFactor
  final finalFactor =
      feedResult?.debugInfo.combinedFactor ?? 1.0;

  // Clamp percent to [-30, +30] per spec
  final percentChange = ((finalFactor - 1.0) * 100).clamp(-30.0, 30.0);

  // ── 6. Money impact ───────────────────────────────────────────────────────
  final rawMoneySaved = (todayFeed - suggestedFeed) * PondCardData.feedPrice;
  final moneySaved = _isSmartMode(doc, hasSampling) ? rawMoneySaved : 0.0;

  // ── 7. Pond stats ─────────────────────────────────────────────────────────
  final survival = _survivalEstimate(doc);
  final density = pond.area > 0 ? (pond.seedCount / 100000.0) / pond.area : 0.0;
  final fcr = feedResult?.debugInfo.fcr ?? 0.0;

  // ── 8. Labels ─────────────────────────────────────────────────────────────
  final trayResult = _trayResultLabel(hasTray, trayFactor);
  final growthLabel = _growthLabel(abw, growthFactor);

  // ── 9. Status engine ──────────────────────────────────────────────────────
  final status = _computeStatus(survival, growthFactor, trayFactor);

  // ── 10. Confidence ────────────────────────────────────────────────────────
  final confidence = _computeConfidence(hasTray, hasSampling);

  return PondCardData(
    pondId: pondId,
    pondName: pond.name,
    size: pond.area,
    doc: doc,
    density: density,
    survival: survival,
    todayFeed: todayFeed,
    abw: abw,
    fcr: fcr,
    hasSampling: hasSampling,
    hasTray: hasTray,
    trayFactor: trayFactor,
    growthFactor: growthFactor,
    finalFactor: finalFactor,
    suggestedFeed: suggestedFeed,
    percentChange: percentChange,
    moneySaved: moneySaved,
    status: status,
    confidence: confidence,
    isSmartMode: _isSmartMode(doc, hasSampling),
    trayResult: trayResult,
    growthLabel: growthLabel,
    feedStage: feedResult?.debugInfo.feedStage ?? 'blind',
  );
});

// ── Helpers ──────────────────────────────────────────────────────────────────

bool _isSmartMode(int doc, bool hasSampling) => doc > 30 || hasSampling;

double _survivalEstimate(int doc) {
  if (doc <= 30) return 90.0;
  if (doc <= 60) return 85.0;
  if (doc <= 90) return 80.0;
  return 75.0;
}

String _trayResultLabel(bool hasTray, double trayFactor) {
  if (!hasTray) return '—';
  if (trayFactor < 0.95) return 'Leftover';
  if (trayFactor > 1.05) return 'Empty';
  return 'Normal';
}

String _growthLabel(double abw, double growthFactor) {
  if (abw <= 0) return '—';
  if (growthFactor < 0.85) return 'Slow';
  if (growthFactor > 1.10) return 'Fast';
  return 'Good';
}

String _computeStatus(double survival, double growthFactor, double trayFactor) {
  if (survival < 70 || growthFactor < 0.75) return 'Risk';
  if (trayFactor < 0.90 || growthFactor < 0.85) return 'Attention';
  return 'Good';
}

String _computeConfidence(bool hasTray, bool hasSampling) {
  if (hasTray && hasSampling) return 'High';
  if (hasTray || hasSampling) return 'Medium';
  return 'Low';
}
