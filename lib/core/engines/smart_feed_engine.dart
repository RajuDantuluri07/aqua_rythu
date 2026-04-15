import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../enums/tray_status.dart';
import 'feed_input_builder.dart';
import 'feed_plan_generator.dart';
import 'master_feed_engine.dart';
import 'models/feed_output.dart';
import '../../repositories/feed_repository.dart';

/// Feed phase for a given DOC.
///
///   NORMAL     (DOC 1–14)  : fixed feed, no tray/smart adjustment
///   TRAY_HABIT (DOC 15–30) : collect tray data for habit-building, no adjustment
///   SMART      (DOC > 30)  : full hybrid — tray × smart × sampling × safety guardrails
enum FeedMode { normal, trayHabit, smart }

/// Hybrid Smart Feed Engine v2
///
/// Formula (SMART phase only):
///   finalFeed = baseFeed × computeFinalFeedFactor(tray, smart, abw, doc)
///
/// Factor priority (highest → lowest):  TRAY > SMART > SAMPLING
/// Safety clamp: final factor capped at ±10%, with consecutive-increase and
/// overfeeding guards.
class SmartFeedEngine {
  static final _supabase = Supabase.instance.client;
  static final _feedRepo = FeedRepository();

  /// Set true in dev/debug builds to emit verbose factor logs.
  static bool debugMode = false;

  // ── FEED MODE ─────────────────────────────────────────────────────────────

  static FeedMode getFeedMode(int doc) {
    if (doc <= 14) return FeedMode.normal;
    if (doc <= 30) return FeedMode.trayHabit;
    return FeedMode.smart;
  }

  // ── PUBLIC ENTRY POINTS ───────────────────────────────────────────────────

  /// Called immediately after a tray log is saved.
  /// Orchestrates the unified feed calculation and updates planned rounds.
  static Future<void> applyTrayAdjustment({
    required String pondId,
    required int doc,
    required TrayStatus trayStatus,
  }) async {
    final mode = getFeedMode(doc);
    if (mode == FeedMode.normal) return;

    final input = await FeedInputBuilder.fromDB(pondId);
    final output = MasterFeedEngine.run(input);

    if (output.finalFactor <= 0.0) return;

    final reasonTag = _reasonTag(output.finalFactor, trayStatus.name, mode);

    await _logDebug(
      pondId: pondId,
      doc: doc,
      mode: mode,
      output: output,
      reason: reasonTag,
      abw: input.abw,
    );

    if (debugMode) {
      AppLogger.debug(
        '[HybridFeed] applyTrayAdjustment pond=$pondId DOC=$doc mode=${mode.name} '
        'tray=${(output.factors['tray'] ?? 1.0).toStringAsFixed(3)} '
        'growth=${(output.factors['growth'] ?? 1.0).toStringAsFixed(3)} '
        'sampling=${(output.factors['sampling'] ?? 1.0).toStringAsFixed(3)} '
        'environment=${(output.factors['environment'] ?? 1.0).toStringAsFixed(3)} '
        'final=${output.finalFactor.toStringAsFixed(3)}',
      );
    }

    for (int i = 1; i <= 3; i++) {
      final futureDoc = doc + i;
      if (futureDoc > 120) break;
      await _applyFactorFromBase(pondId, futureDoc, output.finalFactor, reasonTag);
    }

    AppLogger.info(
      'HybridFeed.applyTrayAdjustment: pond $pondId DOC $doc (${mode.name}) → +1/+2/+3 '
      'tray=${trayStatus.name} factor=${output.finalFactor.toStringAsFixed(3)}',
    );
  }

  /// Called after feed logs and on dashboard load.
  /// Recalculates the next DOC using the shared MasterFeedEngine.
  static Future<void> recalculateFeedPlan(String pondId) async {
    try {
      final input = await FeedInputBuilder.fromDB(pondId);
      await ensureFutureFeedExists(pondId, input.doc);

      final output = MasterFeedEngine.run(input);
      if (output.finalFactor <= 0.0) return;

      final nextDoc = input.doc + 1;
      final reason = _reasonTag(output.finalFactor, 'RECALC', getFeedMode(input.doc));

      await _logDebug(
        pondId: pondId,
        doc: input.doc,
        mode: getFeedMode(input.doc),
        output: output,
        reason: reason,
        abw: input.abw,
      );

      await _applyFactorFromBase(pondId, nextDoc, output.finalFactor, reason);

      if (debugMode) {
        AppLogger.debug(
          '[HybridFeed] recalculate pond=$pondId DOC=${input.doc} '
          'tray=${(output.factors['tray'] ?? 1.0).toStringAsFixed(3)} '
          'growth=${(output.factors['growth'] ?? 1.0).toStringAsFixed(3)} '
          'sampling=${(output.factors['sampling'] ?? 1.0).toStringAsFixed(3)} '
          'final=${output.finalFactor.toStringAsFixed(3)}',
        );
      }

      AppLogger.info(
        'HybridFeed.recalculate: pond $pondId DOC=${input.doc} → DOC $nextDoc '
        'final=${output.finalFactor.toStringAsFixed(3)}',
      );
    } catch (e) {
      AppLogger.error('SmartFeedEngine.recalculateFeedPlan failed for $pondId', e);
    }
  }

  /// Legacy no-op — kept for call-site compatibility.
  static Future<void> checkAndActivateSmartFeed(dynamic pond) async {}

  // ── DB APPLICATION ────────────────────────────────────────────────────────

  static Future<void> _applyFactorFromBase(
    String pondId,
    int doc,
    double factor,
    String reason,
  ) async {
    final rows = await _supabase
        .from('feed_rounds')
        .select('id, base_feed, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');

    for (final row in rows) {
      if (row['is_manual'] == true) continue;

      final base = (row['base_feed'] as num?)?.toDouble();
      if (base == null || base <= 0) continue;

      final adjusted = _applySafetyClamp(base, base * factor);

      final succeeded = await _feedRepo.atomicUpdateRound(
        rowId: row['id'] as String,
        newPlannedAmount: double.parse(adjusted.toStringAsFixed(3)),
        adjustmentReason: reason,
      );

      if (!succeeded) {
        AppLogger.debug('HybridFeed: race on row ${row['id']} (doc $doc) — skipped');
      }
    }
  }

  /// Hard clamp: adjusted amount never goes below 70% or above 130% of base.
  static double _applySafetyClamp(double base, double adjusted) {
    return adjusted.clamp(base * 0.70, base * 1.30);
  }

  // ── DEBUG LOGGING ─────────────────────────────────────────────────────────

  static Future<void> _logDebug({
    required String pondId,
    required int doc,
    required FeedMode mode,
    required FeedOutput output,
    required String reason,
    double? abw,
  }) async {
    try {
      await _supabase.from('feed_debug_logs').insert({
        'pond_id': pondId,
        'doc': doc,
        'mode': mode.name,
        'base_feed': output.baseFeed,
        'tray_factor': output.factors['tray'] ?? 1.0,
        'growth_factor': output.factors['growth'] ?? 1.0,
        'sampling_factor': output.factors['sampling'] ?? 1.0,
        'environment_factor': output.factors['environment'] ?? 1.0,
        'fcr_factor': output.factors['fcr'] ?? 1.0,
        'abw': abw,
        'final_factor': output.finalFactor,
        'final_feed': output.recommendedFeed,
        'engine_version': output.engineVersion,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Debug logging must never crash the main flow
      AppLogger.debug('feed_debug_logs insert failed (non-critical): $e');
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  static String _reasonTag(double factor, String trayStatus, FeedMode mode) {
    final pct = ((factor - 1.0) * 100).round();
    final prefix = mode == FeedMode.trayHabit ? 'TRAY_HABIT' : 'TRAY';
    if (pct == 0) return '${prefix}_${trayStatus.toUpperCase()} HOLD';
    return pct > 0
        ? '${prefix}_${trayStatus.toUpperCase()} +$pct%'
        : '${prefix}_${trayStatus.toUpperCase()} $pct%';
  }
}
