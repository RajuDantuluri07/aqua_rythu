import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:aqua_rythu/core/services/farm_service.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
// import 'package:aqua_rythu/core/services/feed_service.dart'; // Removed - recalculation now handled by controller
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/core/utils/logger.dart';
import 'package:aqua_rythu/core/utils/doc_utils.dart';
import 'package:aqua_rythu/core/utils/supabase_errors.dart';
import '../pond/enums/seed_type.dart';

enum PondStatus { active, completed }

class Pond {
  final String id;
  final String name;
  final double area;
  final DateTime stockingDate;
  final int seedCount;
  final int plSize;
  final int numTrays;
  final PondStatus status;
  final double? currentAbw; // Latest sampled average body weight
  final DateTime?
      latestSampleDate; // When the last sample was taken (for freshness check)
  final bool isSmartFeedEnabled; // Smart Feed activation status

  // Feed round config
  final int initialFeedRounds; // Rounds for DOC 1–7 (default 2)
  final int postWeekFeedRounds; // Rounds for DOC 8+  (default 4)
  final bool
      isCustomFeedPlan; // If true, use above values; else use default DOC logic

  // Anchor feed (DOC > 30): farmer-set baseline, adjusted by tray response
  final double? anchorFeed;
  final bool isAnchorInitialized;
  final double? fcr;

  // Seed type: determines which DOC-based feed table to use
  final SeedType seedType;

  // ── Feed Configuration ─────────────────────────────────────────────────────
  final String? feedBrandId; // Selected feed company brand
  final String? feedBrandName; // Display name for the brand

  // ── Harvest / Action Engine fields ─────────────────────────────────────────
  final int? stockCount; // current active stock (after harvests)
  final bool hasSampling; // whether at least one sample exists
  final String harvestStage; // 'none' | 'partial' | 'near' | 'completed'
  final double activeStockPct; // fraction of initial stock still in pond
  final DateTime? lastHarvestDate;
  final double? lastHarvestQty;

  // ── Daily Action Engine fields ──────────────────────────────────────────────
  final String aerationType; // 'low' | 'medium' | 'high' — affects capacity
  final String? trayScore; // 'good' | 'average' | 'poor' — latest tray result

  Pond({
    required this.id,
    required this.name,
    required this.area,
    required this.stockingDate,
    this.seedCount = 100000,
    this.plSize = 10,
    this.numTrays = 4,
    this.status = PondStatus.active,
    this.currentAbw,
    this.latestSampleDate,
    this.isSmartFeedEnabled = false,
    this.initialFeedRounds = 2,
    this.postWeekFeedRounds = 4,
    this.isCustomFeedPlan = false,
    this.anchorFeed,
    this.isAnchorInitialized = false,
    this.fcr,
    SeedType? seedType,
    this.stockCount,
    this.hasSampling = false,
    this.harvestStage = 'none',
    this.activeStockPct = 1.0,
    this.lastHarvestDate,
    this.lastHarvestQty,
    this.aerationType = 'medium',
    this.trayScore,
    this.feedBrandId,
    this.feedBrandName,
  }) : seedType = seedType ?? SeedTypeX.fromPlSize(plSize);

  /// Returns how many feed rounds apply for the given DOC, respecting
  /// any custom plan the farmer has configured.
  int feedRoundsForDoc(int doc) {
    if (isCustomFeedPlan) {
      return doc <= 7 ? initialFeedRounds : postWeekFeedRounds;
    }
    return doc <= 7 ? 2 : 4;
  }

  Pond copyWith({
    String? id,
    String? name,
    double? area,
    DateTime? stockingDate,
    int? seedCount,
    int? plSize,
    int? numTrays,
    PondStatus? status,
    double? currentAbw,
    DateTime? latestSampleDate,
    bool? isSmartFeedEnabled,
    int? initialFeedRounds,
    int? postWeekFeedRounds,
    bool? isCustomFeedPlan,
    double? anchorFeed,
    bool? isAnchorInitialized,
    double? fcr,
    SeedType? seedType,
    int? stockCount,
    bool? hasSampling,
    String? harvestStage,
    double? activeStockPct,
    DateTime? lastHarvestDate,
    double? lastHarvestQty,
    String? aerationType,
    String? trayScore,
    String? feedBrandId,
    String? feedBrandName,
  }) {
    return Pond(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      stockingDate: stockingDate ?? this.stockingDate,
      seedCount: seedCount ?? this.seedCount,
      plSize: plSize ?? this.plSize,
      numTrays: numTrays ?? this.numTrays,
      status: status ?? this.status,
      currentAbw: currentAbw ?? this.currentAbw,
      latestSampleDate: latestSampleDate ?? this.latestSampleDate,
      isSmartFeedEnabled: isSmartFeedEnabled ?? this.isSmartFeedEnabled,
      initialFeedRounds: initialFeedRounds ?? this.initialFeedRounds,
      postWeekFeedRounds: postWeekFeedRounds ?? this.postWeekFeedRounds,
      isCustomFeedPlan: isCustomFeedPlan ?? this.isCustomFeedPlan,
      anchorFeed: anchorFeed ?? this.anchorFeed,
      isAnchorInitialized: isAnchorInitialized ?? this.isAnchorInitialized,
      fcr: fcr ?? this.fcr,
      seedType: seedType ?? this.seedType,
      stockCount: stockCount ?? this.stockCount,
      hasSampling: hasSampling ?? this.hasSampling,
      harvestStage: harvestStage ?? this.harvestStage,
      activeStockPct: activeStockPct ?? this.activeStockPct,
      lastHarvestDate: lastHarvestDate ?? this.lastHarvestDate,
      lastHarvestQty: lastHarvestQty ?? this.lastHarvestQty,
      aerationType: aerationType ?? this.aerationType,
      trayScore: trayScore ?? this.trayScore,
      feedBrandId: feedBrandId ?? this.feedBrandId,
      feedBrandName: feedBrandName ?? this.feedBrandName,
    );
  }

  /// Calculates Day of Culture (DOC) as whole days since stocking.
  /// @deprecated Use calculateDocWithRef or calculateDoc with explicit time parameter
  /// This getter uses device time and is NOT tamper-proof
  int get doc {
    return calculateDoc(DateTime.now());
  }

  /// Calculates DOC using server time for tamper-proof calculation
  /// Returns null if server time is not yet available (loading state)
  int? calculateDocWithRef(Ref ref) {
    return calculateDocFromStockingDate(stockingDate, ref: ref);
  }

  /// Calculates DOC with explicit time parameter (for testing or server time)
  int calculateDoc(DateTime now) {
    return calculateDocFromStockingDateLegacy(stockingDate, now: now);
  }

  /// Computed today's feed amount based on feed history
  /// This is the single source of truth for today's feed data
  double? get todayFeed {
    // This will be computed from feed history in the home screen
    // Returning null here indicates computation is needed
    return null;
  }
}

class Farm {
  final String id;
  final String name;
  final String location;
  final List<Pond> ponds;

  Farm({
    required this.id,
    required this.name,
    required this.location,
    this.ponds = const [],
  });
}

class FarmState {
  final List<Farm> farms;
  final String selectedId;
  final bool accessDenied;
  /// True when the last loadFarms() call failed with a network/DB error.
  /// The UI should show a retry banner when this is true and farms is empty.
  final bool loadError;

  FarmState({
    required this.farms,
    required this.selectedId,
    this.accessDenied = false,
    this.loadError = false,
  });

  Farm? get currentFarm {
    if (farms.isEmpty) return null;
    try {
      return farms.firstWhere((f) => f.id == selectedId);
    } catch (_) {
      return farms.first;
    }
  }

  FarmState copyWith({
    List<Farm>? farms,
    String? selectedId,
    bool? accessDenied,
    bool? loadError,
  }) {
    return FarmState(
      farms: farms ?? this.farms,
      selectedId: selectedId ?? this.selectedId,
      accessDenied: accessDenied ?? this.accessDenied,
      loadError: loadError ?? this.loadError,
    );
  }
}

class FarmNotifier extends StateNotifier<FarmState> {
  FarmNotifier()
      : super(FarmState(
          farms: [], // ✅ CLEANED: Empty list - will load from Supabase
          selectedId: '',
        ));

  void selectFarm(String id) {
    state = state.copyWith(selectedId: id);
  }

  Future<void> loadFarms({String? setAsSelectedId}) async {
    final user = Supabase.instance.client.auth.currentUser;
    AppLogger.debug("Loading farms for user: ${user?.id}");

    if (user == null) {
      return;
    }

    try {
      final data = await FarmService().getFarmsWithPonds();

      final loadedFarms = <Farm>[];
      for (final f in data) {
        try {
          final ponds = <Pond>[];
          for (final p in (f['ponds'] as List? ?? [])) {
            try {
              ponds.add(Pond(
                id: p['id']?.toString() ?? '',
                name: p['name'] ?? '',
                area: (p['area'] as num?)?.toDouble() ?? 0.0,
                stockingDate: p['stocking_date'] != null
                    ? DateTime.tryParse(p['stocking_date'] as String) ??
                        DateTime.now()
                    : DateTime.now(),
                seedCount: p['seed_count'] ?? 100000,
                plSize: p['pl_size'] ?? 10,
                numTrays: p['num_trays'] ?? 4,
                status: p['status'] == 'completed'
                    ? PondStatus.completed
                    : PondStatus.active,
                currentAbw: p['current_abw'] != null
                    ? (p['current_abw'] as num).toDouble()
                    : null,
                latestSampleDate: p['latest_sample_date'] != null
                    ? DateTime.tryParse(p['latest_sample_date'] as String)
                    : null,
                isSmartFeedEnabled: p['is_smart_feed_enabled'] ?? false,
                initialFeedRounds: p['initial_feed_rounds'] ?? 2,
                postWeekFeedRounds: p['post_week_feed_rounds'] ?? 4,
                isCustomFeedPlan: p['is_custom_feed_plan'] ?? false,
                anchorFeed: p['anchor_feed'] != null
                    ? (p['anchor_feed'] as num).toDouble()
                    : null,
                isAnchorInitialized: p['is_anchor_initialized'] ?? false,
                seedType: SeedTypeX.fromDb(p['stocking_type'] as String?),
                stockCount: p['stock_count'] as int?,
                hasSampling: p['has_sampling'] as bool? ?? false,
                harvestStage: p['harvest_stage'] as String? ?? 'none',
                activeStockPct:
                    (p['active_stock_pct'] as num?)?.toDouble() ?? 1.0,
                lastHarvestDate: p['last_harvest_date'] != null
                    ? DateTime.tryParse(p['last_harvest_date'] as String)
                    : null,
                lastHarvestQty: (p['last_harvest_qty'] as num?)?.toDouble(),
                aerationType: p['aeration_type'] as String? ?? 'medium',
                trayScore: p['tray_score'] as String?,
              ));
            } catch (e) {
              AppLogger.error('Failed to parse pond: $e', e);
            }
          }
          loadedFarms.add(Farm(
            id: f['id']?.toString() ?? '',
            name: f['name'] ?? '',
            location: f['location'] ?? '',
            ponds: ponds,
          ));
        } catch (e) {
          AppLogger.error('Failed to parse farm: $e', e);
        }
      }

      state = state.copyWith(
        farms: loadedFarms,
        selectedId: setAsSelectedId ??
            (loadedFarms.isNotEmpty ? loadedFarms.first.id : ''),
        loadError: false,
      );
    } catch (e) {
      AppLogger.error("Error loading farms", e);
      if (isRlsDenied(e)) {
        state = state.copyWith(accessDenied: true);
      } else {
        state = state.copyWith(loadError: true);
      }
    }
  }

  Future<void> deletePond(String farmId, String pondId) async {
    try {
      await PondService().deletePond(pondId);
    } catch (e) {
      AppLogger.error('Failed to delete pond from DB', e);
      rethrow;
    }

    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: f.name,
            location: f.location,
            ponds: f.ponds.where((p) => p.id != pondId).toList(),
          );
        }
        return f;
      }).toList(),
    );
  }

  void updatePond({
    required String pondId,
    required String name,
    required double area,
    required int seedCount,
    required int plSize,
    required DateTime stockingDate,
    required int numTrays,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(
                name: name,
                area: area,
                seedCount: seedCount,
                plSize: plSize,
                stockingDate: stockingDate,
                numTrays: numTrays,
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  Future<void> updatePondStatus(String pondId, PondStatus status) async {
    // Persist to Supabase first
    try {
      await PondService().updatePondStatus(
        pondId: pondId,
        status: status.name,
      );
    } catch (e) {
      AppLogger.error('Failed to persist pond status to DB', e);
      rethrow;
    }

    // Update local state after successful DB write
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(status: status);
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void updateAnchorFeed(String pondId, double anchorFeed) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(
                anchorFeed: anchorFeed,
                isAnchorInitialized: true,
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void updateSmartFeedStatus(String pondId, bool isEnabled) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(isSmartFeedEnabled: isEnabled);
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void resetPond(
    String pondId, {
    required int seedCount,
    required int plSize,
    required DateTime stockingDate,
    int numTrays = 4,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(
                status: PondStatus.active,
                seedCount: seedCount,
                plSize: plSize,
                stockingDate: stockingDate,
                numTrays: numTrays,
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void updateFarm({
    required String farmId,
    required String name,
    required String location,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: name,
            location: location,
            ponds: f.ponds,
          );
        }
        return f;
      }).toList(),
    );
  }

  Future<void> deleteFarm(String farmId) async {
    try {
      await FarmService().deleteFarm(farmId);
    } catch (e) {
      AppLogger.error('Failed to delete farm from DB', e);
      rethrow;
    }

    final updatedFarms = state.farms.where((f) => f.id != farmId).toList();
    final newSelectedId = state.selectedId == farmId
        ? (updatedFarms.isNotEmpty ? updatedFarms.first.id : '')
        : state.selectedId;

    state = state.copyWith(
      farms: updatedFarms,
      selectedId: newSelectedId,
    );
  }

  /// Update pond state after a harvest is logged.
  void updatePondHarvest({
    required String pondId,
    required int newStockCount,
    required double activeStockPct,
    required String harvestStage,
    required double lastHarvestQty,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id != pondId) return p;
            return p.copyWith(
              stockCount: newStockCount,
              activeStockPct: activeStockPct,
              harvestStage: harvestStage,
              lastHarvestDate: DateTime.now(),
              lastHarvestQty: lastHarvestQty,
              hasSampling: false,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

}

final farmProvider = StateNotifierProvider<FarmNotifier, FarmState>((ref) {
  return FarmNotifier();
});

/// Returns the current date/time and refreshes at both midnight and every hour.
///
/// The midnight-aligned timer ensures DOC increments within 1 minute of
/// actual midnight rather than waiting up to 59 minutes for the hourly tick
/// (TICKET-026 — DST/NTP clock jumps could cause wrong DOC for up to 1 hour).
final currentDateProvider = Provider<DateTime>((ref) {
  // Hourly fallback — keeps DOC fresh even without a midnight trigger.
  final hourly =
      Timer.periodic(const Duration(hours: 1), (_) => ref.invalidateSelf());

  // One-shot timer aligned to the next local midnight.
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final untilMidnight = nextMidnight.difference(now);
  final midnight = Timer(untilMidnight, () => ref.invalidateSelf());

  ref.onDispose(() {
    hourly.cancel();
    midnight.cancel();
  });
  return DateTime.now();
});

final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(currentDateProvider);
  return DateTime(now.year, now.month, now.day);
});

final oneWeekAgoProvider = Provider<DateTime>((ref) {
  final today = ref.watch(todayProvider);
  return today.subtract(const Duration(days: 7));
});

final docProvider = Provider.family<int, String>((ref, pondId) {
  // ✅ Guard: Return 1 if pondId is empty (prevents errors in cascading watches)
  if (pondId.isEmpty) {
    return 1;
  }

  final farmState = ref.watch(farmProvider);
  final now = ref.watch(currentDateProvider);

  // Optimization: Check current farm first
  final currentPonds = farmState.currentFarm?.ponds ?? [];
  final currentIdx = currentPonds.indexWhere((p) => p.id == pondId);
  if (currentIdx != -1) {
    return currentPonds[currentIdx].calculateDoc(now);
  }

  // Fallback: Check all other farms
  for (var farm in farmState.farms) {
    final pondIndex = farm.ponds.indexWhere((p) => p.id == pondId);
    if (pondIndex != -1) {
      return farm.ponds[pondIndex].calculateDoc(now);
    }
  }

  return 1;
});
