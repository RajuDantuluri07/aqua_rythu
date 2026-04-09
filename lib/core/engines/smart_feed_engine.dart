import 'package:supabase_flutter/supabase_flutter.dart';
import 'engine_constants.dart';
import '../utils/logger.dart';
import '../enums/tray_status.dart';
import 'feed_plan_generator.dart';
import '../../repositories/feed_repository.dart';

/// Feed phase for a given DOC.
///
///   NORMAL     (DOC 1–14)  : fixed feed, no tray/smart adjustment
///   TRAY_HABIT (DOC 15–30) : collect tray data for habit-building, no adjustment
///   SMART      (DOC > 30)  : full hybrid — tray × smart × safety guardrails
enum FeedMode { normal, trayHabit, smart }

/// Hybrid Smart Feed Engine v2
///
/// Formula (SMART phase only):
///   finalFeed = baseFeed × trayFactor × smartFactor
///
/// Safety clamp (Option-A addition): final factor capped at ±10%, with
/// consecutive-increase and overfeeding guards preserved from v1.
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
  /// Applies hybrid factor to DOC+1, DOC+2, DOC+3.
  /// Only active in SMART phase (DOC > 30).
  static Future<void> applyTrayAdjustment({
    required String pondId,
    required int doc,
    required TrayStatus trayStatus,
  }) async {
    final mode = getFeedMode(doc);
    if (mode == FeedMode.normal) return;

    final last3DaysLeftover = await _last3DaysLeftoverPct(pondId);
    final trayFactor = calculateTrayFactor(last3DaysLeftover);

    // TRAY_HABIT: only tray signal, smart = 1.0
    // SMART: full hybrid
    double smartFactor = 1.0;
    if (mode == FeedMode.smart) {
      final pond = await _getPond(pondId);
      if (pond == null) return;
      final seedCount = (pond['seed_count'] as int?) ?? 100000;
      final abw = await _latestAbw(pondId);
      final feedHistory = await _feedHistory(pondId, days: 14);
      smartFactor = getSmartFactor(
        doc: doc,
        abw: abw,
        feedHistory: feedHistory,
        seedCount: seedCount,
      );
    }

    final rawFactor = trayFactor * smartFactor;
    final currentFeed = await _todayTotalFeed(pondId, doc);
    final baseFeed = await _todayBaseFeed(pondId, doc);

    final finalFactor = applySafetyGuards(
      factor: rawFactor,
      consecutiveIncreaseDays: await _consecutiveIncreaseDays(pondId, doc),
      consecutiveDecreaseDays: await _consecutiveDecreaseDays(pondId, doc),
      currentFeed: currentFeed,
      baseFeed: baseFeed,
    );

    final reasonTag = _reasonTag(finalFactor, trayStatus.name, mode);

    await _logDebug(
      pondId: pondId,
      doc: doc,
      mode: mode,
      baseFeed: baseFeed,
      trayFactor: trayFactor,
      smartFactor: smartFactor,
      finalFactor: finalFactor,
      finalFeed: baseFeed * finalFactor,
      reason: reasonTag,
    );

    if ((finalFactor - 1.0).abs() < 0.005) return;

    if (debugMode) {
      AppLogger.debug(
        '[HybridFeed] applyTrayAdjustment pond=$pondId DOC=$doc mode=${mode.name} '
        'tray=${trayFactor.toStringAsFixed(3)} '
        'smart=${smartFactor.toStringAsFixed(3)} '
        'final=${finalFactor.toStringAsFixed(3)}',
      );
    }

    for (int i = 1; i <= 3; i++) {
      final futureDoc = doc + i;
      if (futureDoc > 120) break;
      await _applyFactorFromBase(pondId, futureDoc, finalFactor, reasonTag);
    }

    AppLogger.info(
      'HybridFeed.applyTrayAdjustment: pond $pondId DOC $doc (${mode.name}) → +1/+2/+3 '
      'tray=${trayStatus.name} factor=${finalFactor.toStringAsFixed(3)}',
    );
  }

  /// Called after feed logs and on dashboard load.
  /// Recalculates next DOC using full hybrid engine.
  /// Only active in SMART phase (DOC > 30).
  static Future<void> recalculateFeedPlan(String pondId) async {
    try {
      final pond = await _getPond(pondId);
      if (pond == null) return;

      final currentDoc = _computeDoc(pond['stocking_date'] as String);
      final mode = getFeedMode(currentDoc);
      if (mode == FeedMode.normal) return;

      await ensureFutureFeedExists(pondId, currentDoc);

      final last3DaysLeftover = await _last3DaysLeftoverPct(pondId);
      final trayFactor = calculateTrayFactor(last3DaysLeftover);

      double smartFactor = 1.0;
      if (mode == FeedMode.smart) {
        final seedCount = (pond['seed_count'] as int?) ?? 100000;
        final abw = await _latestAbw(pondId);
        final feedHistory = await _feedHistory(pondId, days: 14);
        smartFactor = getSmartFactor(
          doc: currentDoc,
          abw: abw,
          feedHistory: feedHistory,
          seedCount: seedCount,
        );
      }

      final rawFactor = trayFactor * smartFactor;
      final currentFeed = await _todayTotalFeed(pondId, currentDoc);
      final baseFeed = await _todayBaseFeed(pondId, currentDoc);

      final finalFactor = applySafetyGuards(
        factor: rawFactor,
        consecutiveIncreaseDays: await _consecutiveIncreaseDays(pondId, currentDoc),
        consecutiveDecreaseDays: await _consecutiveDecreaseDays(pondId, currentDoc),
        currentFeed: currentFeed,
        baseFeed: baseFeed,
      );

      final nextDoc = currentDoc + 1;
      final pct = ((finalFactor - 1.0) * 100).round();
      final reason = pct >= 0
          ? '${mode.name.toUpperCase()}_ADJUST +$pct%'
          : '${mode.name.toUpperCase()}_ADJUST ${pct}%';

      await _logDebug(
        pondId: pondId,
        doc: currentDoc,
        mode: mode,
        baseFeed: baseFeed,
        trayFactor: trayFactor,
        smartFactor: smartFactor,
        finalFactor: finalFactor,
        finalFeed: baseFeed * finalFactor,
        reason: reason,
      );

      if ((finalFactor - 1.0).abs() < 0.005) return;

      await _applyFactorFromBase(pondId, nextDoc, finalFactor, reason);

      if (debugMode) {
        AppLogger.debug(
          '[HybridFeed] recalculate pond=$pondId DOC=$currentDoc '
          'tray=${trayFactor.toStringAsFixed(3)} '
          'smart=${smartFactor.toStringAsFixed(3)} '
          'final=${finalFactor.toStringAsFixed(3)}',
        );
      }

      AppLogger.info(
        'HybridFeed.recalculate: pond $pondId DOC $currentDoc → DOC $nextDoc '
        'tray=${trayFactor.toStringAsFixed(3)} '
        'smart=${smartFactor.toStringAsFixed(3)} '
        'applied=${finalFactor.toStringAsFixed(3)}',
      );
    } catch (e) {
      AppLogger.error('SmartFeedEngine.recalculateFeedPlan failed for $pondId', e);
    }
  }

  /// Legacy no-op — kept for call-site compatibility.
  static Future<void> checkAndActivateSmartFeed(dynamic pond) async {}

  // ── LAYER 1: TRAY FACTOR ─────────────────────────────────────────────────

  /// Tray factor from last 3 days average leftover %.
  /// formula: 1.05 - (avgLeftover / 100), clamped [0.85, 1.05].
  ///   0% leftover  → 1.05 (shrimp hungry → feed more)
  ///  20% leftover  → 0.85 (slight overfeeding → reduce)
  ///  40%+ leftover → 0.85 (clamped floor)
  /// No data → 1.0 (no adjustment).
  static double calculateTrayFactor(List<double> last3DaysLeftover) {
    if (last3DaysLeftover.isEmpty) return 1.0;
    final avg = last3DaysLeftover.reduce((a, b) => a + b) / last3DaysLeftover.length;
    return (1.05 - (avg / 100)).clamp(0.85, 1.05);
  }

  // ── LAYER 2: SMART FACTOR ────────────────────────────────────────────────

  /// Growth factor based on actual vs expected ABW ratio.
  static double getGrowthFactor(double ratio) {
    if (ratio > 1.1) return 1.05; // Growing faster than expected
    if (ratio < 0.9) return 0.95; // Growing slower — restrict
    return 1.0;
  }

  /// FCR factor — rewards efficient conversion, penalises waste.
  static double getFCRFactor(double fcr) {
    if (fcr < 1.2) return 1.05; // Efficient → allow more
    if (fcr > 1.6) return 0.95; // Wasteful → restrict
    return 1.0;
  }

  /// Smart factor = average of growth and FCR factors, clamped [0.9, 1.1].
  /// Returns 1.0 when ABW data is unavailable (safe default).
  static double getSmartFactor({
    required int doc,
    required double? abw,
    required List<double> feedHistory,
    required int seedCount,
  }) {
    if (abw == null || abw <= 0) return 1.0;

    final expectedAbw = _interpolate(FeedEngineConstants.abwTargets, doc);
    if (expectedAbw <= 0) return 1.0;

    final growthFactor = getGrowthFactor(abw / expectedAbw);

    // FCR: total feed over biomass
    final totalFeed = feedHistory.fold(0.0, (s, v) => s + v);
    final biomassKg = seedCount * abw / 1000.0;
    if (biomassKg < 1.0 || totalFeed < 0.1) return 1.0;

    final fcrFactor = getFCRFactor(totalFeed / biomassKg);

    // FCR weighted higher (0.6) — more reliable signal than growth alone
    return (growthFactor * 0.4 + fcrFactor * 0.6).clamp(0.9, 1.1);
  }

  // ── LAYER 3: SAFETY GUARDRAILS (Option-A) ────────────────────────────────

  /// Hard safety bounds preserved from v1 to protect crop.
  static double applySafetyGuards({
    required double factor,
    required int consecutiveIncreaseDays,
    required int consecutiveDecreaseDays,
    required double currentFeed,
    required double baseFeed,
  }) {
    // 3.1 Daily change limit ±10%
    double result = factor.clamp(0.90, 1.10);

    // 3.2 Increase streak cap — 3 consecutive increases → cap at +5%
    if (consecutiveIncreaseDays >= 3 && result > 1.05) {
      result = 1.05;
    }

    // 3.3 Decrease streak cap — 3 consecutive decreases → hold (no further reduction)
    if (consecutiveDecreaseDays >= 3 && result < 1.0) {
      result = 1.0;
    }

    // 3.4 Overfeeding protection — already >130% of base → hold
    if (baseFeed > 0 && currentFeed > baseFeed * 1.3 && result > 1.0) {
      result = 1.0;
    }

    return result;
  }

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
        .eq('status', 'pending')
        .eq('is_smart_adjusted', false);

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
    required double baseFeed,
    required double trayFactor,
    required double smartFactor,
    required double finalFactor,
    required double finalFeed,
    required String reason,
  }) async {
    try {
      await _supabase.from('feed_debug_logs').insert({
        'pond_id': pondId,
        'doc': doc,
        'mode': mode.name,
        'base_feed': baseFeed,
        'tray_factor': trayFactor,
        'smart_factor': smartFactor,
        'final_factor': finalFactor,
        'final_feed': finalFeed,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Debug logging must never crash the main flow
      AppLogger.debug('feed_debug_logs insert failed (non-critical): $e');
    }
  }

  // ── DATA FETCHERS ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> _getPond(String pondId) async {
    return await _supabase
        .from('ponds')
        .select('seed_count, stocking_date')
        .eq('id', pondId)
        .maybeSingle();
  }

  /// Latest ABW from sampling_logs.
  static Future<double?> _latestAbw(String pondId) async {
    try {
      final rows = await _supabase
          .from('sampling_logs')
          .select('avg_weight')
          .eq('pond_id', pondId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return null;
      return (rows.first['avg_weight'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Feed given over the last [days] days from feed_logs.
  static Future<List<double>> _feedHistory(String pondId, {int days = 14}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days)).toIso8601String().split('T')[0];
      final rows = await _supabase
          .from('feed_logs')
          .select('feed_given')
          .eq('pond_id', pondId)
          .gte('created_at', since);

      return rows
          .map<double>((r) => (r['feed_given'] as num?)?.toDouble() ?? 0.0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Last 3 days of tray leftover expressed as percentages.
  /// Maps existing tray_statuses array (empty/partial/full) to leftover %:
  ///   empty → 0%,  partial → 30%,  full → 70%
  static Future<List<double>> _last3DaysLeftoverPct(String pondId) async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')[0];
      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses')
          .eq('pond_id', pondId)
          .gte('date', since)
          .order('date', ascending: false)
          .limit(3);

      return rows
          .map<double>((row) => _statusesToLeftoverPct(
                List<String>.from(row['tray_statuses'] as List? ?? []),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Converts a list of tray status strings to a single leftover %.
  static double _statusesToLeftoverPct(List<String> statuses) {
    if (statuses.isEmpty) return 0.0;
    int full = 0, empty = 0;
    for (final s in statuses) {
      if (s == 'full') full++;
      if (s == 'empty') empty++;
    }
    final majority = statuses.length / 2;
    if (full > majority) return 70.0;
    if (empty > majority) return 0.0;
    return 30.0; // partial majority
  }

  /// Sum of today's planned feed (overfeeding guard).
  static Future<double> _todayTotalFeed(String pondId, int doc) async {
    try {
      final rows = await _supabase
          .from('feed_rounds')
          .select('planned_amount')
          .eq('pond_id', pondId)
          .eq('doc', doc);
      return rows.fold<double>(
          0.0, (s, r) => s + ((r['planned_amount'] as num?)?.toDouble() ?? 0.0));
    } catch (_) {
      return 0.0;
    }
  }

  /// Sum of today's base feed (overfeeding guard comparison).
  static Future<double> _todayBaseFeed(String pondId, int doc) async {
    try {
      final rows = await _supabase
          .from('feed_rounds')
          .select('base_feed')
          .eq('pond_id', pondId)
          .eq('doc', doc);
      return rows.fold<double>(
          0.0, (s, r) => s + ((r['base_feed'] as num?)?.toDouble() ?? 0.0));
    } catch (_) {
      return 0.0;
    }
  }

  /// Counts consecutive DOCs with a negative adjustment (for decrease streak cap).
  static Future<int> _consecutiveDecreaseDays(String pondId, int currentDoc) async {
    try {
      int count = 0;
      for (int i = 1; i <= 3; i++) {
        final checkDoc = currentDoc - i;
        if (checkDoc < 1) break;

        final rows = await _supabase
            .from('feed_rounds')
            .select('planned_amount, base_feed')
            .eq('pond_id', pondId)
            .eq('doc', checkDoc)
            .limit(1);

        if (rows.isEmpty) break;
        final planned = (rows.first['planned_amount'] as num?)?.toDouble() ?? 0.0;
        final base = (rows.first['base_feed'] as num?)?.toDouble() ?? 0.0;

        if (base > 0 && planned < base) {
          count++;
        } else {
          break;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Counts consecutive DOCs with a positive adjustment (for increase streak cap).
  static Future<int> _consecutiveIncreaseDays(String pondId, int currentDoc) async {
    try {
      int count = 0;
      for (int i = 1; i <= 3; i++) {
        final checkDoc = currentDoc - i;
        if (checkDoc < 1) break;

        final rows = await _supabase
            .from('feed_rounds')
            .select('planned_amount, base_feed')
            .eq('pond_id', pondId)
            .eq('doc', checkDoc)
            .limit(1);

        if (rows.isEmpty) break;
        final planned = (rows.first['planned_amount'] as num?)?.toDouble() ?? 0.0;
        final base = (rows.first['base_feed'] as num?)?.toDouble() ?? 0.0;

        if (base > 0 && planned > base) {
          count++;
        } else {
          break;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  static int _computeDoc(String stockingDateStr) {
    final stocking = DateTime.parse(stockingDateStr);
    final today = DateTime.now();
    return today
            .difference(DateTime(stocking.year, stocking.month, stocking.day))
            .inDays +
        1;
  }

  static String _reasonTag(double factor, String trayStatus, FeedMode mode) {
    final pct = ((factor - 1.0) * 100).round();
    final prefix = mode == FeedMode.trayHabit ? 'TRAY_HABIT' : 'TRAY';
    if (pct == 0) return '${prefix}_${trayStatus.toUpperCase()} HOLD';
    return pct > 0
        ? '${prefix}_${trayStatus.toUpperCase()} +$pct%'
        : '${prefix}_${trayStatus.toUpperCase()} ${pct}%';
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
