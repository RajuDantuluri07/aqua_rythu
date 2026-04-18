import 'package:aqua_rythu/core/services/farm_service.dart';
import '../supplements/supplement_mix_screen.dart';
import '../supplements/screens/supplement_item.dart';
import '../supplements/supplement_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_schedule_screen.dart';
import 'pond_dashboard_provider.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';
import '../../features/tray/tray_provider.dart';
import '../tray/tray_model.dart';
import '../../core/enums/tray_status.dart';
import '../farm/farm_provider.dart';
import '../harvest/harvest_provider.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../feed/feed_timeline_card.dart';
import '../feed/smart_feed_provider.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../farm/new_cycle_setup_screen.dart';
import '../harvest/harvest_summary_screen.dart';
import 'package:intl/intl.dart';
import 'package:aqua_rythu/core/theme/app_theme.dart';
import 'package:aqua_rythu/core/engines/planning/feed_plan_constants.dart';
import 'package:aqua_rythu/core/engines/feed/feed_decision_engine.dart';
import 'package:aqua_rythu/core/engines/tray/tray_decision_engine.dart';
import 'package:aqua_rythu/core/engines/pond/pond_value_engine.dart';
import 'package:aqua_rythu/core/engines/feed/feed_status_engine.dart' hide FeedDecision;
import 'package:aqua_rythu/core/engines/feed/engine_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqua_rythu/core/language/language_switcher.dart';
import 'package:aqua_rythu/core/language/app_localizations.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../debug/debug_dashboard_screen.dart';
import 'package:aqua_rythu/features/home/alert_strip.dart';
import 'package:aqua_rythu/core/constants/app_constants.dart';
import 'package:aqua_rythu/features/home/home_view_model.dart';
import 'package:aqua_rythu/features/home/kpi_row.dart';
import 'package:aqua_rythu/features/home/feed_trend_card.dart';
import 'package:aqua_rythu/features/home/home_builder.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  bool _showFeedScheduleTip = false;
  int _debugTapCount = 0;
  bool _completedRoundsExpanded = false;
  // T13 — tracks which round just completed to show feedback prompt once
  int _lastFeedbackRound = -1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _checkFeedScheduleTip();
  }

  /// Secret 5-tap trigger → opens the Feed Engine Debug dashboard.
  void _onDebugTap(String pondId, String pondName) {
    if (!AppConfig.isDebugMode) return;
    _debugTapCount++;
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DebugDashboardScreen(pondId: pondId),
        ),
      );
    }
  }


  Future<void> _checkFeedScheduleTip() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('feed_schedule_tip_pending') ?? false;
    if (pending && mounted) {
      await prefs.remove('feed_schedule_tip_pending');
      setState(() => _showFeedScheduleTip = true);
      _pulseController.repeat(reverse: true);
      // Stop after ~4 seconds (5 pulses)
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted) {
          _pulseController.stop();
          _pulseController.animateTo(0);
          setState(() => _showFeedScheduleTip = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Round state machine
  // DOC < 30: next round unlocks once prev feed is marked done
  // DOC ≥ 30: next round unlocks only AFTER prev feed done AND prev tray logged
  Map<String, dynamic> _getSimpleRoundState({
    required int doc,
    required int round,
    required int totalRounds,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
  }) {
    final isDone = feedDone[round] ?? false;
    final isTrayLogged = trayDone[round] ?? false;
    final isLocked = _isLocked(doc, round, feedDone, trayDone);
    // Current = first round that is not fully cleared
    // For DOC > 30: a round is "cleared" only when both feed done AND tray logged
    final currentRound = _getCurrentRound(doc, feedDone, trayDone, totalRounds);
    final isCurrent = !isDone && round == currentRound;
    // Tray CTA: feed done but tray not yet logged
    // DOC 15–29: optional (show button but doesn't block next round)
    // DOC ≥ 30:  mandatory (blocks next round until logged)
    final showTrayCTA = isDone && doc >= 15 && !isTrayLogged;

    return {
      'isDone': isDone,
      'isCurrent': isCurrent,
      'isLocked': isLocked,
      'showTrayCTA': showTrayCTA,
      'isTrayLogged': isTrayLogged,
    };
  }

  /// Returns the next round that needs action (feed or tray).
  /// DOC ≤ 30: first round where feed is not done.
  /// DOC ≥ 31: first round where feed is not done, but only after previous
  ///           round's tray is logged.
  int _getCurrentRound(int doc, Map<int, bool> feedDone,
      Map<int, bool> trayDone, int totalRounds) {
    for (int i = 1; i <= totalRounds; i++) {
      if (!(feedDone[i] ?? false)) return i;
      // Fix #4: tray blocks next round only in smart mode (DOC ≥ 31).
      if (doc >= 31 && !(trayDone[i] ?? false)) return i;
    }
    return totalRounds + 1;
  }

  /// A round is locked when the previous round is not fully cleared.
  /// DOC ≤ 30: cleared = feed done.
  /// DOC ≥ 31: cleared = feed done AND tray logged.
  bool _isLocked(int doc, int round, Map<int, bool> feedDone,
      Map<int, bool> trayDone) {
    if (round <= 1) return false;
    final prev = round - 1;
    final prevFeedDone = feedDone[prev] ?? false;
    if (!prevFeedDone) return true;
    // Fix #4: tray mandatory-block only activates in smart mode (DOC ≥ 31).
    if (doc >= 31 && !(trayDone[prev] ?? false)) return true;
    return false;
  }

List<SupplementItem> _getPlannedFeedSupplements(
      List<Supplement> supplements, String feedingTime, double feedQty) {
    final items = <SupplementItem>[];
    for (final supplement in supplements) {
      if (supplement.type != SupplementType.feedMix) {
        continue;
      }
      if (supplement.isPaused || !supplement.feedingTimes.contains(feedingTime)) {
        continue;
      }
      items.addAll(supplement.calculateDosage(feedQty));
    }
    return items;
  }

  List<SupplementItem> _getAppliedFeedSupplements(
      int round, List<SupplementLog> logs) {
    final items = <SupplementItem>[];
    final roundLogs = logs
        .where((log) =>
            log.supplementType == SupplementType.feedMix &&
            log.feedRound == round)
        .toList();
    for (final log in roundLogs) {
      for (final item in log.appliedItems) {
        items.add(
          SupplementItem(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            type: 'feed',
          ),
        );
      }
    }
    return items;
  }

  bool _logFeedSupplementApplication({
    required String pondId,
    required String pondName,
    required int round,
    required double feedQty,
    required List<Supplement> activePlansToday,
  }) {
    if (feedQty <= 0) {
      return false;
    }
    final alreadyLogged = ref.read(supplementLogProvider.notifier).hasFeedLogForRoundOnDate(
          pondId: pondId,
          round: round,
          date: DateTime.now(),
        );
    if (alreadyLogged) {
      return true;
    }

    final roundKey = "R$round";
    final matchingPlans = activePlansToday
        .where((plan) =>
            plan.type == SupplementType.feedMix &&
            !plan.isPaused &&
            plan.feedingTimes.contains(roundKey))
        .toList();
    if (matchingPlans.isEmpty) {
      return false;
    }

    var loggedAny = false;
    for (final plan in matchingPlans) {
      final appliedItems = plan.calculateAppliedItems(feedKg: feedQty);
      if (appliedItems.isEmpty) {
        continue;
      }
      loggedAny = true;
      ref.read(supplementLogProvider.notifier).logApplication(
            supplementId: plan.id,
            pondId: pondId,
            pondName: pondName,
            items: appliedItems,
            supplementName: plan.goal != null ? plan.name : plan.name,
            supplementType: SupplementType.feedMix,
            feedRound: round,
            inputValue: feedQty,
            inputUnit: 'kg',
          );
    }
    return loggedAny;
  }

  DateTime _waterPlanScheduleForDay(Supplement plan, DateTime day) {
    final baseDate = plan.date ?? day;
    final dateOnly = DateTime(day.year, day.month, day.day);
    final timeValue = plan.effectiveWaterTime ?? '';
    try {
      final parts = timeValue.split(':');
      if (parts.length == 2) {
        return DateTime(
          dateOnly.year,
          dateOnly.month,
          dateOnly.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Time parse failed for "$timeValue": $e');
    }
    return DateTime(dateOnly.year, dateOnly.month, dateOnly.day, baseDate.hour, baseDate.minute);
  }

  String _formatWaterTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  bool _logWaterSupplementApplication({
    required String pondId,
    required String pondName,
    required double pondArea,
    required Supplement plan,
    required DateTime scheduledAt,
  }) {
    if (pondArea <= 0) {
      return false;
    }
    final alreadyLogged =
        ref.read(supplementLogProvider.notifier).hasWaterLogForSupplementOnDate(
              pondId: pondId,
              supplementId: plan.id,
              date: scheduledAt,
            );
    if (alreadyLogged) {
      return true;
    }

    final appliedItems = plan.calculateAppliedItems(pondArea: pondArea);
    if (appliedItems.isEmpty) {
      return false;
    }

    ref.read(supplementLogProvider.notifier).logApplication(
          supplementId: plan.id,
          pondId: pondId,
          pondName: pondName,
          items: appliedItems,
          supplementName: plan.name,
          scheduledTime: _formatWaterTime(scheduledAt),
          supplementType: SupplementType.waterMix,
          inputValue: pondArea,
          inputUnit: 'acre',
          scheduledAt: scheduledAt,
        );
    return true;
  }

  /// Returns feed round display data for active rounds only (qty > 0).
  /// DB always has 4 rows — we show only rounds where planned_amount > 0.
  /// Time labels come from getFeedConfig using the round index.
  List<Map<String, dynamic>> _getFeedRounds(
      int doc, Map<int, double> roundFeedAmounts, [Pond? pond]) {
    final config = getFeedConfig(doc);

    if (roundFeedAmounts.isEmpty) {
      // No DB data yet — show 4 rounds by default
      const defaultActive = 4;
      return List.generate(defaultActive, (i) => {
        'round': i + 1,
        'time': config.timingsDisplay[i],
        'key': 'R${i + 1}',
      });
    }

    // Show only rounds with qty > 0 and a valid scheduled time
    final activeRounds = (roundFeedAmounts.keys.toList()..sort())
        .where((r) => (roundFeedAmounts[r] ?? 0.0) > 0)
        .toList();

    final result = <Map<String, dynamic>>[];
    for (final r in activeRounds) {
      final idx = r - 1;
      if (idx < 0 || idx >= config.timingsDisplay.length) continue;
      final time = config.timingsDisplay[idx];
      if (time.startsWith('--')) continue; // skip rounds with no scheduled time for this DOC
      result.add({'round': r, 'time': time, 'key': 'R$r'});
    }
    return result;
  }

  void openTray(int round, bool isLocked) async {
    if (isLocked) {
      return;
    }
    final selectedPond = ref.read(pondDashboardProvider).selectedPond;
    final doc = ref.read(docProvider(selectedPond));

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrayLogScreen(
          pondId: selectedPond,
          doc: doc,
          round: round,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      ref.read(pondDashboardProvider.notifier).logTray(round);
    }
  }

  void _showAnchorFeedDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Current Feed Amount',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your pond has crossed DOC 30. Enter how much feed (kg) you are currently giving per day so we can adjust based on tray response.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Feed amount (kg per day)',
                hintText: 'e.g. 4.0',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                ref.read(pondDashboardProvider.notifier).updateAnchorFeed(val);
                Navigator.pop(dialogCtx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddFarmDialog() {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('add_new_farm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Farm Name",
                hintText: "e.g. Sri Rama Farm",
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.hBase,
            TextField(
              controller: locCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Location",
                hintText: "e.g. Nellore",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final createdLabel = AppLocalizations.of(context).t('farm_created');
                try {
                  final farmService = FarmService();
                  await farmService.createFarm(
                    name: nameCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    farmType: 'Semi-Intensive',
                  );
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(content: Text(createdLabel)));
                    navigator.pop();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context).t('create_farm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final selectedPond = dashboardState.selectedPond;
    final today = ref.watch(todayProvider);
    final oneWeekAgo = ref.watch(oneWeekAgoProvider);

    // Notify user when feed plan was silently regenerated (auto-recovery)
    ref.listen<PondDashboardState>(pondDashboardProvider, (previous, next) {
      if (next.feedAutoRecovered && !(previous?.feedAutoRecovered ?? false)) {
        ref.read(pondDashboardProvider.notifier).clearAutoRecoveredFlag();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Feed plan was missing and has been regenerated automatically.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      // TASK 2: Prompt for anchor feed on first entry into smart phase (DOC >= 31).
      if (next.needsAnchorFeedInput && !(previous?.needsAnchorFeedInput ?? false)) {
        ref.read(pondDashboardProvider.notifier).clearNeedsAnchorFeedInput();
        if (mounted) {
          _showAnchorFeedDialog(context);
        }
      }

      // Warn farmer when a tray log failed to save to the server.
      // The current session is unaffected, but if the app restarts before
      // connectivity is restored the round will be locked again.
      if (next.trayPersistFailed && !(previous?.trayPersistFailed ?? false)) {
        ref.read(pondDashboardProvider.notifier).clearTrayPersistFailedFlag();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tray log could not be saved. Please re-log tray if you restart the app.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFFB45309),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    });

    // Safe argument handling — provider is the single source of truth for feed data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments as String?;
      if (args != null && args.isNotEmpty && args != selectedPond) {
        ref.read(pondDashboardProvider.notifier).selectPond(args);
      } else if (selectedPond.isEmpty) {
        // Auto-select first pond (e.g. after first pond creation redirect)
        final ponds = ref.read(farmProvider).currentFarm?.ponds ?? [];
        if (ponds.isNotEmpty) {
          ref.read(pondDashboardProvider.notifier).selectPond(ponds.first.id);
        }
      } else if (selectedPond.isNotEmpty &&
          dashboardState.roundFeedAmounts.isEmpty &&
          !dashboardState.isFeedLoading) {
        ref.read(pondDashboardProvider.notifier).loadTodayFeed(selectedPond);
      }
    });

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    final currentPond = ponds.isNotEmpty
        ? ponds.firstWhere(
            (p) => p.id == selectedPond,
            orElse: () => ponds.first,
          )
        : null;  // ✅ CLEANED: Return null if no ponds - let UI handle gracefully

    /// ⚠️ HANDLED: Check for no farms first, then no ponds
    if (currentPond == null) {
      // Case 1: No farms exist - show message without CTA
      if (farmState.farms.isEmpty) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).t('ponds')),
            centerTitle: true,
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: LanguageSwitcher(),
              ),
            ],
          ),
          bottomNavigationBar: const AppBottomBar(currentIndex: 1),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.landscape_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).t('no_farms'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).t('create_farm_first'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Case 2: Farm exists but no ponds - show Add First Pond button
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('ponds')),
          centerTitle: true,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: LanguageSwitcher(),
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 1),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).t('no_ponds'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).t('create_pond_to_start'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addPond);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context).t('add_first_pond')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCompleted = currentPond.status == PondStatus.completed;

    final allSupplements = ref.watch(supplementProvider);
    final activePlansToday = allSupplements.where((plan) {
      return plan.appliesToPond(selectedPond) &&
          plan.isActiveOnDate(DateTime.now()) &&
          !plan.isPaused;
    }).toList();

    /// ✅ TRAY DATA
    final trayLogs = ref.watch(trayProvider(selectedPond));

    final Map<int, TrayLog> todayTrayMap = {
      for (var log in trayLogs)
        if (log.time.year == today.year &&
            log.time.month == today.month &&
            log.time.day == today.day)
          log.round: log
    };
    final Map<int, bool> trayDone =
        todayTrayMap.map((key, value) => MapEntry(key, true));

    /// EMPTY STATE
    if (currentFarm != null && currentFarm.ponds.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        bottomNavigationBar: const AppBottomBar(currentIndex: 1),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 64, color: Colors.grey),
                AppSpacing.hBase,
                Text("${AppLocalizations.of(context).t('no_ponds')} — ${currentFarm.name}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                AppSpacing.hM,
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addPond);
                  },
                  child: Text(AppLocalizations.of(context).t('add_first_pond')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentDoc = ref.watch(docProvider(selectedPond));

    /// ✅ CURRENT STATS
    final history = ref.watch(feedHistoryProvider)[selectedPond] ?? [];
    final totalFeedToDate = history.isNotEmpty ? history.first.cumulative : 0.0;

    final growthLogs = ref.watch(growthProvider(selectedPond));

    double pondFcr = 0.0;
    double currentAbw = 0.0;

    if (growthLogs.isNotEmpty) {
      final lastLog = growthLogs.first;
      currentAbw = lastLog.abw;
      double survival = 1.0;
      if (currentDoc > 60) {
        survival = 0.90;
      } else if (currentDoc > 30) {
        survival = 0.95;
      }

      final biomass =
          (currentPond.seedCount * survival * lastLog.averageBodyWeight) / 1000;
      if (biomass > 0) {
        pondFcr = totalFeedToDate / biomass;
      }
    }

    /// ✅ PREVIOUS WEEK STATS
    double prevFcr = 0.0;
    final prevHistoryLog = history.firstWhere(
      (h) => h.date.isBefore(oneWeekAgo),
      orElse: () => FeedHistoryLog(
          date: DateTime(2000),
          doc: 0,
          rounds: [],
          trayStatuses: [],
          expected: 0,
          cumulative: 0),
    );

    // Get growth log from approx 7 days ago
    final prevGrowthLog = growthLogs.isEmpty
        ? null
        : growthLogs.firstWhere(
            (l) => l.date.isBefore(oneWeekAgo),
            orElse: () =>
                growthLogs.last, // Fallback to oldest log if no weekly history
          );

    double prevAbw = 0.0;
    if (prevHistoryLog.doc > 0 && prevGrowthLog != null) {
      prevAbw = prevGrowthLog.abw;
      double prevSurvival = 1.0;
      if (prevGrowthLog.doc > 60) {
        prevSurvival = 0.90;
      } else if (prevGrowthLog.doc > 30) {
        prevSurvival = 0.95;
      }

      final prevBiomass = (currentPond.seedCount *
              prevSurvival *
              prevGrowthLog.averageBodyWeight) /
          1000;
      if (prevBiomass > 0) {
        prevFcr = prevHistoryLog.cumulative / prevBiomass;
      }
    } else if (prevGrowthLog != null) {
      // Fallback for ABW if no history log found but growth log exists
      prevAbw = prevGrowthLog.abw;
    }

    // Trends calculated for future use (FCR decrease = good, ABW increase = good)
    // ignore: unused_local_variable
    final double fcrTrend = (pondFcr > 0 && prevFcr > 0) ? (pondFcr - prevFcr) : 0;
    // ignore: unused_local_variable
    final double abwTrend = (currentAbw > 0 && prevAbw > 0) ? (currentAbw - prevAbw) : 0;

    final supplementLogs = ref.watch(supplementLogProvider);
    final now = DateTime.now();
    final todaySupplementLogs = supplementLogs
        .where((l) =>
            l.pondId == selectedPond &&
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day)
        .toList();

    // Both planned and consumed come from provider state (single source of truth)
    final double plannedFeed = dashboardState.roundFeedAmounts.values
        .fold(0.0, (sum, v) => sum + v);

    final double consumedFeed = dashboardState.roundFeedStatus.entries
        .where((e) => e.value == 'completed')
        .fold(0.0, (sum, e) => sum + (dashboardState.roundFeedAmounts[e.key] ?? 0.0));

    // Smart Feed auto-enables at DOC ≥ 30 (smart_feeding = doc >= 30).
    // The DB flag `isSmartFeedEnabled` is the farmer's manual preference; even if
    // never toggled, Smart Mode activates at DOC 30 because the round lock and
    // SmartFeedEngine both trigger on doc >= 30.
    final isSmartFeedEnabled = currentPond.isSmartFeedEnabled || (currentDoc >= 30);

    // ── DOC-adaptive mode ────────────────────────────────────────────────────
    final String mode;
    if (currentDoc == 1) {
      mode = 'onboarding';
    } else if (currentDoc < 30) {
      mode = 'growth';
    } else {
      mode = 'smart';
    }

    // ── Feeding streak (consecutive days with at least one completed round) ──
    int streak = 0;
    {
      DateTime expected = DateTime(today.year, today.month, today.day);
      for (final log in history) {
        final logDay =
            DateTime(log.date.year, log.date.month, log.date.day);
        if (logDay == expected && log.total > 0) {
          streak++;
          expected = expected.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // ── Pond Value ────────────────────────────────────────────────────────────
    final double survivalFraction = _estimatedSurvivalRate(currentDoc) / 100.0;
    String? traySignal;
    {
      final recentTray = trayLogs
          .where((l) => !l.isSkipped && l.trays.isNotEmpty)
          .firstOrNull;
      if (recentTray != null) {
        final full = recentTray.trays.where((t) => t == TrayStatus.full).length;
        final empty =
            recentTray.trays.where((t) => t == TrayStatus.empty).length;
        final total = recentTray.trays.length;
        if (full > total / 2) {
          traySignal = 'full';
        } else if (empty > total / 2) traySignal = 'empty';
        else traySignal = 'partial';
      }
    }
    final bool hasTrayData =
        trayLogs.any((l) => !l.isSkipped && l.trays.isNotEmpty);
    final pondValue = PondValueEngine.calculate(
      stockCount: currentPond.seedCount,
      avgWeightG: currentAbw,
      survivalRate: survivalFraction,
      doc: currentDoc,
      fedToday: consumedFeed > 0,
      missedFeed: consumedFeed == 0 && currentDoc > 1,
      traySignal: traySignal,
      feedingConsistent: streak >= 3,
      hasTrayData: hasTrayData,
      missingLogs: consumedFeed == 0 && currentDoc > 1,
    );

    // ── Pending rounds ────────────────────────────────────────────────────────
    final List<int> pendingRounds = dashboardState.roundFeedStatus.entries
        .where((e) => e.value != 'completed')
        .map((e) => e.key)
        .toList()
      ..sort();

    final int completedRoundsCount = dashboardState.roundFeedStatus.values
        .where((s) => s == 'completed')
        .length;

    // SSOT for live countdown — passed directly to FeedHeroCard.
    final DateTime? nextFeedAt = FeedStatusEngine.nextFeedAt(
      now: DateTime.now(),
      lastFeedTime: dashboardState.lastFeedTime,
      doc: currentDoc,
      feedsDoneToday: completedRoundsCount,
    );

    // ── HomeViewModel — single source of truth for all home sections ─────────
    final vm = HomeBuilder.build(
      doc:             currentDoc,
      feedsDone:       completedRoundsCount,
      maxFeeds:        currentDoc <= 7 ? 2 : 4,
      lastFeedTime:    dashboardState.lastFeedTime,
      roundFeedStatus: dashboardState.roundFeedStatus,
      trayDone:        trayDone,
      consumedFeed:    consumedFeed,
      plannedFeed:     plannedFeed,
      feedHistory:     history,
      trayLogs:        trayLogs,
      growthLogs:      growthLogs,
      currentAbw:      currentAbw,
      pondFcr:         pondFcr,
      streak:          streak,
      seedCount:       currentPond.seedCount,
    );

    // ── Savings vs plan for completed rounds ──────────────────────────────────
    double? heroSavedToday;
    if (completedRoundsCount >= 1 && consumedFeed > 0) {
      final double baseline = dashboardState.roundFeedStatus.entries
          .where((e) => e.value == 'completed')
          .fold(0.0, (sum, e) => sum + (dashboardState.roundFeedAmounts[e.key] ?? 0.0));
      if (baseline > 0) {
        final diff = baseline - consumedFeed;
        if (diff > 0.001) heroSavedToday = diff * kFeedCostPerKg;
      }
    }

    // ── Current (hero) round data ─────────────────────────────────────────────
    final int? heroRound = pendingRounds.isNotEmpty ? pendingRounds.first : null;
    String heroTime = '';
    double heroQty = 0;
    List<String> heroSupplements = [];
    if (heroRound != null) {
      final feedRoundsData =
          _getFeedRounds(currentDoc, dashboardState.roundFeedAmounts, currentPond);
      final roundData = feedRoundsData.firstWhere(
        (r) => r['round'] == heroRound,
        orElse: () => <String, dynamic>{},
      );
      heroTime = (roundData['time'] as String?) ?? '';
      final heroTimeKey = (roundData['key'] as String?) ?? 'R$heroRound';
      heroQty = dashboardState.roundFeedAmounts[heroRound] ?? 0;
      heroSupplements = _getPlannedFeedSupplements(activePlansToday, heroTimeKey, heroQty)
          .map((s) => '${s.name.toUpperCase()} ${s.quantity.toStringAsFixed(1)}${s.unit}')
          .toList();
    }

    // ── Next feed time tomorrow (for AllDone card) ────────────────────────────
    String? nextRoundTime;
    {
      final config = getFeedConfig(currentDoc + 1);
      if (config.timingsDisplay.isNotEmpty) {
        final t = config.timingsDisplay[0];
        if (!t.startsWith('--')) nextRoundTime = t;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER — Language switcher (left) + ADD POND button (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const LanguageSwitcherDark(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.addPond),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context).t('add_pond_btn'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// POND TABS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...ponds.map((pond) {
                      bool isSelected = pond.id == selectedPond;

                      final hasFeed =
                          (ref.watch(feedHistoryProvider)[pond.id] ?? []).isNotEmpty;
                      final hasHarvest =
                          ref.watch(harvestProvider(pond.id)).isNotEmpty;

                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(pondDashboardProvider.notifier)
                              .selectPond(pond.id);
                        },
                        onLongPress: () {
                          if (hasFeed || hasHarvest) {
                            return;
                          }

                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: Text(AppLocalizations.of(context).t('delete_pond')),
                                content: Text(
                                    "Delete '${pond.name}'? This pond has no feed or harvest records. It will be permanently removed."),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text(AppLocalizations.of(context).t('cancel')),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: Text(AppLocalizations.of(context).t('delete')),
                                    onPressed: () async {
                                      if (currentFarm != null) {
                                        try {
                                          await ref
                                              .read(farmProvider.notifier)
                                              .deletePond(
                                                  currentFarm.id, pond.id);
                                        } catch (e) {
                                          if (dialogContext.mounted) {
                                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                              const SnackBar(content: Text("Failed to delete pond. Please try again.")),
                                            );
                                          }
                                          return;
                                        }
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.only(right: AppSpacing.s + 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.base,
                              vertical: AppSpacing.s + 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade200,
                            borderRadius: AppRadius.rl,
                          ),
                          child: Text(
                            pond.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }),

                  ],
                ),
              ),

              AppSpacing.hBase,

              /// POND VALUE CARD — replaces Species/DOC/Survival stats strip
              /// 5-tap still opens the Feed Engine Debug Dashboard
              GestureDetector(
                onTap: () => _onDebugTap(selectedPond, currentPond.name),
                child: _buildValueCard(
                  mode: mode,
                  pondValue: pondValue,
                  doc: currentDoc,
                  streak: streak,
                  seedCount: currentPond.seedCount,
                  survivalRate: survivalFraction,
                ),
              ),

              const SizedBox(height: 12),

              // ── ALERT STRIP — highest priority status (not shown when all done) ──
              if (!isCompleted) ...[
                if (vm.alert.type != AlertType.allDone) ...[
                  AlertStrip(data: vm.alert),
                  const SizedBox(height: 10),
                ],

                // ── KPI ROW — Feed Today · ABW · FCR ──────────────────────────
                KpiRow(data: vm.kpis),
                const SizedBox(height: 12),

                // ── GAP 3 — Daily Performance Card (end-of-day intelligence) ──
                if (completedRoundsCount >= (currentDoc <= 7 ? 2 : 4)) ...[
                  _DailyPerformanceCard(
                    fcr: pondFcr,
                    currentAbw: currentAbw,
                    expectedAbw: vm.growth.expectedAbw,
                    completedRounds: completedRoundsCount,
                    totalRounds: currentDoc <= 7 ? 2 : 4,
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 12),

              if (isCompleted)
                _buildCompletedDashboard(context, ref, currentPond)
              else ...[

                if (currentDoc > 120) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: AppRadius.rs,
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).t('extended_culture'),
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                /// ── DAILY TASKS TIMELINE ─────────────────────────────────────
                if (dashboardState.isFeedLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (dashboardState.roundFeedAmounts.isEmpty && currentDoc < 30)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).t('no_feed_plan'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Start feeding to see insights',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      // ── Active rounds (current + upcoming) + water supplements ──
                      ..._buildTimeline(
                        today: today,
                        currentDoc: currentDoc,
                        pondName: currentPond.name,
                        pondArea: currentPond.area,
                        todayTrayMap: todayTrayMap,
                        dashboardState: dashboardState,
                        trayDone: trayDone,
                        activePlansToday: activePlansToday,
                        todaySupplementLogs: todaySupplementLogs,
                        selectedPond: selectedPond,
                        smartFeedOutput: null,
                        currentPond: currentPond,
                        isSmartFeedEnabled: isSmartFeedEnabled,
                        valueDelta: pondValue.delta,
                        showDoneRoundsOnly: false,
                        nextFeedAt: nextFeedAt,
                        // T7/T8/T9/T10/T11/T13 — intelligence + safety layer
                        insight: vm.insight?.message,
                        completedRounds: completedRoundsCount,
                        totalRounds: currentDoc <= 7 ? 2 : 4,
                        feedMode: feedModeFromDoc(currentDoc),
                        lastFeedbackRound: _lastFeedbackRound,
                        onFeedbackSubmit: (round, isAccurate) {
                          setState(() => _lastFeedbackRound = -1);
                          // TODO: persist FeedFeedback to DB
                          debugPrint('[FeedFeedback] R$round accurate=$isAccurate doc=$currentDoc pond=$selectedPond');
                        },
                      ),

                      const SizedBox(height: 12),
                      GestureDetector(
                          onTap: () => setState(() => _completedRoundsExpanded = !_completedRoundsExpanded),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _completedRoundsExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                  size: 18,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _completedRoundsExpanded ? 'Hide Completed Rounds' : 'Completed Rounds',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${dashboardState.roundFeedStatus.values.where((s) => s == 'completed').length} done',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_completedRoundsExpanded) ...[
                          const SizedBox(height: 8),
                          ..._buildTimeline(
                            today: today,
                            currentDoc: currentDoc,
                            pondName: currentPond.name,
                            pondArea: currentPond.area,
                            todayTrayMap: todayTrayMap,
                            dashboardState: dashboardState,
                            trayDone: trayDone,
                            activePlansToday: activePlansToday,
                            todaySupplementLogs: todaySupplementLogs,
                            selectedPond: selectedPond,
                            smartFeedOutput: null,
                            currentPond: currentPond,
                            isSmartFeedEnabled: isSmartFeedEnabled,
                            valueDelta: pondValue.delta,
                            showDoneRoundsOnly: true,
                          ),
                        ],
                      ],
                      ),
                const SizedBox(height: 16),

                /// ── QUICK ACTIONS (Feed/Supp + Tank Ops) ─────────────────────
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('feed_schedule'),
                      icon: Icons.calendar_month_rounded,
                      iconColor: AppColors.primary,
                      onTap: () {
                        if (_showFeedScheduleTip) {
                          _pulseController.stop();
                          setState(() => _showFeedScheduleTip = false);
                        }
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FeedScheduleScreen(pondId: selectedPond)));
                      },
                    ),
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('supplement_mix'),
                      icon: Icons.science_rounded,
                      iconColor: Colors.deepPurple,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => SupplementMixScreen(pondId: selectedPond))),
                    ),
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('sampling'),
                      icon: Icons.texture,
                      iconColor: Colors.purple,
                      badge: _samplingBadge(currentDoc),
                      badgeColor: const Color(0xFFDC2626),
                      onTap: () {
                        if (isCompleted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context).t('sampling_locked'))));
                        } else {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => SamplingScreen(pondId: selectedPond)));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('water_test'),
                      icon: Icons.water_drop_rounded,
                      iconColor: AppColors.primary,
                      badge: "Today",
                      badgeColor: const Color(0xFF16A34A),
                      onTap: () {
                        if (isCompleted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.of(context).t('water_test_locked'))));
                        } else {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => WaterTestScreen(pondId: selectedPond)));
                        }
                      },
                    ),
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('harvest'),
                      icon: Icons.agriculture_rounded,
                      iconColor: AppColors.warning,
                      badge: "DOC $currentDoc",
                      badgeColor: const Color(0xFF64748B),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => isCompleted
                                  ? HarvestSummaryScreen(pondId: selectedPond)
                                  : HarvestScreen(pondId: selectedPond))),
                    ),
                    _TankOpButton(
                      label: AppLocalizations.of(context).t('history'),
                      icon: Icons.history_rounded,
                      iconColor: Colors.teal,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FeedHistoryScreen(pondId: selectedPond))),
                    ),
                  ],
                ),
              // ── INTELLIGENCE LAYER (below quick actions) ───────────────────
              if (!isCompleted) ...[
                const SizedBox(height: 20),

                // Feed vs Ideal trend (7-day sparkline)
                FeedTrendCard(data: vm.trend),

                const SizedBox(height: 10),

                // Removed: Growth status, Waste insight, Activity timeline, Smart insight
              ],
              // ── END INTELLIGENCE LAYER ──────────────────────────────────────
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeline({
    required DateTime today,
    required int currentDoc,
    required String pondName,
    required double pondArea,
    required Map<int, TrayLog> todayTrayMap,
    required PondDashboardState dashboardState,
    required Map<int, bool> trayDone,
    required List<Supplement> activePlansToday,
    required List<SupplementLog> todaySupplementLogs,
    required String selectedPond,
    required SmartFeedOutput? smartFeedOutput,
    required Pond? currentPond,
    required bool isSmartFeedEnabled,
    required double valueDelta,
    bool showDoneRoundsOnly = false,
    DateTime? nextFeedAt,
    // T7/T8/T9/T10/T11/T13 — intelligence + safety layer params
    String? insight,
    int completedRounds = 0,
    int totalRounds = 0,
    double? confidenceScore,
    FeedMode feedMode = FeedMode.guided,
    int lastFeedbackRound = -1,
    void Function(int round, bool isAccurate)? onFeedbackSubmit,
  }) {
    final feedRoundsData = _getFeedRounds(currentDoc, dashboardState.roundFeedAmounts, currentPond);
    final List<Map<String, dynamic>> timelineItems = [];


    // Add Feed Rounds
    for (var data in feedRoundsData) {
      final timeStr = data['time'] as String;
      DateTime sortTime;
      try {
        final dt = DateFormat("hh:mm a").parse(timeStr);
        sortTime =
            DateTime(today.year, today.month, today.day, dt.hour, dt.minute);
      } catch (_) {
        sortTime = DateTime(today.year, today.month, today.day, 23, 59);
      }
      timelineItems.add({...data, 'type': 'feed', 'sortTime': sortTime});
    }

    final waterPlans = activePlansToday
        .where((plan) => plan.type == SupplementType.waterMix)
        .toList();

    for (final plan in waterPlans) {
      final existingLogs = todaySupplementLogs
          .where((log) =>
              log.supplementType == SupplementType.waterMix &&
              log.supplementId == plan.id)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final scheduledAt = _waterPlanScheduleForDay(plan, today);
      final latestLog = existingLogs.isNotEmpty ? existingLogs.first : null;

      timelineItems.add({
        'type': 'water',
        'plan': plan,
        'log': latestLog,
        'time': latestLog?.scheduledTime ?? _formatWaterTime(scheduledAt),
        'sortTime': latestLog?.scheduledAt ?? scheduledAt,
      });
    }

    for (final log in todaySupplementLogs) {
      if (log.supplementType != SupplementType.waterMix) {
        continue;
      }
      final alreadyRepresented = waterPlans.any((plan) => plan.id == log.supplementId);
      if (alreadyRepresented) {
        continue;
      }
      final sortTime = log.timestamp;
      timelineItems.add({
        'type': 'water',
        'log': log,
        'time': DateFormat("hh:mm a").format(sortTime),
        'sortTime': sortTime,
      });
    }

    timelineItems.sort((a, b) =>
        (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime));

    return timelineItems.map<Widget?>((itemData) {
      final bool isFeed = itemData['type'] == 'feed';

      // Filter by mode: showDoneRoundsOnly shows only done feed rounds,
      // otherwise shows active rounds + water supplements (skips done feed)
      if (!isFeed && showDoneRoundsOnly) return null;

      Widget card;

      if (isFeed) {
        // ── Feed round card (unified for all DOCs) ─────────────────────
        final Map<int, bool> feedDoneMap = {
          for (final e in dashboardState.roundFeedStatus.entries)
            e.key: e.value == 'completed',
        };
        final round = itemData['round'] as int;
        final time = itemData['time'] as String;
        final timeKey = itemData['key'] as String;
        final double qty = dashboardState.roundFeedAmounts[round] ?? 0.0;
        final thisRoundLog = todayTrayMap[round];

        final roundState = _getSimpleRoundState(
          doc: currentDoc,
          round: round,
          totalRounds: dashboardState.roundFeedAmounts.isNotEmpty
              ? dashboardState.roundFeedAmounts.values.where((v) => v > 0).length
              : (currentDoc <= 7 ? 2 : 4),
          feedDone: feedDoneMap,
          trayDone: trayDone,
        );

        final bool isDone = roundState['isDone'] as bool;
        final bool isCurrent = roundState['isCurrent'] as bool;
        final bool isTrayLogged = roundState['isTrayLogged'] as bool;
        // A tray log exists but it was auto-skipped (farmer moved on without logging)
        final bool isTraySkipped = isTrayLogged && (todayTrayMap[round]?.isSkipped ?? false);
        // DOC 15–29: tray is optional — show the button but don't block progression.
        // DOC ≥ 30:  tray is mandatory — handled by _isLocked/_getCurrentRound.
        // isPendingTray = tray not yet handled at all (neither logged nor skipped)
        final bool isPendingTray = isDone && currentDoc >= 15 && !isTrayLogged;

        // Filter: skip non-done rounds in done-only mode.
        if (showDoneRoundsOnly && !isDone) return null;
        // In active mode: only skip done rounds that have NO pending tray action.
        // If tray is pending or skipped, keep the card visible so farmer can log it.
        if (!showDoneRoundsOnly && isDone && !isPendingTray && !isTraySkipped) return null;

        final FeedRoundState cardState = isDone
            ? FeedRoundState.done
            : isCurrent
                ? FeedRoundState.current
                : FeedRoundState.upcoming;

        // First upcoming round after current = "NEXT"
        final int currentRound = feedDoneMap.entries
            .where((e) => !e.value)
            .map((e) => e.key)
            .fold<int>(0, (m, r) => m == 0 ? r : (r < m ? r : m));
        final bool isNext = cardState == FeedRoundState.upcoming && round == currentRound + 1;

        // Supplements: applied for done rounds, planned for others
        final appliedSupplements = _getAppliedFeedSupplements(round, todaySupplementLogs);
        final List<String> supplements = appliedSupplements.isNotEmpty
            ? appliedSupplements
                .map((s) => "${s.name.toUpperCase()} ${s.quantity.toStringAsFixed(1)}${s.unit}")
                .toList()
            : _getPlannedFeedSupplements(activePlansToday, timeKey, qty)
                .map((s) => "${s.name.toUpperCase()} ${s.quantity.toStringAsFixed(1)}${s.unit}")
                .toList();

        final double finalFeedKg = dashboardState.roundFinalFeedAmounts[round] ?? qty;
        final bool isManuallyEdited = dashboardState.roundIsManuallyEdited[round] ?? false;

        // T10 — Safety clamp: cap recommendation to ±20/25% of last feed
        final double lastKg = round > 1 ? (dashboardState.roundFeedAmounts[round - 1] ?? 0.0) : 0.0;
        final double safeQty = (lastKg > 0 && qty > 0)
            ? qty.clamp(lastKg * 0.75, lastKg * 1.2)
            : qty;
        final bool isSafetyClamped = lastKg > 0 && (safeQty - qty).abs() > 0.01;

        card = FeedTimelineCard(
          round: round,
          time: time,
          recommendedFeedKg: safeQty,
          finalFeedKg: finalFeedKg,
          isManuallyEdited: isManuallyEdited,
          state: cardState,
          isPendingTray: isPendingTray,
          isTraySkipped: isTraySkipped,
          trayStatuses: thisRoundLog?.isSkipped == true ? null : thisRoundLog?.trays,
          supplements: supplements,
          isSmartFeed: isSmartFeedEnabled,
          lastFeedKg: lastKg > 0 ? lastKg : null,
          leftoverPercent: thisRoundLog?.leftoverPercent,
          correctionPercent: 0, // TODO: calculate
          // Hero timer SSOT — card owns the live countdown internally.
          // Only supplied for the current (active) round; null for done/upcoming.
          nextFeedAt: isCurrent ? nextFeedAt : null,
          onEdit: isCurrent
              ? (double newQty) {
                  ref.read(pondDashboardProvider.notifier).editRoundAmount(
                        round,
                        newQty,
                        persistToPlan: currentDoc >= 30,
                      );
                }
              : null,
          // MARK AS FED: always available on the current round, for all DOCs
          onMarkDone: isCurrent
              ? () {
                  // T13 — show feedback prompt on the done card after this round
                  setState(() => _lastFeedbackRound = round);
                  final actualQty = finalFeedKg;
                  if (actualQty > 0) {
                    _logFeedSupplementApplication(
                      pondId: selectedPond,
                      pondName: pondName,
                      round: round,
                      feedQty: actualQty,
                      activePlansToday: activePlansToday,
                    );
                  }
                  // markFeedDone updates status in DB → loadTodayFeed → Riverpod rebuild
                  // Card then transitions: current → done (+ LOG TRAY if DOC >= 15)
                  ref.read(pondDashboardProvider.notifier).markFeedDone(
                        round,
                        actualQty: actualQty,
                      );
                  // V2-01: ₹ delta snackbar — closes dopamine loop after every feed.
                  // Shows "+₹120 added to pond value" immediately after marking done.
                  final completedAfter = round;
                  final motivationMsg = _feedMotivationMessage(completedAfter);
                  final valueLabel = _formatCurrency(valueDelta);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      valueDelta >= 1
                          ? '$motivationMsg  •  +$valueLabel added to pond value'
                          : motivationMsg,
                    ),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ));
                }
              : null,
          // LOG TRAY: pending = never logged, skipped = auto-skipped (show "Update Now")
          onLogTray: (isPendingTray || isTraySkipped) ? () => openTray(round, false) : null,
          isNext: isNext,
          // T7/T8/T9/T10/T11/T13 — intelligence + safety layer
          insight: isCurrent ? insight : null,
          completedRounds: completedRounds,
          totalRounds: totalRounds,
          confidenceScore: isCurrent ? confidenceScore : null,
          isSafetyClamped: isCurrent && isSafetyClamped,
          feedMode: feedMode,
          showFeedbackPrompt: isDone && round == lastFeedbackRound,
          onFeedback: isDone ? (bool isAccurate) => onFeedbackSubmit?.call(round, isAccurate) : null,
          decision: isCurrent ? dashboardState.decision : null,
          recommendationInstruction: isCurrent ? dashboardState.recommendation?.instruction : null,
          isCurrent: isCurrent,
          // TASK 8: pass anchor so card can show "Base Feed / Adjusted Feed" split
          anchorFeedKg: (isCurrent && currentDoc >= 31) ? currentPond?.anchorFeed : null,
        );

        // External warning strip removed — FeedTimelineCard now owns the timer
        // and warning UX internally via its 3-state layout (Too Early / Window
        // Open / Overdue). The nextFeedAt DateTime drives all of this.
      } else {
        final log = itemData['log'] as SupplementLog?;
        final plan = itemData['plan'] as Supplement?;
        final isApplied = log != null;

        final scheduledAt = plan != null
            ? _waterPlanScheduleForDay(plan, today)
            : (log?.scheduledAt ?? log?.timestamp ?? today);
        final items = log?.appliedItems ??
            (plan != null ? plan.calculateAppliedItems(pondArea: pondArea) : <CalculatedItem>[]);

        card = _WaterRoundCard(
          time: itemData['time'],
          title: log?.supplementName ?? plan?.name ?? "Water Mix",
          items: items,
          isApplied: isApplied,
          onMarkDone: plan == null || isApplied
              ? null
              : () {
                  if (pondArea <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pond area must be greater than zero"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final didLog = _logWaterSupplementApplication(
                    pondId: dashboardState.selectedPond,
                    pondName: pondName,
                    pondArea: pondArea,
                    plan: plan,
                    scheduledAt: scheduledAt,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        didLog
                            ? "Water supplement marked as applied"
                            : "Unable to apply water supplement",
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
        );
      }

      return card;
    }).whereType<Widget>().toList();
  }

  // ── Estimated survival rate based on DOC ──────────────────────────
  int _estimatedSurvivalRate(int doc) {
    if (doc <= 5) return 99;
    if (doc <= 10) return 98;
    if (doc <= 20) return 95;
    if (doc <= 30) return 92;
    if (doc <= 60) return 88;
    if (doc <= 90) return 84;
    return 80;
  }

  // ── Sampling badge text ───────────────────────────────────────────
  String? _samplingBadge(int doc) {
    // Suggest sampling every 7 days; show "Due in Xd" when approaching
    final daysSinceLast = doc % 7;
    final daysUntilNext = 7 - daysSinceLast;
    if (daysUntilNext <= 2) return "Due in ${daysUntilNext}d";
    return null;
  }

  // ── POND VALUE CARD ────────────────────────────────────────────────────
  // Replaces the Species/DOC/Survival stats strip.
  // Shows harvest value range, daily delta, confidence, DOC badge, streak.
  Widget _buildValueCard({
    required String mode,
    required PondValue pondValue,
    required int doc,
    required int streak,
    required int seedCount,
    required double survivalRate,
  }) {
    final String subtitle;
    switch (mode) {
      case 'onboarding':
        subtitle = 'Expected Harvest Value';
        break;
      case 'growth':
        subtitle = 'Pond Potential';
        break;
      default:
        subtitle = 'Projected Value';
    }

    final minK = (pondValue.min / 1000).toStringAsFixed(0);
    final maxK = (pondValue.max / 1000).toStringAsFixed(0);
    final deltaRs = pondValue.delta.round();
    final deltaLabel = deltaRs >= 1000
        ? '₹${(deltaRs / 1000).toStringAsFixed(1)}K'
        : '₹$deltaRs';

    // Seed count display: 100000 → "1L", 200000 → "2L", else "Xk"
    final String seedLabel;
    if (seedCount >= 100000) {
      seedLabel = '${(seedCount / 100000).toStringAsFixed(seedCount % 100000 == 0 ? 0 : 1)}L';
    } else {
      seedLabel = '${(seedCount / 1000).toStringAsFixed(0)}k';
    }
    final survivalPct = (survivalRate * 100).round();
    final int pricePerKg = FeedEngineConstants.harvestPricePerKg.round();

    // Confidence color thresholds
    final Color confidenceColor;
    if (pondValue.confidence >= 80) {
      confidenceColor = const Color(0xFF16A34A); // green
    } else if (pondValue.confidence >= 60) {
      confidenceColor = const Color(0xFFD97706); // amber
    } else {
      confidenceColor = const Color(0xFFDC2626); // red
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rm,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: subtitle + DOC badge
          Row(
            children: [
              Text(
                subtitle.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DOC $doc',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: DOMINANT value range
          Text(
            '₹${minK}K – ₹${maxK}K',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          // Row 3: delta + confidence on same line
          Row(
            children: [
              Text(
                '+$deltaLabel today ↑',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: confidenceColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${pondValue.confidence}% confidence',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: confidenceColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 4: "Based on" trust line
          Text(
            'Based on: $seedLabel seed • $survivalPct% survival • ₹$pricePerKg/kg',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          // Row 5: streak pill (only when streak > 0)
          if (streak > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 14, color: Color(0xFFEA580C)),
                const SizedBox(width: 4),
                Text(
                  '$streak day feeding streak',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── TODAY DECISION CARD ─────────────────────────────────────────────────
  // T1 + T8 + T9: Decision, money impact, tray-based action
  Widget _buildTodayDecisionCard({
    required int currentDoc,
    required Map<int, TrayLog> todayTrayMap,
    required List<TrayLog> allTrayLogs,
    required Map<int, double> roundFeedAmounts,
    required Map<int, String> roundFeedStatus,
    required double plannedFeed,
    required double consumedFeed,
    required String mode,
  }) {
    // ── mode-based display strings ──────────────────────────────────────
    final String cardTitle;
    switch (mode) {
      case 'onboarding':
        cardTitle = 'Day 1 Growth Plan';
        break;
      case 'growth':
        cardTitle = 'Growth Phase';
        break;
      default: // 'smart'
        cardTitle = 'Smart Feed Decision';
    }

    // T9: Multi-round tray scoring via TrayDecisionEngine.
    // Merges today's tray map and allTrayLogs into a single newest-first list
    // so the engine gets a complete cross-day view of recent rounds.
    final todaySorted = (todayTrayMap.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)))
        .map((e) => e.value)
        .toList();
    // Deduplicate: today's logs take priority; skip any duplicate from allTrayLogs
    final seenKeys = <String>{};
    final dedupedLogs = <TrayLog>[];
    for (final log in [...todaySorted, ...allTrayLogs]) {
      if (seenKeys.add('${log.doc}_${log.round}')) dedupedLogs.add(log);
    }

    final trayDecision = TrayDecisionEngine.evaluate(
      allTrayLogs: dedupedLogs,
      doc: currentDoc,
    );

    final String action = trayDecision.action;
    final String percentage = trayDecision.percentageLabel;
    final String reason = trayDecision.reason;

    // T8: Savings / Loss — only valid after at least one round is completed.
    // baseline = planned amounts for COMPLETED rounds only (NOT the full-day total).
    // consumedFeed < baseline → saved money (under-fed vs plan, smart feed win)
    // consumedFeed > baseline → lost money  (over-fed vs plan, farmer needs correction)
    // consumedFeed == baseline → neutral    → show nothing
    final int completedRounds =
        roundFeedStatus.values.where((s) => s == 'completed').length;
    double? savedToday;
    if (completedRounds >= 1 && consumedFeed > 0) {
      final double baselineFeed = roundFeedStatus.entries
          .where((e) => e.value == 'completed')
          .fold(0.0, (sum, e) => sum + (roundFeedAmounts[e.key] ?? 0.0));
      if (baselineFeed > 0) {
        final double diff = baselineFeed - consumedFeed;
        if (diff > 0.001) {
          savedToday = diff * kFeedCostPerKg;
        }
      }
    }

    final Color actionColor = action == 'INCREASE'
        ? const Color(0xFF16A34A)
        : action == 'REDUCE'
            ? const Color(0xFFDC2626)
            : const Color(0xFF2563EB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: mode title ────────────────────────────────────────
          Text(
            cardTitle.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B5E20),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // ── Action row: badge only for INCREASE/REDUCE; MAINTAIN is
          //    hidden so only the farmer-friendly reason is shown. ─────
          if (action != 'MAINTAIN') ...[
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    '$action$percentage',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: actionColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    reason,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              reason,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
            ),
          ],

          // ── Savings / Loss row ────────────────────────────────────────
          if (savedToday != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Saved Today: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  '₹${savedToday.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  // ── V2-05: NEXT ACTION CARD ──────────────────────────────────────────────
  // Always visible — never shows a blank state. Single clear instruction.
  Widget _buildNextActionCard(String actionText) {
    final bool isDone = actionText.startsWith('✅');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? const Color(0xFF86EFAC) : const Color(0xFF6EE7B7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
            size: isDone ? 18 : 14,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF14532D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── P3-04: ALL ROUNDS DONE CARD ─────────────────────────────────────────
  Widget _buildAllDoneCard({required int completedRounds, required int totalRounds}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All $totalRounds rounds completed today',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 4),
                // P3.5-03: forward-looking — reinforce next-day return habit
                const Text(
                  'Your pond stayed on track today.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Come back tomorrow and keep the same consistency.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── V2-01: CURRENCY FORMATTER ────────────────────────────────────────────
  // Compact ₹ display: ₹500, ₹1.2K, ₹15.0K — consistent across all ₹ labels.
  static String _formatCurrency(double value) {
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toInt()}';
  }

  // ── P3-05: MOTIVATION MESSAGE BY ROUND PROGRESS ──────────────────────────
  static String _feedMotivationMessage(int completedRound) {
    switch (completedRound) {
      case 1:
        return 'Good start today';
      case 2:
        return 'Nice consistency';
      case 3:
        return 'Great discipline';
      case 4:
        // P3.5-02: connect action → outcome for stronger habit loop
        return 'Perfect feeding today — pond on track for best growth';
      default:
        return 'Round $completedRound done';
    }
  }

  Widget _buildCompletedDashboard(
      BuildContext context, WidgetRef ref, Pond pond) {
    final currentDoc = ref.watch(docProvider(pond.id));
    final harvests = ref.watch(harvestProvider(pond.id));
    final totalYield = harvests.fold(0.0, (sum, h) => sum + h.quantity);
    final totalRevenue = harvests.fold(0.0, (sum, h) => sum + h.revenue);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cycle Completed",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30)),
                    child: const Text("IDLE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _completedStat("TOTAL YIELD", "${totalYield.toInt()} kg"),
                  const SizedBox(width: 40),
                  _completedStat("TOTAL REVENUE",
                      "₹${NumberFormat('#,##,###').format(totalRevenue)}"),
                ],
              ),
              const SizedBox(height: 20),
              _completedStat("DURATION", "$currentDoc Days"),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NewCycleSetupScreen(pondId: pond.id)));
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text("START NEW CYCLE",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Secondary Summary Access
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context,
                "Reports",
                Icons.analytics_rounded,
                Colors.orange,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HarvestSummaryScreen(pondId: pond.id))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                "History",
                Icons.history_rounded,
                Colors.blue,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FeedHistoryScreen(pondId: pond.id))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _completedStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _WaterRoundCard extends StatelessWidget {
  final String time;
  final String title;
  final List<dynamic> items;
  final bool isApplied;
  final VoidCallback? onMarkDone;

  const _WaterRoundCard({
    required this.time,
    required this.title,
    required this.items,
    required this.isApplied,
    this.onMarkDone,
  });

  // ── Water palette (mirrors FeedTimelineCard's green palette but teal) ──
  static const _teal       = Color(0xFF0D9488);
  static const _tealLight  = Color(0xFF14B8A6);
  static const _tealBg     = Color(0xFFF0FDFA);
  static const _tealBorder = Color(0xFF99F6E4);
  static const _slate100   = Color(0xFFF1F5F9);
  static const _slate200   = Color(0xFFE2E8F0);
  static const _slate400   = Color(0xFF94A3B8);
  static const _slate500   = Color(0xFF64748B);
  static const _ink        = Color(0xFF0F172A);
  static const _red        = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return isApplied ? _doneCard() : _pendingCard();
  }

  // ── DONE card ──────────────────────────────────────────────────────────
  Widget _doneCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _tealBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tealBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          const Text(
                            "WATER SUPPLEMENT",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _teal,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x260D9488),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "COMPLETED",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _teal,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _teal,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "DONE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items used
          if (items.isNotEmpty) ...[
            const Divider(height: 1, color: _tealBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "MIX APPLIED",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _slate400,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: items.map((item) {
                      final name = item is CalculatedItem
                          ? item.name.toUpperCase()
                          : (item.itemName as String).toUpperCase();
                      final qty = item is CalculatedItem
                          ? "${item.quantity.toStringAsFixed(1)}${item.unit}"
                          : "${(item.totalDose as double).toStringAsFixed(1)}${item.unit}";
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _teal.withOpacity(0.2)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _teal,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              TextSpan(
                                text: "  $qty",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── PENDING card ───────────────────────────────────────────────────────
  Widget _pendingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tealLight, width: 2),
        boxShadow: [
          BoxShadow(color: _tealLight.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top badges + title
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge("WATER SUPPLEMENT", _slate400, _slate100),
                          _badge("NOW", Colors.white, _red),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$title  •  $time",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.opacity_rounded, size: 22, color: _teal),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Mix required box
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _teal.withOpacity(0.3)),
                ),
                child: const Text(
                  "RECOMMENDED ACTION",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _teal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _slate200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop_rounded, size: 14, color: _teal),
                        const SizedBox(width: 6),
                        const Text(
                          "MIX REQUIRED",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _teal,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "MANDATORY",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _red,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _itemGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // MARK DONE button
          if (onMarkDone != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onMarkDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "MARK AS APPLIED",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _itemGrid() {
    if (items.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final row = <Widget>[];
      row.add(Expanded(child: _itemCell(items[i])));
      if (i + 1 < items.length) {
        row.add(Container(width: 1, height: 40, color: _slate200, margin: const EdgeInsets.symmetric(horizontal: 8)));
        row.add(Expanded(child: _itemCell(items[i + 1])));
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _itemCell(dynamic item) {
    final name = item is CalculatedItem
        ? item.name.toUpperCase()
        : (item.itemName as String).toUpperCase();
    final qty = item is CalculatedItem
        ? "${item.quantity.toStringAsFixed(1)}${item.unit}"
        : "${(item.totalDose as double).toStringAsFixed(1)}${item.unit}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _teal,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          qty,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
      ],
    );
  }
}

class CompactProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final String totalText; // "0.0 / 0.0 kg"

  const CompactProgressBar({
    super.key,
    required this.progress,
    required this.totalText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: AppRadius.rm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  totalText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                "Today Progress",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── Tank Operation Button (new 4-item design) ──────────────────────────────

class _TankOpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _TankOpButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with optional badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  if (badge != null && badgeColor == const Color(0xFFDC2626))
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
              if (badge != null && badgeColor != const Color(0xFFDC2626)) ...[
                const SizedBox(height: 3),
                Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── GAP 3 — Daily Performance Summary Card ────────────────────────────────────
/// Shown when all feeding rounds are done. Gives the farmer a "how did I do?"
/// snapshot across three dimensions: feeding, FCR, and growth.
class _DailyPerformanceCard extends StatelessWidget {
  final double fcr;
  final double currentAbw;
  final double expectedAbw;
  final int completedRounds;
  final int totalRounds;

  const _DailyPerformanceCard({
    required this.fcr,
    required this.currentAbw,
    required this.expectedAbw,
    required this.completedRounds,
    required this.totalRounds,
  });

  static const _green  = Color(0xFF16A34A);
  static const _amber  = Color(0xFFF59E0B);
  static const _red    = Color(0xFFEF4444);
  static const _slate  = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  // T14 — Overall feeding score from adherence
  static String _feedingScore(double adherence) {
    if (adherence > 0.9) return 'Good';
    if (adherence > 0.75) return 'Average';
    return 'Needs Attention';
  }

  // T14 — Overall day verdict from all three signals
  static _DayVerdict _dayVerdict({
    required double adherence,
    required double fcr,
    required double growthRatio,
  }) {
    final bool feedGood = adherence > 0.9;
    final bool fcrGood  = fcr <= 0 || fcr <= 1.4;
    final bool growthOk = growthRatio <= 0 || growthRatio >= 0.85;

    final int goodCount = (feedGood ? 1 : 0) + (fcrGood ? 1 : 0) + (growthOk ? 1 : 0);
    if (goodCount == 3) return const _DayVerdict('Great day! Everything on track ✅', _green);
    if (goodCount == 2) return const _DayVerdict('Good day — minor area to improve', _amber);
    return const _DayVerdict('Needs attention — check the signals below', _red);
  }

  @override
  Widget build(BuildContext context) {
    // Feeding
    final adherence = totalRounds > 0 ? completedRounds / totalRounds : 0.0;
    final String feedScore = _feedingScore(adherence);
    final String feedLabel;
    final Color feedColor;
    if (adherence >= 1.0) { feedLabel = '$feedScore ✅'; feedColor = _green; }
    else if (adherence >= 0.75) { feedLabel = feedScore; feedColor = _amber; }
    else { feedLabel = feedScore; feedColor = _red; }

    // FCR
    final String fcrLabel;
    final Color fcrColor;
    if (fcr <= 0)         { fcrLabel = 'No data yet'; fcrColor = _slate; }
    else if (fcr <= 1.2)  { fcrLabel = 'Excellent'; fcrColor = _green; }
    else if (fcr <= 1.4)  { fcrLabel = 'Stable'; fcrColor = _green; }
    else if (fcr <= 1.6)  { fcrLabel = 'Watch it'; fcrColor = _amber; }
    else                  { fcrLabel = 'Too high'; fcrColor = _red; }

    // Growth
    final double growthRatio = (currentAbw > 0 && expectedAbw > 0)
        ? currentAbw / expectedAbw
        : 0.0;
    final String growthLabel;
    final Color growthColor;
    if (currentAbw <= 0 || expectedAbw <= 0) {
      growthLabel = 'Do a sampling'; growthColor = _slate;
    } else {
      if (growthRatio >= 1.0)       { growthLabel = 'Ahead ✅'; growthColor = _green; }
      else if (growthRatio >= 0.85) { growthLabel = 'On track'; growthColor = _green; }
      else                          { growthLabel = 'Slightly slow'; growthColor = _amber; }
    }

    // T14 — Overall day verdict
    final verdict = _dayVerdict(
      adherence: adherence,
      fcr: fcr,
      growthRatio: growthRatio,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY\'S PERFORMANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _slate,
              letterSpacing: 1.0,
            ),
          ),
          // T14 — Overall day score banner
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: verdict.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: verdict.color.withOpacity(0.25)),
            ),
            child: Text(
              verdict.message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: verdict.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PerfItem(label: 'Feeding', value: feedLabel, color: feedColor),
              _PerfDivider(),
              _PerfItem(label: 'FCR', value: fcrLabel, color: fcrColor),
              _PerfDivider(),
              _PerfItem(label: 'Growth', value: growthLabel, color: growthColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayVerdict {
  final String message;
  final Color color;
  const _DayVerdict(this.message, this.color);
}

class _PerfItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PerfItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _PerfDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: const Color(0xFFE2E8F0),
      );
}
