import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/engines/engine_constants.dart';
import '../core/engines/feed_plan_constants.dart';
import '../core/utils/logger.dart';

class SamplingService {
  final _supabase = Supabase.instance.client;

  Future<void> addSampling({
    required String pondId,
    required DateTime date,
    required int doc,
    required double weightKg,
    required int totalPieces,
    required double averageBodyWeight,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Insert sampling log
    await _supabase.from('sampling_logs').insert({
      'pond_id': pondId,
      'doc': doc,
      'avg_weight': averageBodyWeight,
      'count': totalPieces,
      'created_at': date.toIso8601String(),
    });

    // 2. Update pond current_abw — critical for FCR calculations
    await _supabase.from('ponds').update({
      'current_abw': averageBodyWeight,
    }).eq('id', pondId);
  }

  /// Recalculates all pending feed_rounds from [doc] to DOC 120 based on
  /// the real sampled ABW. Overrides both planned_amount and base_feed so
  /// future smart adjustments use the corrected baseline.
  ///
  /// This is the highest-priority correction — sampling truth overrides
  /// everything including previous smart adjustments.
  Future<void> applySamplingCorrection({
    required String pondId,
    required int doc,
    required double sampledAbw,
  }) async {
    try {
      // Get pond stocking count for biomass calculation
      final pond = await _supabase
          .from('ponds')
          .select('seed_count')
          .eq('id', pondId)
          .maybeSingle();

      if (pond == null) {
        AppLogger.error('applySamplingCorrection: pond $pondId not found');
        return;
      }

      final seedCount = (pond['seed_count'] as int?) ?? 100000;
      int updatedDocs = 0;

      for (int futureDoc = doc; futureDoc <= 120; futureDoc++) {
        final newTotalFeed = _biomassBasedFeed(
          abwGrams: sampledAbw,
          seedCount: seedCount,
          doc: futureDoc,
        );

        if (newTotalFeed <= 0) continue;

        // Fetch pending rounds for this DOC
        final rows = await _supabase
            .from('feed_rounds')
            .select('id, round, is_manual')
            .eq('pond_id', pondId)
            .eq('doc', futureDoc)
            .eq('status', 'pending');

        if (rows.isEmpty) continue;

        for (final row in rows) {
          if (row['is_manual'] == true) continue; // Respect manual overrides

          final roundNum = (row['round'] as int?) ?? 1;
          final config = getFeedConfig(futureDoc);
          final dist = (roundNum >= 1 && roundNum <= config.rounds)
              ? config.splits[roundNum - 1]
              : (1.0 / config.rounds);
          final roundFeed = double.parse((newTotalFeed * dist).toStringAsFixed(3));

          // Sampling is ground truth: reset planned_amount AND base_feed.
          // Clear smart-adjusted flag so future tray events start fresh from new base.
          await _supabase.from('feed_rounds').update({
            'planned_amount': roundFeed,
            'base_feed': roundFeed,
            'is_smart_adjusted': false,
            'adjustment_reason': 'SAMPLING_RESET',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', row['id'] as String);
        }

        updatedDocs++;
      }

      AppLogger.info(
        'SamplingCorrection: pond $pondId DOC $doc ABW ${sampledAbw.toStringAsFixed(1)}g '
        '→ updated $updatedDocs future DOCs',
      );
    } catch (e) {
      AppLogger.error('SamplingService.applySamplingCorrection failed for $pondId', e);
    }
  }

  /// Computes total daily feed in kg using real sampled ABW.
  double _biomassBasedFeed({
    required double abwGrams,
    required int seedCount,
    required int doc,
  }) {
    final survival = _interpolate(FeedEngineConstants.survivalRates, doc);
    final feedingRate = _interpolate(FeedEngineConstants.feedingRates, doc);
    final biomassKg = seedCount * survival * abwGrams / 1000;
    return biomassKg * feedingRate;
  }

  double _interpolate(Map<int, double> table, int doc) {
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
