import 'package:supabase_flutter/supabase_flutter.dart';
import 'engine_constants.dart';
import '../utils/logger.dart';
import 'feed_plan_generator.dart';

/// Smart Feed Engine — FCR + Tray driven daily feed adjustment.
///
/// Only activates for DOC > 30 (blind feeding phase uses fixed rates).
/// Safe to call anytime — will return early if DOC ≤ 30 or data is missing.
class SmartFeedEngine {
  static final _supabase = Supabase.instance.client;

  /// Main entry point.
  /// Called after: tray log, feed log, DOC change.
  static Future<void> recalculateFeedPlan(String pondId) async {
    try {
      final pond = await _getPond(pondId);
      if (pond == null) return;

      final currentDoc = _computeDoc(pond['stocking_date'] as String);
      if (currentDoc <= 30) return; // Blind phase — no smart adjustment

      // 1. Ensure rolling 7-day feed window exists
      await ensureFutureFeedExists(pondId, currentDoc);

      // 2. Compute correction factors from tray + FCR signals
      final trayFactor = await _trayFactor(pondId);
      final fcrFactor = await _fcrFactor(pondId, pond, currentDoc);

      // Combined factor clamped to safe guardrail range
      final factor = (trayFactor * fcrFactor).clamp(0.80, 1.15);

      if ((factor - 1.0).abs() < 0.01) return; // No meaningful change

      // 3. Apply factor to next day's pending (non-manual) rounds
      final nextDoc = currentDoc + 1;
      await _applyFactorToNextDay(pondId, nextDoc, factor);

      AppLogger.info(
        'SmartFeed: pond $pondId DOC $currentDoc → DOC $nextDoc '
        'trayFactor=${trayFactor.toStringAsFixed(2)} '
        'fcrFactor=${fcrFactor.toStringAsFixed(2)} '
        'applied=${factor.toStringAsFixed(2)}',
      );
    } catch (e) {
      AppLogger.error('SmartFeedEngine.recalculateFeedPlan failed for $pondId', e);
    }
  }

  /// Legacy activation check — logic is now inside recalculateFeedPlan.
  static Future<void> checkAndActivateSmartFeed(dynamic pond) async {}

  // ── POND DETAILS ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _getPond(String pondId) async {
    return await _supabase
        .from('ponds')
        .select('seed_count, stocking_date, current_abw')
        .eq('id', pondId)
        .maybeSingle();
  }

  static int _computeDoc(String stockingDateStr) {
    final stocking = DateTime.parse(stockingDateStr);
    final today = DateTime.now();
    return today.difference(DateTime(stocking.year, stocking.month, stocking.day)).inDays + 1;
  }

  // ── TRAY FACTOR ───────────────────────────────────────────────────────────
  //
  // Reads today's latest tray log from DB.
  // full  (leftover) → reduce next day   (-15%)
  // empty (all eaten) → increase next day (+10%)
  // partial           → slight reduction  (-5%)
  // no log            → no change         (0%)

  static Future<double> _trayFactor(String pondId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses')
          .eq('pond_id', pondId)
          .eq('date', today)
          .order('round_number', ascending: false)
          .limit(1);

      if (rows.isEmpty) return 1.0;

      final statuses = List<String>.from(rows.first['tray_statuses'] as List);
      if (statuses.isEmpty) return 1.0;

      int full = 0, empty = 0;
      for (final s in statuses) {
        if (s == 'full') full++;
        if (s == 'empty') empty++;
      }

      final majority = statuses.length / 2;
      if (full > majority) return FeedEngineConstants.mediumLeftoverMultiplier; // -15%
      if (empty > majority) return 1.10;                                         // +10%
      return FeedEngineConstants.slightLeftoverMultiplier;                        // -5%
    } catch (e) {
      AppLogger.error('SmartFeedEngine: tray factor fetch failed', e);
      return 1.0;
    }
  }

  // ── FCR FACTOR ────────────────────────────────────────────────────────────
  //
  // Computes actual FCR against target FCR for the current DOC.
  // actualFCR > target + 0.1 → reduce  (-10%)
  // actualFCR < target - 0.1 → increase (+5%)
  // within range              → no change

  static Future<double> _fcrFactor(
    String pondId,
    Map<String, dynamic> pond,
    int currentDoc,
  ) async {
    try {
      final seedCount = (pond['seed_count'] as int?) ?? 100000;

      // Use latest sampled ABW; fall back to target from constants
      final abwGrams = (pond['current_abw'] as num?)?.toDouble() ??
          _interpolate(FeedEngineConstants.abwTargets, currentDoc);

      // Sum all feed given from feed_logs
      final feedLogs = await _supabase
          .from('feed_logs')
          .select('feed_given')
          .eq('pond_id', pondId);

      final totalFeed = feedLogs.fold<double>(
        0.0,
        (sum, row) => sum + ((row['feed_given'] as num?)?.toDouble() ?? 0.0),
      );

      final survival = _interpolate(FeedEngineConstants.survivalRates, currentDoc);
      final biomassKg = seedCount * survival * abwGrams / 1000;

      if (biomassKg < 1.0 || totalFeed < 0.1) return 1.0; // Insufficient data

      final actualFcr = totalFeed / biomassKg;
      final targetFcr = _targetFcr(currentDoc);

      if (actualFcr > targetFcr + 0.1) return 0.90; // Overfeeding → reduce
      if (actualFcr < targetFcr - 0.1) return 1.05; // Underfeeding → increase
      return 1.0;
    } catch (e) {
      AppLogger.error('SmartFeedEngine: FCR factor calc failed', e);
      return 1.0;
    }
  }

  // ── APPLY TO NEXT DAY ─────────────────────────────────────────────────────

  static Future<void> _applyFactorToNextDay(
    String pondId,
    int nextDoc,
    double factor,
  ) async {
    final rows = await _supabase
        .from('feed_rounds')
        .select('id, planned_amount, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', nextDoc)
        .eq('status', 'pending');

    for (final row in rows) {
      if (row['is_manual'] == true) continue; // Never override manual edits

      final current = (row['planned_amount'] as num).toDouble();
      // Apply factor, clamped to ±20%/+15% of base
      final updated = (current * factor).clamp(current * 0.80, current * 1.15);

      await _supabase
          .from('feed_rounds')
          .update({'planned_amount': double.parse(updated.toStringAsFixed(3))})
          .eq('id', row['id'] as String);
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  static double _targetFcr(int doc) {
    if (doc < 30) return 1.0;
    if (doc < 60) return 1.2;
    if (doc < 90) return 1.3;
    return 1.4;
  }

  static double _interpolate(Map<int, double> table, int doc) {
    final keys = table.keys.toList()..sort();
    if (doc <= keys.first) return table[keys.first]!;
    if (doc >= keys.last) return table[keys.last]!;
    for (int i = 0; i < keys.length - 1; i++) {
      final k1 = keys[i], k2 = keys[i + 1];
      if (doc >= k1 && doc <= k2) {
        final t = (doc - k1) / (k2 - k1);
        return table[k1]! + t * (table[k2]! - table[k1]!);
      }
    }
    return table[keys.last]!;
  }
}
