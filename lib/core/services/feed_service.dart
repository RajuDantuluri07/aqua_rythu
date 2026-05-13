import 'package:supabase_flutter/supabase_flutter.dart';
import '../../systems/planning/feed_plan_constants.dart';
import '../../features/tray/enums/tray_status.dart';
import '../../features/feed/feed_schedule_provider.dart';
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
      // 🔒 FIX #1: Use safe insert function to prevent duplicates
      // This will check for existing (pond_id, doc, round) before inserting
      final inserted = await supabase.rpc('safe_insert_feed_log', params: {
        'p_pond_id': pondId,
        'p_doc': doc,
        'p_round': 1, // Daily feed log uses round=1 by convention
        'p_feed_given': actualFeedGiven,
        'p_base_feed': baseFeed,
        'p_created_at': date.toIso8601String(),
        'p_tray_leftover': leftoverPercent,
        'p_stocking_type': stockingType,
        'p_density': density,
      });

      if (!inserted) {
        AppLogger.warn(
            'Feed log skipped - duplicate entry for pond $pondId DOC $doc');
        return; // Skip silently for duplicates
      }
    });
  }

  /// Check inventory stock before feeding.
  ///
  /// Throws [InsufficientStockException] if feeding [feedAmount] would push
  /// stock negative — callers must surface this to the farmer before saving.
  /// Non-stock errors (DB unavailable, missing farm_id) are swallowed so they
  /// never block feeding when inventory data is simply absent.
  Future<void> _checkInventoryStock(String pondId, double feedAmount) async {
    InsufficientStockException? stockError;
    try {
      final pondRow = await supabase
          .from('ponds')
          .select('farm_id')
          .eq('id', pondId)
          .maybeSingle();
      final farmId = pondRow?['farm_id'] as String?;
      if (farmId == null) return;

      final feedItem = await _inventoryService.getFeedItemForFarm(farmId);
      if (feedItem == null) return;

      final stock = await _inventoryService.getInventoryStock(farmId);
      final feedStock = stock.firstWhere(
        (item) => item['category'] == 'feed' && item['is_auto_tracked'] == true,
        orElse: () => <String, dynamic>{},
      );

      if (feedStock.isEmpty) return;

      final currentStock =
          (feedStock['expected_stock'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStock - feedAmount;

      if (newStock < 0) {
        stockError = InsufficientStockException(
          'Insufficient feed stock: need ${feedAmount.toStringAsFixed(1)} kg '
          'but only ${currentStock.toStringAsFixed(1)} kg available. '
          'Please restock before feeding.',
        );
      } else if (newStock <= 20.0) {
        AppLogger.info(
            'LOW STOCK WARNING: Pond $pondId has ${newStock.toStringAsFixed(1)} kg remaining after feeding');
      }
    } catch (e) {
      // DB/inventory errors must not block feeding — just log and continue.
      AppLogger.error('Failed to check inventory stock: $e');
    }
    // Rethrow outside the catch so the block-feeding path is never swallowed.
    if (stockError != null) throw stockError;
  }

  /// Fetch all logged feed entries for a pond, oldest first.
  /// Fix #2: include 'doc' so FeedHistoryLog.doc is populated (was always 0).
  /// Fix #6: include 'round' so each feed entry can be mapped to its round.
  Future<List<Map<String, dynamic>>> fetchFeedLogs(String pondId) async {
    // ✅ Guard: Return empty list if pondId is empty (prevents invalid UUID errors)
    if (pondId.isEmpty) {
      return [];
    }

    return await supabase
        .from('feed_logs')
        .select('feed_given, base_feed, created_at, doc, round')
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
  Future<void> saveFeedPlans(String pondId, List<FeedDayPlan> feedPlans) async {
    if (pondId.isEmpty) throw Exception('Invalid pondId');

    try {
      for (final plan in feedPlans) {
        final doc = plan.doc;
        final List<double> amounts = List<double>.from(plan.rounds);

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

  /// Save individual feed round for atomic updates.
  ///
  /// This uses the canonical DB transaction so `feed_rounds.status` and the
  /// matching `feed_logs` row are written together. Writing `feed_logs`
  /// directly has broken in production when app columns drifted from the DB
  /// schema (for example `feed_kg`/`source` are not part of the current
  /// feed_logs table).
  Future<void> saveFeedRound({
    required String pondId,
    required int doc,
    required int round,
    required double amount,
    required bool isManual,
  }) async {
    await _completeFeedRoundWithLog(
      pondId: pondId,
      doc: doc,
      round: round,
      amount: amount,
      baseFeed: amount,
      createdAt: DateTime.now(),
    );
  }

  int getNextRoundFromHistory(List<FeedLog> logs, int doc) {
    final sameDayLogs = logs.where((l) => l.doc == doc).toList();

    if (sameDayLogs.isEmpty) {
      return 1;
    }

    final lastRound =
        sameDayLogs.map((l) => l.round).reduce((a, b) => a > b ? a : b);

    return lastRound + 1;
  }

  Future<void> saveFeedEntry({
    required String pondId,
    required int doc,
    required double feedKg,
    required int? selectedRound,
    required bool isPro,
  }) async {
    if (doc > 150) {
      throw Exception('Crop completed');
    }

    final logs = await fetchFeedLogs(pondId);
    final parsedLogs = logs.map(FeedLog.fromMap).toList();

    final round = selectedRound ?? getNextRoundFromHistory(parsedLogs, doc);

    await _completeFeedRoundWithLog(
      pondId: pondId,
      doc: doc,
      round: round,
      amount: feedKg,
      // The RPC persists this as feed_logs.base_feed. The UI already passes the
      // final quantity for this round here, so use it as the fallback planned
      // value instead of writing app-only columns that do not exist in DB.
      baseFeed: feedKg,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _completeFeedRoundWithLog({
    required String pondId,
    required int doc,
    required int round,
    required double amount,
    required double baseFeed,
    required DateTime createdAt,
  }) async {
    await _withRetry(
        'completeFeedRoundWithLog(pond=$pondId doc=$doc round=$round)',
        () async {
      final response =
          await supabase.rpc('complete_feed_round_with_log', params: {
        'p_pond_id': pondId,
        'p_doc': doc,
        'p_round': round,
        'p_feed_amount': amount,
        'p_base_feed': baseFeed,
        'p_created_at': createdAt.toIso8601String(),
      });

      // Current migrations return JSONB. Some older databases returned BOOLEAN.
      // Supabase may also wrap scalar RPC outputs in a single-element list.
      if (response is bool) {
        if (!response) {
          throw Exception(
              'complete_feed_round_with_log returned false for pond $pondId DOC $doc round $round');
        }
        return;
      }

      late final Map<String, dynamic> result;
      if (response is Map) {
        result = Map<String, dynamic>.from(response);
      } else if (response is List &&
          response.isNotEmpty &&
          response.first is Map) {
        result = Map<String, dynamic>.from(response.first as Map);
      } else {
        throw Exception(
            'Unexpected complete_feed_round_with_log response: $response');
      }

      if (result['success'] != true) {
        throw Exception(
            'Feed was not saved for pond $pondId DOC $doc round $round: ${result['error'] ?? 'unknown database error'}');
      }
    });
  }

}

class InsufficientStockException implements Exception {
  final String message;
  const InsufficientStockException(this.message);
  @override
  String toString() => message;
}

class FeedLog {
  final int doc;
  final int round;

  FeedLog({
    required this.doc,
    required this.round,
  });

  factory FeedLog.fromMap(Map<String, dynamic> map) {
    return FeedLog(
      doc: (map['doc'] as num?)?.toInt() ?? 0,
      round: (map['round'] as num?)?.toInt() ?? 0,
    );
  }
}
