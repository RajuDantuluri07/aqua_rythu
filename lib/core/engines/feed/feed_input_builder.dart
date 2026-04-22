// ⚠️ DEPRECATED: This file is part of the legacy feed engine.
// The new FeedController in lib/systems/feed_system/ now handles input building internally.
// This file will be removed in v4.0.
// ignore: deprecated_member_use_from_same_package
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../enums/tray_status.dart';
import '../../enums/stocking_type.dart';
import '../../utils/doc_utils.dart';
import '../../utils/time_provider.dart';
import '../../../systems/feed_system/models/feed_input.dart';

class FeedInputBuilder {
  static final _supabase = Supabase.instance.client;
  
  static final bool _hasWarned = false;

  /// Builds the canonical FeedInput for a pond using only persisted state.
  ///
  /// This is the single source of truth for every engine entry point.
  /// 
  /// 🔥 CRASH GUARD: This method will throw if called from new code paths.
  /// Use FeedController.calculateForPond() instead.
  static Future<FeedInput> fromDB(String pondId) async {
    // 🔴 FIX 4: CRASH GUARD - Always throw to prevent usage (not just in debug)
    throw UnsupportedError(
      '🔥 DEPRECATED: FeedInputBuilder.fromDB() is permanently disabled.\n'
      'Use: FeedController.calculateForPond() instead.\n'
      'File: lib/systems/feed_system/feed_controller.dart',
    );
    final pond = await _supabase
        .from('ponds')
        .select(
          'seed_count, stocking_date, stocking_type, current_abw, latest_sample_date, anchor_feed',
        )
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      throw Exception('FeedInputBuilder: pond not found: $pondId');
    }

    final currentDoc = _computeDoc(pond['stocking_date'] as String);
    final seedCount = (pond['seed_count'] as int?) ?? 100000;
    final sample = _latestAbwFromPondData(pond);
    final water = await _latestWaterLog(pondId);
    final trayStatuses = await _latestTrayStatuses(pondId, currentDoc);
    final leftovers = await _last3DaysLeftoverPct(pondId);

    final lastFeedTime = await _latestFeedTime(pondId, currentDoc);

    // Fix #1: compute real values so FeedIntelligenceEngine and FCREngine receive
    // actual data instead of the null that permanently disabled both correction layers.
    final actualFeedYesterday = currentDoc > 1
        ? await _actualFeedForDoc(pondId, currentDoc - 1)
        : null;

    final lastFcr = await _computeLastFcr(
      pondId: pondId,
      seedCount: seedCount,
      abw: sample.abw,
    );

    return FeedInput(
      pondId: pondId,
      seedCount: seedCount,
      doc: currentDoc,
      abw: sample.abw,
      stockingType: StockingType.values.firstWhere(
        (type) => type.name == ((pond['stocking_type'] as String?) ?? 'nursery'),
        orElse: () => StockingType.nursery,
      ),
      trayStatuses: trayStatuses,
      recentTrayLeftoverPct: leftovers.isEmpty ? const [-1.0] : leftovers,
      sampleAgeDays: sample.ageDays,
      dissolvedOxygen: water.dissolvedOxygen,
      ammonia: water.ammonia,
      anchorFeed: (pond['anchor_feed'] as num?)?.toDouble(),
      previousFeed: actualFeedYesterday,
    );
  }

  static Future<List<TrayStatus>> _latestTrayStatuses(String pondId, int doc) async {
    try {
      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('date', ascending: false)
          .order('round_number', ascending: false)
          .limit(1);

      if (rows.isEmpty) return const [];

      final rawStatuses = List<String>.from(rows.first['tray_statuses'] as List? ?? []);
      if (rawStatuses.length == 1 && rawStatuses.first == 'skipped') {
        return const [];
      }

      return rawStatuses.map((status) {
        try {
          return TrayStatus.values.byName(status);
        } catch (_) {
          return TrayStatus.partial;
        }
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static ({double? abw, int ageDays}) _latestAbwFromPondData(
      Map<String, dynamic> pond) {
    final abw = (pond['current_abw'] as num?)?.toDouble();
    if (abw == null || abw <= 0) return (abw: null, ageDays: 0);

    final sampleDateStr = pond['latest_sample_date'] as String?;
    if (sampleDateStr == null) return (abw: null, ageDays: 0);

    final parsed = DateTime.tryParse(sampleDateStr);
    if (parsed == null) return (abw: null, ageDays: 0);

    final localSampled = DateTime(parsed.year, parsed.month, parsed.day);
    final localToday = DateTime(
      TimeProvider.now().year,
      TimeProvider.now().month,
      TimeProvider.now().day,
    );
    final ageDays = localToday.difference(localSampled).inDays;
    if (ageDays > 7) return (abw: null, ageDays: ageDays);

    return (abw: abw, ageDays: ageDays);
  }

  static Future<({double dissolvedOxygen, double ammonia, double temperature, double phChange})>
      _latestWaterLog(String pondId) async {
    const safeDefaults = (
      dissolvedOxygen: 6.0,
      ammonia: 0.05,
      temperature: 28.0,
      phChange: 0.0,
    );
    try {
      final rows = await _supabase
          .from('water_logs')
          .select('dissolved_oxygen, ammonia, temperature, ph, created_at')
          .eq('pond_id', pondId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) return safeDefaults;

      final row = rows.first;

      // Discard readings older than 48 hours. A stale low-DO reading blocks
      // feeding long after conditions recover; a stale safe reading gives false
      // confidence when current water is actually critical.
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (createdAt != null) {
        final ageHours = TimeProvider.now().difference(createdAt).inHours;
        if (ageHours > 48) return safeDefaults;
      }

      return (
        dissolvedOxygen: (row['dissolved_oxygen'] as num?)?.toDouble() ?? 6.0,
        ammonia: (row['ammonia'] as num?)?.toDouble() ?? 0.05,
        temperature: (row['temperature'] as num?)?.toDouble() ?? 28.0,
        phChange: 0.0,
      );
    } catch (_) {
      return safeDefaults;
    }
  }

  static Future<List<double>> _last3DaysLeftoverPct(String pondId) async {
    try {
      final today = TimeProvider.now();
      final todayStr = DateTime(today.year, today.month, today.day)
          .toIso8601String()
          .split('T')[0];
      final sinceStr = today
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')[0];

      // Fetch enough rows so ponds with multiple rounds per day (up to 4)
      // across 3 days are fully covered. LIMIT 3 would give 3 rows from the
      // same busy day instead of one row per distinct day.
      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses, date')
          .eq('pond_id', pondId)
          .gte('date', sinceStr)
          .lt('date', todayStr)
          .order('date', ascending: false)
          .limit(12);

      if (rows.isEmpty) return const [-1.0];

      // Group all tray readings by calendar date, then average within each day.
      // This ensures 3 results = 3 distinct days, not 3 rounds from 1 day.
      final Map<String, List<String>> byDate = {};
      for (final row in rows) {
        final date = row['date'] as String;
        final statuses = List<String>.from(row['tray_statuses'] as List? ?? []);
        byDate.putIfAbsent(date, () => []).addAll(statuses);
      }

      final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
      return sortedDates
          .take(3)
          .map((date) => _statusesToLeftoverPct(byDate[date]!))
          .toList();
    } catch (_) {
      return const [-1.0];
    }
  }

  static Future<DateTime?> _latestFeedTime(String pondId, int doc) async {
    try {
      final row = await _supabase
          .from('feed_logs')
          .select('created_at')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return DateTime.tryParse(row['created_at'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  static double _statusesToLeftoverPct(List<String> statuses) {
    if (statuses.isEmpty) return -1.0;
    if (statuses.every((s) => s == 'skipped')) return -1.0;
    int full = 0, empty = 0;
    for (final s in statuses) {
      if (s == 'full') full++;
      if (s == 'empty') empty++;
    }
    final majority = statuses.length / 2;
    if (full > majority) return 70.0;
    if (empty > majority) return 0.0;
    return 30.0;
  }

  // ── Fix #1: intelligence activation helpers ────────────────────────────────

  /// Returns the total feed given on [doc] (last row = most-complete daily total).
  /// Returns null when no log exists for that day (first day, missed day, etc.).
  static Future<double?> _actualFeedForDoc(String pondId, int doc) async {
    if (doc < 1) return null;
    try {
      // feed_logs may contain multiple rows per day (one per logFeeding call),
      // each carrying a running daily total. The last row is the authoritative sum.
      final row = await _supabase
          .from('feed_logs')
          .select('feed_given')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      final val = (row['feed_given'] as num?)?.toDouble() ?? 0.0;
      return val > 0 ? val : null;
    } catch (_) {
      return null;
    }
  }

  /// Computes cumulative FCR for the current pond cycle.
  ///
  /// FCR = total_feed_given / current_biomass_estimate.
  /// Returns null when there is insufficient data (no ABW or no feed history).
  /// Used as the [FeedInput.lastFcr] signal for FCREngine correction.
  static Future<double?> _computeLastFcr({
    required String pondId,
    required int seedCount,
    required double? abw,
  }) async {
    if (abw == null || abw <= 0) return null;

    try {
      // Conservative survival for biomass estimate (feedback signal only, not display).
      const kSurvivalEstimate = 0.90;
      final biomassKg = (seedCount * kSurvivalEstimate * abw) / 1000;
      if (biomassKg <= 0.1) return null;

      // Fetch all feed logs ascending so the last row per date wins.
      final rows = await _supabase
          .from('feed_logs')
          .select('feed_given, created_at')
          .eq('pond_id', pondId)
          .order('created_at', ascending: true);

      if (rows.isEmpty) return null;

      // Group by calendar date; take the last (most complete) value per day.
      // saveFeed inserts a running-total row on each logFeeding call for the same day,
      // so the final row per date is the authoritative daily total.
      final Map<String, double> latestByDate = {};
      for (final row in rows) {
        final dateKey = (row['created_at'] as String).substring(0, 10);
        final val = (row['feed_given'] as num?)?.toDouble() ?? 0.0;
        latestByDate[dateKey] = val; // ascending order → last entry wins
      }

      final totalFeed =
          latestByDate.values.fold(0.0, (s, v) => s + v);
      if (totalFeed <= 0) return null;

      final fcr = totalFeed / biomassKg;
      // Discard implausible values — likely bad data rather than real FCR.
      if (fcr < 0.5 || fcr > 5.0) return null;
      return fcr;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  static int _computeDoc(String stockingDateStr) {
    final stocking = DateTime.parse(stockingDateStr);
    return calculateDocFromStockingDate(stocking);
  }
}
