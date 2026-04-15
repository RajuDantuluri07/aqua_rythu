import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/tray_status.dart';
import '../utils/doc_utils.dart';
import 'models/feed_input.dart';

class FeedInputBuilder {
  static final _supabase = Supabase.instance.client;

  /// Builds the canonical FeedInput for a pond using only persisted state.
  ///
  /// This is the single source of truth for every engine entry point.
  static Future<FeedInput> fromDB(String pondId) async {
    final pond = await _supabase
        .from('ponds')
        .select(
          'seed_count, stocking_date, stocking_type, current_abw, latest_sample_date',
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

    return FeedInput(
      seedCount: seedCount,
      doc: currentDoc,
      abw: sample.abw,
      stockingType: (pond['stocking_type'] as String?) ?? 'nursery',
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
      lastFcr: null,
      actualFeedYesterday: null,
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
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final ageDays = localToday.difference(localSampled).inDays;
    if (ageDays > 7) return (abw: null, ageDays: ageDays);

    return (abw: abw, ageDays: ageDays);
  }

  static Future<({double dissolvedOxygen, double ammonia, double temperature, double phChange})>
      _latestWaterLog(String pondId) async {
    try {
      final rows = await _supabase
          .from('water_logs')
          .select('dissolved_oxygen, ammonia, temperature, ph')
          .eq('pond_id', pondId)
          .order('created_at', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        return (dissolvedOxygen: 6.0, ammonia: 0.05, temperature: 28.0, phChange: 0.0);
      }

      final row = rows.first;
      return (
        dissolvedOxygen: (row['dissolved_oxygen'] as num?)?.toDouble() ?? 6.0,
        ammonia: (row['ammonia'] as num?)?.toDouble() ?? 0.05,
        temperature: (row['temperature'] as num?)?.toDouble() ?? 28.0,
        phChange: 0.0,
      );
    } catch (_) {
      return (dissolvedOxygen: 6.0, ammonia: 0.05, temperature: 28.0, phChange: 0.0);
    }
  }

  static Future<List<double>> _last3DaysLeftoverPct(String pondId) async {
    try {
      final today = DateTime.now();
      final todayStr = DateTime(today.year, today.month, today.day)
          .toIso8601String()
          .split('T')[0];
      final sinceStr = today
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')[0];

      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses')
          .eq('pond_id', pondId)
          .gte('date', sinceStr)
          .lt('date', todayStr)
          .order('date', ascending: false)
          .limit(3);

      return rows
          .map<double>((row) => _statusesToLeftoverPct(
                List<String>.from(row['tray_statuses'] as List? ?? []),
              ))
          .toList();
    } catch (_) {
      return const [-1.0];
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

  static int _computeDoc(String stockingDateStr) {
    final stocking = DateTime.parse(stockingDateStr);
    return calculateDocFromStockingDate(stocking);
  }
}
