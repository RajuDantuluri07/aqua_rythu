import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:aqua_rythu/core/services/farm_service.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import 'package:aqua_rythu/core/services/feed_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/core/utils/logger.dart';
import 'package:aqua_rythu/core/utils/doc_utils.dart';

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
  final double? currentAbw;        // Latest sampled average body weight
  final DateTime? latestSampleDate; // When the last sample was taken (for freshness check)
  final bool isSmartFeedEnabled;   // Smart Feed activation status

  // Feed round config
  final int initialFeedRounds;    // Rounds for DOC 1–7 (default 2)
  final int postWeekFeedRounds;   // Rounds for DOC 8+  (default 4)
  final bool isCustomFeedPlan;    // If true, use above values; else use default DOC logic

  // Anchor feed (DOC > 30): farmer-set baseline, adjusted by tray response
  final double? anchorFeed;
  final bool isAnchorInitialized;

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
  });

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
    );
  }

  /// Calculates Day of Culture (DOC) as whole days since stocking.
  int get doc {
    return calculateDoc(DateTime.now());
  }

  int calculateDoc(DateTime now) {
    return calculateDocFromStockingDate(stockingDate, now: now);
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

  FarmState({
    required this.farms,
    required this.selectedId,
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
  }) {
    return FarmState(
      farms: farms ?? this.farms,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

class FarmNotifier extends StateNotifier<FarmState> {
  FarmNotifier()
      : super(FarmState(
          farms: [],  // ✅ CLEANED: Empty list - will load from Supabase
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
                    ? DateTime.tryParse(p['stocking_date'] as String) ?? DateTime.now()
                    : DateTime.now(),
                seedCount: p['seed_count'] ?? 100000,
                plSize: p['pl_size'] ?? 10,
                numTrays: p['num_trays'] ?? 4,
                status: p['status'] == 'completed' ? PondStatus.completed : PondStatus.active,
                currentAbw: p['current_abw'] != null ? (p['current_abw'] as num).toDouble() : null,
                latestSampleDate: p['latest_sample_date'] != null
                    ? DateTime.tryParse(p['latest_sample_date'] as String)
                    : null,
                isSmartFeedEnabled: p['is_smart_feed_enabled'] ?? false,
                initialFeedRounds: p['initial_feed_rounds'] ?? 2,
                postWeekFeedRounds: p['post_week_feed_rounds'] ?? 4,
                isCustomFeedPlan: p['is_custom_feed_plan'] ?? false,
                anchorFeed: p['anchor_feed'] != null ? (p['anchor_feed'] as num).toDouble() : null,
                isAnchorInitialized: p['is_anchor_initialized'] ?? false,
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
        selectedId: setAsSelectedId ?? (loadedFarms.isNotEmpty ? loadedFarms.first.id : ''),
      );
    } catch (e) {
      AppLogger.error("Error loading farms", e);
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

  void deleteFarm(String farmId) {
    final updatedFarms = state.farms.where((f) => f.id != farmId).toList();
    final newSelectedId = updatedFarms.isNotEmpty ? updatedFarms.first.id : '';
    
    state = state.copyWith(
      farms: updatedFarms,
      selectedId: newSelectedId,
    );
  }

  /// 🔄 SMART FEED TRIGGER: Trigger recalculation when DOC increments
  void triggerSmartFeedRecalculationOnDocChange(String pondId) {
    // Fire-and-forget Smart Feed recalculation
    FeedService().recalculateFeedPlan(pondId).catchError((e) {
      AppLogger.error('Feed recalculation trigger failed', e);
    });
  }}

final farmProvider = StateNotifierProvider<FarmNotifier, FarmState>((ref) {
  return FarmNotifier();
});

/// A provider that returns the current date and refreshes every hour
/// to ensure DOC increments automatically at midnight.
final currentDateProvider = Provider<DateTime>((ref) {
  // Rebuild this provider every hour
  final timer = Timer.periodic(const Duration(hours: 1), (_) => ref.invalidateSelf());
  ref.onDispose(() => timer.cancel());
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
