import 'package:supabase_flutter/supabase_flutter.dart';
import '../../systems/planning/feed_plan_constants.dart';
import '../../features/tray/enums/tray_status.dart';
import '../utils/logger.dart';
import 'inventory_service.dart';

class FeedService {
  final supabase = Supabase.instance.client;
  final _inventoryService = InventoryService();

  Future<void> saveFeed({
    required String pondId,
    required DateTime date,
    required int doc,
    required List<double> rounds,
    required double expectedFeed,
    required double cumulativeFeed,
    required double baseFeed,
    required String engineVersion,
    double? leftoverPercent,
    String? stockingType,
    int? density,
  }) async {
    // feed_given = actual feed given by the farmer (sum of all rounds today).
    // base_feed  = engine recommendation (finalFeed from orchestrator).
    // NOTE: cumulativeFeed (all-time since stocking) is intentionally NOT stored
    // here; it lives only in FeedHistoryLog in-memory state.
    final actualFeedGiven = rounds.fold(0.0, (sum, r) => sum + r);

    // Check inventory stock before feeding (warning only, don't block)
    await _checkInventoryStock(pondId, actualFeedGiven);

    await _withRetry('saveFeed(pond=$pondId doc=$doc)', () async {
      await supabase.from('feed_logs').insert({
        'pond_id': pondId,
        'feed_given': actualFeedGiven,
        'feed_quantity': actualFeedGiven, // For inventory auto-deduction
        'feed_type': 'feed', // Default feed type for inventory
        'base_feed': baseFeed,
        'created_at': date.toIso8601String(),
        'doc': doc,
        if (leftoverPercent != null) 'tray_leftover': leftoverPercent,
        if (stockingType != null) 'stocking_type': stockingType,
        if (density != null) 'density': density,
        'engine_version': engineVersion,
      });
    });
  }

  /// Check inventory stock and log warnings for negative/low stock
  Future<void> _checkInventoryStock(String pondId, double feedAmount) async {
    try {
      // Get feed item for this pond
      final feedItem = await _inventoryService.getFeedItemForCrop(pondId);
      if (feedItem == null) return; // No inventory setup, skip check

      // Get current stock
      final stock = await _inventoryService.getInventoryStock(pondId, null);
      final feedStock = stock.firstWhere(
        (item) => item['category'] == 'feed' && item['is_auto_tracked'] == true,
        orElse: () => <String, dynamic>{},
      );

      if (feedStock.isEmpty) return;

      final currentStock =
          (feedStock['expected_stock'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStock - feedAmount;

      // Log warnings
      if (newStock < 0) {
        AppLogger.warn(
            'NEGATIVE STOCK WARNING: Pond $pondId feeding ${feedAmount}kg will result in ${newStock.toStringAsFixed(1)}kg stock');
      } else if (newStock <= 20.0) {
        AppLogger.info(
            'LOW STOCK WARNING: Pond $pondId has ${newStock.toStringAsFixed(1)}kg stock remaining after feeding');
      }
    } catch (e) {
      // Don't fail feeding if stock check fails, just log the error
      AppLogger.error('Failed to check inventory stock: $e');
    }
  }

  /// Fetch all logged feed entries for a pond, oldest first.
  /// Fix #2: include 'doc' so FeedHistoryLog.doc is populated (was always 0).
  Future<List<Map<String, dynamic>>> fetchFeedLogs(String pondId) async {
    // ✅ Guard: Return empty list if pondId is empty (prevents invalid UUID errors)
    if (pondId.isEmpty) {
      return [];
    }

    return await supabase
        .from('feed_logs')
        .select('feed_given, base_feed, created_at, doc')
        .eq('pond_id', pondId)
        .order('created_at', ascending: true);
  }

  Future<DateTime?> fetchLatestFeedTimeForDoc({
    required String pondId,
    required int doc,
  }) async {
    final row = await supabase
        .from('feed_logs')
        .select('created_at')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return DateTime.tryParse(row['created_at'] as String? ?? '');
  }

  /// Fetch all feed plans for a pond
  Future<List<Map<String, dynamic>>> getFeedPlans(String pondId) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    try {
      return await supabase
          .from('feed_rounds')
          .select('doc, round, planned_amount, base_feed, status')
          .eq('pond_id', pondId)
          .order('doc', ascending: true)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plans: $e');
    }
  }

  /// Fetch feed rounds for specific pond and DOC
  Future<List<dynamic>> getFeedRounds(String pondId, int doc) async {
    final res = await supabase
        .from('feed_rounds')
        .select()
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round');

    AppLogger.debug("Fetched ${res.length} feed rounds for pond $pondId");

    return res;
  }

  /// Fetch feed plan for a specific DOC
  Future<List<Map<String, dynamic>>> getFeedPlanForDoc({
    required String pondId,
    required int doc,
  }) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    try {
      return await supabase
          .from('feed_rounds')
          .select()
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plan for DOC $doc: $e');
    }
  }

  /// Insert a single feed_rounds row and return its new id.
  /// Used for DOC > 30 rounds that have no pre-generated plan.
  Future<String> insertFeedRound({
    required String pondId,
    required int doc,
    required int round,
    required double plannedAmount,
    String status = 'completed',
  }) async {
    return _withRetry('insertFeedRound(pond=$pondId doc=$doc r=$round)',
        () async {
      final response = await supabase
          .from('feed_rounds')
          .insert({
            'pond_id': pondId,
            'doc': doc,
            'round': round,
            'planned_amount': plannedAmount,
            'status': status,
            'is_manual': true,
          })
          .select('id')
          .single();
      return response['id'] as String;
    });
  }

  /// Mark a feed plan as completed
  Future<void> markFeedPlanCompleted({
    required String feedPlanId,
  }) async {
    if (feedPlanId.isEmpty) {
      throw Exception('Invalid feedPlanId');
    }

    await _withRetry('markFeedPlanCompleted($feedPlanId)', () async {
      await supabase
          .from('feed_rounds')
          .update({'status': 'completed'}).eq('id', feedPlanId);
    });
  }

  /// Pre-mark the first [count] feed rounds for a pond+doc as completed.
  /// Called right after pond creation when the farmer reports they've
  /// already fed N times today.
  Future<void> premarkRoundsCompleted({
    required String pondId,
    required int doc,
    required int count,
  }) async {
    if (count <= 0) return;
    final rows = await supabase
        .from('feed_rounds')
        .select('id, round')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round', ascending: true)
        .limit(count);

    for (final row in rows) {
      await _withRetry('premarkRoundsCompleted(${row['id']})', () async {
        await supabase
            .from('feed_rounds')
            .update({'status': 'completed'}).eq('id', row['id'] as String);
      });
    }
  }

  /// Manually override a feed plan amount
  Future<void> overrideFeedAmount({
    required String feedPlanId,
    required double newAmount,
  }) async {
    if (feedPlanId.isEmpty) {
      throw Exception('Invalid feedPlanId');
    }

    await _withRetry('overrideFeedAmount($feedPlanId)', () async {
      await supabase.from('feed_rounds').update({
        'planned_amount': newAmount,
        'is_manual': true,
      }).eq('id', feedPlanId);
    });
  }

  /// Writes redistributed round amounts back to DB (called after redistribution
  /// guard fires in [PondDashboardNotifier.loadTodayFeed]).
  /// Only updates rows that exist (idMap); skips rounds with no row id.
  Future<void> persistCorrectedRounds(
    String pondId,
    int doc,
    Map<int, double> correctedAmounts,
    Map<int, String> idMap,
  ) async {
    for (final entry in correctedAmounts.entries) {
      final round = entry.key;
      final amount = entry.value;
      final id = idMap[round];
      if (id == null || id.isEmpty) continue;
      await _withRetry('persistCorrectedRounds(r$round id=$id)', () async {
        await supabase.from('feed_rounds').update({
          'planned_amount': amount,
          'base_feed': amount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id);
      });
    }
    AppLogger.info('Redistribution written to DB for pond $pondId DOC $doc: '
        '${correctedAmounts.entries.map((e) => "R${e.key}:${e.value.toStringAsFixed(2)}kg").join(" | ")}');
  }

  /// Save feed schedule — always upserts exactly 4 rows per DOC.
  /// Never deletes rows; qty=0 means inactive (no card shown on dashboard).
  Future<void> saveFeedPlans(String pondId, List<dynamic> feedPlans) async {
    if (pondId.isEmpty) throw Exception('Invalid pondId');

    try {
      for (final plan in feedPlans) {
        final doc = plan.doc is int ? plan.doc as int : plan['doc'] as int;
        final List<double> amounts = plan['rounds'] != null
            ? List<double>.from(
                (plan.rounds as List).map((v) => (v as num).toDouble()))
            : [
                _validateFeedAmount(plan['r1'], 'r1', pondId, doc),
                _validateFeedAmount(plan['r2'], 'r2', pondId, doc),
                _validateFeedAmount(plan['r3'], 'r3', pondId, doc),
                _validateFeedAmount(plan['r4'], 'r4', pondId, doc),
              ];

        // Enforce config constraints: inactive rounds for this DOC are always 0.
        // This is the write gate — DB must never hold feed amounts for rounds
        // that have no scheduled time for the given DOC.
        final config = getFeedConfig(doc);
        final paddedRounds = List<double>.generate(4, (i) {
          if (i >= amounts.length) return 0.0;
          if (i >= config.splits.length || config.splits[i] == 0.0) return 0.0;
          return amounts[i];
        });

        // Fetch existing row IDs for this doc (to update vs insert)
        final existing = await supabase
            .from('feed_rounds')
            .select('id, round')
            .eq('pond_id', pondId)
            .eq('doc', doc)
            .order('round');

        final Map<int, String> existingIds = {
          for (final row in existing) (row['round'] as int): row['id'] as String
        };

        // Parallelize the 4 rounds per DOC — previously sequential (4 awaits),
        // now a single parallel batch (1 await for 4 concurrent operations).
        await Future.wait(List.generate(4, (i) async {
          final round = i + 1;
          final qty = paddedRounds[i];
          final existingId = existingIds[round];

          await _withRetry('saveFeedPlans(pond=$pondId doc=$doc r=$round)',
              () async {
            if (existingId != null) {
              await supabase.from('feed_rounds').update({
                'planned_amount': qty,
                'base_feed': qty,
                'is_manual': true,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', existingId);
            } else {
              await supabase.from('feed_rounds').insert({
                'pond_id': pondId,
                'doc': doc,
                'round': round,
                'planned_amount': qty,
                'base_feed': qty,
                'status': 'pending',
                'is_manual': true,
              });
            }
          });
        }));
      }

      AppLogger.info(
          "Feed plans saved for pond $pondId (${feedPlans.length} DOCs × 4 rounds)");
    } catch (e) {
      throw Exception('Failed to save feed plans: $e');
    }
  }

  // ── DEPRECATED STUBS (for backward compatibility during migration) ───────────
  //
  // ⚠️ These methods are NO-OPs. All feed calculation now goes through
  // PondDashboardController. Remove these once all callers are migrated.

  /// DEPRECATED: No-op stub. Use [PondDashboardController.invalidate()] + [load()].
  @Deprecated('Use PondDashboardController instead')
  Future<void> applyTrayAdjustment({
    required String pondId,
    required int doc,
    required TrayStatus trayStatus,
  }) async {
    AppLogger.info(
        'FeedService.applyTrayAdjustment is deprecated - use Controller');
    // No-op: Controller handles this via cache invalidation
  }

  /// DEPRECATED: No-op stub. Use [PondDashboardController.load()].
  @Deprecated('Use PondDashboardController instead')
  Future<void> recalculateFeedPlan(String pondId) async {
    AppLogger.info(
        'FeedService.recalculateFeedPlan is deprecated - use Controller');
    // No-op: Controller handles this
  }

  // ── PRIVATE HELPERS ─────────────────────────────────────────────────────────

  Future<T> _withRetry<T>(String tag, Future<T> Function() fn) async {
    const maxAttempts = 2;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts) {
          AppLogger.error('$tag failed after $maxAttempts attempts', e);
          rethrow;
        }
        AppLogger.warn('$tag attempt $attempt failed, retrying', e);
      }
    }
    throw StateError('unreachable');
  }

  /// Save individual feed round for atomic updates
  Future<void> saveFeedRound({
    required String pondId,
    required int doc,
    required int round,
    required double amount,
    required bool isManual,
  }) async {
    await _withRetry('saveFeedRound(pond=$pondId doc=$doc round=$round)',
        () async {
      await supabase.from('feed_logs').insert({
        'pond_id': pondId,
        'feed_given': amount,
        'feed_quantity': amount, // For inventory auto-deduction
        'feed_type': 'feed', // Default feed type for inventory
        'created_at': DateTime.now().toIso8601String(),
        'doc': doc,
        'round': round,
        'is_manual': isManual,
        'engine_version': 'v1',
      });
    });
  }

  /// Validate feed amount and fail loudly if invalid
  static double _validateFeedAmount(
      dynamic value, String roundName, String pondId, int doc) {
    if (value == null) {
      throw ArgumentError(
          'Missing feed amount for $roundName in pond $pondId, DOC $doc');
    }

    final amount = (value as num).toDouble();

    if (amount < 0) {
      throw ArgumentError(
          'Invalid negative feed amount $amount for $roundName in pond $pondId, DOC $doc');
    }

    if (amount > 1000) {
      // Sanity check - no round should exceed 1000kg
      AppLogger.warn(
          'Very high feed amount $amount for $roundName in pond $pondId, DOC $doc');
    }

    return amount;
  }
}
