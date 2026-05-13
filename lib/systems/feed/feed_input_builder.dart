import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/tray/enums/tray_status.dart';
import '../../../features/pond/enums/stocking_type.dart';
import '../../../features/pond/enums/seed_type.dart';
import '../../../core/utils/doc_utils.dart';
import '../../../core/utils/time_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../features/feed/models/feed_input.dart';

class FeedInputBuilder {
  static final _supabase = Supabase.instance.client;

  /// Validates string fields with proper null checking
  static String _validateStringField(dynamic value, String fieldName,
      [String defaultValue = '']) {
    if (value == null) {
      AppLogger.warn(
          'Missing string field: $fieldName, using default: $defaultValue');
      return defaultValue;
    }
    if (value is! String) {
      AppLogger.error(
          'Invalid type for $fieldName: expected String, got ${value.runtimeType}');
      return defaultValue;
    }
    return value;
  }

  /// Validates integer fields with proper null checking
  static int _validateIntField(dynamic value, String fieldName,
      [int defaultValue = 0]) {
    if (value == null) {
      AppLogger.warn(
          'Missing int field: $fieldName, using default: $defaultValue');
      return defaultValue;
    }
    if (value is! int) {
      if (value is num) {
        final intValue = value.toInt();
        AppLogger.warn('Converted num to int for $fieldName: $intValue');
        return intValue;
      }
      AppLogger.error(
          'Invalid type for $fieldName: expected int, got ${value.runtimeType}');
      return defaultValue;
    }
    return value;
  }

  /// Validates double fields with proper null checking
  static double? _validateDoubleField(dynamic value, String fieldName) {
    if (value == null) {
      return null;
    }
    if (value is! num) {
      AppLogger.error(
          'Invalid type for $fieldName: expected num, got ${value.runtimeType}');
      return null;
    }
    final numValue = value;
    if (numValue.isNaN || numValue.isInfinite) {
      AppLogger.error('Invalid double value for $fieldName: $numValue');
      return null;
    }
    return numValue.toDouble();
  }

  /// Builds the canonical FeedInput for a pond using only persisted state.
  ///
  /// This is the single source of truth for every engine entry point.
  static Future<FeedInput> fromDB(String pondId) async {
    final pond = await _supabase
        .from('ponds')
        .select(
          'seed_count, stocking_date, stocking_type, current_abw, latest_sample_date, anchor_feed, area',
        )
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      throw Exception('FeedInputBuilder: pond not found: $pondId');
    }

    // CRITICAL: No default for stocking_date - must be explicitly provided
    if (pond['stocking_date'] == null ||
        pond['stocking_date'].toString().isEmpty) {
      throw Exception(
        'FeedInputBuilder: CRITICAL MISSING DATA - stocking_date is required for pond $pondId. '
        'Cannot calculate DOC without stocking date.',
      );
    }
    final currentDoc = _computeDoc(
        _validateStringField(pond['stocking_date'], 'stocking_date'));
    // CRITICAL: No default for seed_count - must be explicitly provided
    if (pond['seed_count'] == null) {
      throw Exception(
        'FeedInputBuilder: CRITICAL MISSING DATA - seed_count is required for pond $pondId. '
        'Cannot calculate feed without shrimp count.',
      );
    }
    final seedCount = _validateIntField(pond['seed_count'], 'seed_count');
    if (seedCount <= 0) {
      throw Exception(
        'FeedInputBuilder: CRITICAL INVALID DATA - seed_count=$seedCount for pond $pondId. '
        'Cannot calculate feed with zero or negative shrimp count.',
      );
    }
    final sample = _latestAbwFromPondData(pond);
    final pondArea = _validateDoubleField(pond['area'], 'area');
    final water = await _latestWaterLog(pondId);
    final trayStatuses = await _latestTrayStatuses(pondId, currentDoc);
    final leftovers = await _last3DaysLeftoverPct(pondId);

    final lastFeedTime = await _latestFeedTime(pondId, currentDoc);

    // Collect data quality warnings for UI display
    final List<String> dataWarnings = [];
    if (!water.hasValidData && water.fallbackReason.isNotEmpty) {
      dataWarnings.add('⚠️ Water data issue: ${water.fallbackReason}');
    }
    if (sample.abw == null) {
      dataWarnings.add('⚠️ No sampling data - using blind feeding');
    }
    if (trayStatuses.isEmpty && currentDoc > 30) {
      dataWarnings.add('⚠️ No tray data - appetite signals unavailable');
    }

    final validationErrors = <String>[];
    if (pondArea == null) {
      validationErrors.add('Pond area is missing.');
    } else if (pondArea <= 0) {
      validationErrors.add('Pond area must be greater than 0.');
    } else if (pondArea > 1000) {
      validationErrors
          .add('Pond area appears to be in wrong unit (too large).');
    }

    final bool hasIncompleteData = dataWarnings.isNotEmpty;

    // Fix #1: compute real values so FeedIntelligenceEngine and FCREngine receive
    // actual data instead of the null that permanently disabled both correction layers.
    final actualFeedYesterday =
        currentDoc > 1 ? await _actualFeedForDoc(pondId, currentDoc - 1) : null;

    final lastFcr = await _computeLastFcr(
      pondId: pondId,
      seedCount: seedCount,
      abw: sample.abw,
    );

    final stockingTypeStr =
        _validateStringField(pond['stocking_type'], 'stocking_type', 'nursery');
    final seedType = SeedTypeX.fromDb(stockingTypeStr);

    // Nursery transition warning
    if (stockingTypeStr.toLowerCase() == 'nursery' && currentDoc > 10) {
      dataWarnings.add(
        '⚠️ Nursery phase complete (DOC > 10). Pond has transitioned to regular feeding mode.'
      );
    }

    return FeedInput(
      seedCount: seedCount,
      doc: currentDoc,
      abw: sample.abw,
      stockingType: StockingType.values.firstWhere(
        (type) => type.name == stockingTypeStr,
        orElse: () => StockingType.nursery,
      ),
      seedType: seedType,
      feedingScore: 3.0,
      intakePercent: 85.0,
      dissolvedOxygen: water.dissolvedOxygen,
      temperature: water.temperature,
      phChange: water.phChange,
      ammonia: water.ammonia,
      mortality: 0,
      trayStatuses: trayStatuses,
      sampleAgeDays: sample.ageDays,
      recentTrayLeftoverPct: leftovers.isEmpty ? const [-1.0] : leftovers,
      lastFcr: lastFcr,
      actualFeedYesterday: actualFeedYesterday,
      lastFeedTime: lastFeedTime,
      anchorFeed: _validateDoubleField(pond['anchor_feed'], 'anchor_feed'),
      pondId: pondId,
      feedsPerDay: 4, // Default to 4 feeds per day
      pondArea: pondArea,
      dataWarnings: dataWarnings,
      hasIncompleteData: hasIncompleteData || validationErrors.isNotEmpty,
      validationErrors: validationErrors,
    );
  }

  static Future<List<TrayStatus>> _latestTrayStatuses(
      String pondId, int doc) async {
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

      final rawStatuses =
          List<String>.from(rows.first['tray_statuses'] as List? ?? []);
      if (rawStatuses.length == 1 && rawStatuses.first == 'skipped') {
        return const [];
      }

      return rawStatuses.map<TrayStatus>((status) {
        try {
          return TrayStatus.values.byName(status);
        } catch (_) {
          return trayStatusFromName(status.toString());
        }
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get tray statuses for pond $pondId DOC $doc',
          e, stackTrace);
      return const []; // Return empty list as fallback
    }
  }

  static ({double? abw, int ageDays}) _latestAbwFromPondData(
      Map<String, dynamic> pond) {
    final abw = _validateDoubleField(pond['current_abw'], 'current_abw');
    if (abw == null || abw <= 0) return (abw: null, ageDays: 0);

    final sampleDateStr =
        _validateStringField(pond['latest_sample_date'], 'latest_sample_date');
    if (sampleDateStr.isEmpty) return (abw: null, ageDays: 0);

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

  static Future<
      ({
        double dissolvedOxygen,
        double ammonia,
        double temperature,
        double phChange,
        bool hasValidData,
        String fallbackReason
      })> _latestWaterLog(String pondId) async {
    // SAFE FALLBACK: Only for non-critical water parameters
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
          .limit(2);

      if (rows.isEmpty) {
        AppLogger.warn(
          '[FeedInputBuilder] NO WATER DATA for pond $pondId. '
          'Using safe fallback values - feed may be inaccurate.',
        );
        return (
          dissolvedOxygen: safeDefaults.dissolvedOxygen,
          ammonia: safeDefaults.ammonia,
          temperature: safeDefaults.temperature,
          phChange: safeDefaults.phChange,
          hasValidData: false,
          fallbackReason: 'No water data available',
        );
      }

      final latestRow = rows.first;
      final previousRow = rows.length > 1 ? rows[1] : null;

      // Discard readings older than 48 hours. A stale low-DO reading blocks
      // feeding long after conditions recover; a stale safe reading gives false
      // confidence when current water is actually critical.
      final createdAt = DateTime.tryParse(
          _validateStringField(latestRow['created_at'], 'created_at', ''));
      if (createdAt != null) {
        final ageHours = TimeProvider.now().difference(createdAt).inHours;
        if (ageHours > 48) {
          AppLogger.warn(
            '[FeedInputBuilder] STALE WATER DATA (${ageHours}h old) for pond $pondId. '
            'Using safe fallback values - feed may be inaccurate.',
          );
          return (
            dissolvedOxygen: safeDefaults.dissolvedOxygen,
            ammonia: safeDefaults.ammonia,
            temperature: safeDefaults.temperature,
            phChange: safeDefaults.phChange,
            hasValidData: false,
            fallbackReason: 'Water data is $ageHours hours old',
          );
        }
      }

      // Validate critical DO reading - if missing, use safe default but warn
      final doValue =
          _validateDoubleField(latestRow['dissolved_oxygen'], 'dissolved_oxygen');
      if (doValue == null) {
        AppLogger.warn(
          '[FeedInputBuilder] MISSING DO reading for pond $pondId. '
          'Using safe default DO=${safeDefaults.dissolvedOxygen} - feed may be inaccurate.',
        );
      }

      // Calculate pH change from latest vs previous water log
      double calculatedPhChange = safeDefaults.phChange;
      final latestPh = _validateDoubleField(latestRow['ph'], 'ph');
      if (latestPh != null && previousRow != null) {
        final previousPh = _validateDoubleField(previousRow['ph'], 'ph');
        if (previousPh != null) {
          calculatedPhChange = latestPh - previousPh;
        }
      }

      return (
        dissolvedOxygen: doValue ?? safeDefaults.dissolvedOxygen,
        ammonia: _validateDoubleField(latestRow['ammonia'], 'ammonia') ??
            safeDefaults.ammonia,
        temperature: _validateDoubleField(latestRow['temperature'], 'temperature') ??
            safeDefaults.temperature,
        phChange: calculatedPhChange,
        hasValidData: doValue != null,
        fallbackReason: doValue == null ? 'Missing DO reading' : '',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
          '[FeedInputBuilder] FAILED to get water log for pond $pondId',
          e,
          stackTrace);
      AppLogger.warn(
        'Using safe water fallback values - feed may be inaccurate.',
      );
      return (
        dissolvedOxygen: safeDefaults.dissolvedOxygen,
        ammonia: safeDefaults.ammonia,
        temperature: safeDefaults.temperature,
        phChange: safeDefaults.phChange,
        hasValidData: false,
        fallbackReason: 'Water data fetch failed',
      );
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
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get 3-day leftover percentages for pond $pondId',
          e,
          stackTrace);
      return const [-1.0]; // Return default value as fallback
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
      return DateTime.tryParse(
          _validateStringField(row['created_at'], 'created_at', ''));
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get latest feed time for pond $pondId DOC $doc',
          e,
          stackTrace);
      return null; // Return null as fallback
    }
  }

  static double _statusesToLeftoverPct(List<String> statuses) {
    if (statuses.isEmpty) return -1.0;
    if (statuses.every((s) => s == 'skipped')) return -1.0;

    var total = 0.0;
    for (final s in statuses) {
      if (s == 'full') {
        total += 70.0;
      } else if (s == 'partial') {
        total += 30.0;
      } else if (s == 'empty') {
        total += 0.0;
      }
    }

    return total / statuses.length;
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
      final val = _validateDoubleField(row['feed_given'], 'feed_given');
      if (val == null || val <= 0) return null;
      return val;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get actual feed for pond $pondId DOC $doc', e, stackTrace);
      return null; // Return null as fallback
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
        final dateKey = _validateStringField(row['created_at'], 'created_at')
            .substring(0, 10);
        final val =
            _validateDoubleField(row['feed_given'], 'feed_given') ?? 0.0;
        latestByDate[dateKey] = val; // ascending order → last entry wins
      }

      final totalFeed = latestByDate.values.fold(0.0, (s, v) => s + v);
      if (totalFeed <= 0) return null;

      final fcr = totalFeed / biomassKg;
      // Discard implausible values — likely bad data rather than real FCR.
      if (fcr < 0.5 || fcr > 5.0) return null;
      return fcr;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to compute FCR for pond $pondId', e, stackTrace);
      return null; // Return null as fallback
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  static int _computeDoc(String stockingDateStr) {
    final stocking = DateTime.parse(stockingDateStr).toUtc();
    return calculateDocFromStockingDateLegacy(stocking);
  }
}
