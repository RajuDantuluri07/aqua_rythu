import '../../services/farm_service.dart';
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
import 'package:aqua_rythu/core/engines/feed_plan_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqua_rythu/core/language/language_switcher.dart';
import 'package:aqua_rythu/core/language/app_localizations.dart';
import 'package:flutter/foundation.dart';
import '../debug/debug_feed_screen.dart';
import '../debug/debug_dashboard_screen.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _showFeedScheduleTip = false;
  bool _showDoc8FeedBanner = false;
  int _debugTapCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkFeedScheduleTip();
  }

  /// Secret 5-tap trigger → opens the Feed Engine Debug dashboard.
  void _onDebugTap(String pondId, String pondName) {
    if (!kDebugMode) return;
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

  /// Shows the "Feeding increased to 4 rounds" banner once when DOC reaches 8.
  Future<void> _checkDoc8FeedNotification(String pondId, int doc) async {
    if (doc < 8) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'doc8_feed_notified_$pondId';
    final alreadyShown = prefs.getBool(key) ?? false;
    if (!alreadyShown && mounted) {
      await prefs.setBool(key, true);
      setState(() => _showDoc8FeedBanner = true);
      // Auto-hide after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showDoc8FeedBanner = false);
      });
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
  // DOC ≤ 30: next round unlocks once prev feed is marked done
  // DOC > 30: next round unlocks only AFTER prev feed done AND prev tray logged
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
    // DOC 15–30: optional (show button but doesn't block next round)
    // DOC > 30:  mandatory (blocks next round until logged)
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
  /// DOC > 30: first round where feed is not done, but only after previous
  ///           round's tray is logged.
  int _getCurrentRound(int doc, Map<int, bool> feedDone,
      Map<int, bool> trayDone, int totalRounds) {
    for (int i = 1; i <= totalRounds; i++) {
      if (!(feedDone[i] ?? false)) return i;
      // DOC > 30: if this round's feed is done but tray not logged,
      // it still "owns" the current slot — next round stays locked
      if (doc > 30 && !(trayDone[i] ?? false)) return i;
    }
    return totalRounds + 1;
  }

  /// A round is locked when the previous round is not fully cleared.
  /// DOC ≤ 30: cleared = feed done.
  /// DOC > 30: cleared = feed done AND tray logged.
  bool _isLocked(int doc, int round, Map<int, bool> feedDone,
      Map<int, bool> trayDone) {
    if (round <= 1) return false;
    final prev = round - 1;
    final prevFeedDone = feedDone[prev] ?? false;
    if (!prevFeedDone) return true;
    // For DOC > 30, also require previous tray to be logged
    if (doc > 30 && !(trayDone[prev] ?? false)) return true;
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
      // No DB data yet — show defaults based on DOC
      final defaultActive = doc <= 7 ? 2 : 4;
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

  void _showFarmSwitchDialog(FarmState farmState) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).t('select_farm')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          ...farmState.farms.map((farm) {
            final isSelected = farm.id == farmState.selectedId;
            return SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              onPressed: () {
                ref.read(farmProvider.notifier).selectFarm(farm.id);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(Icons.landscape,
                      color: isSelected ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      farm.name,
                      style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                ],
              ),
            );
          }),
          const Divider(),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () {
              Navigator.pop(context);
              _showAddFarmDialog();
            },
            child: Row(
              children: [
                Icon(Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).t('add_new_farm'),
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
                try {
                  final farmService = FarmService();
                  await farmService.createFarm(
                    name: nameCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    farmType: 'Semi-Intensive',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).t('farm_created'))),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
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
          bottomNavigationBar: const AppBottomBar(currentIndex: 0),
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
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
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
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
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

    // Trigger DOC 8 notification check whenever DOC or selectedPond changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && selectedPond.isNotEmpty) {
        _checkDoc8FeedNotification(selectedPond, currentDoc);
      }
    });

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

    // Enable Smart Feed when DOC is 30 or when pond has Smart Feed enabled
    final isSmartFeedEnabled = currentPond.isSmartFeedEnabled || (currentDoc >= 30);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
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
                                    "${AppLocalizations.of(context).t('delete_pond_confirm')} '${pond.name}'? ${AppLocalizations.of(context).t('delete_pond_warning')}"),
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

              /// QUICK STATS CARD — SPECIES / DOC / SURVIVAL
              /// 5-tap anywhere on this strip → opens Feed Engine Debug Dashboard
              GestureDetector(
                onTap: () => _onDebugTap(selectedPond, currentPond.name),
                child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rm,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    // SPECIES
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).t('species'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "L. vannamei",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _divider(),
                    // DOC
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).t('doc'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$currentDoc ${AppLocalizations.of(context).t('days')}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _divider(),
                    // SURVIVAL
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context).t('survival'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_estimatedSurvivalRate(currentDoc)}%",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ), // GestureDetector — debug 5-tap

              const SizedBox(height: 12),

              // ── TODAY FEED PLAN BANNER ────────────────────────────────────
              Builder(builder: (context) {
                final feedRoundsToday = dashboardState.roundFeedAmounts.isNotEmpty
                    ? dashboardState.roundFeedAmounts.values.where((v) => v > 0).length
                    : (currentDoc <= 7 ? 2 : 4);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded,
                          size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Text(
                        'Today Feed Plan: $feedRoundsToday feeds',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // ── DOC 8 TRANSITION NOTIFICATION (shown once) ───────────────
              if (_showDoc8FeedBanner) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFEA580C)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Feeding increased to 4 rounds from today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showDoc8FeedBanner = false),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFFEA580C)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              if (isCompleted)
                _buildCompletedDashboard(context, ref, currentPond)
              else ...[
                /// ── ACTION BUTTONS: Feed Schedule + Supplement Mix ─────────────
                Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Transform.scale(
                          scale: _showFeedScheduleTip ? _pulseAnim.value : 1.0,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (_showFeedScheduleTip) {
                              _pulseController.stop();
                              setState(() => _showFeedScheduleTip = false);
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeedScheduleScreen(pondId: selectedPond),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showFeedScheduleTip
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context).t('feed_schedule'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplementMixScreen(pondId: selectedPond),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context).t('supplement_mix'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// ── TODAY'S PROGRESS (Smart Feed only: DOC > 30) ──────────────
                if (isSmartFeedEnabled) ...[
                  _buildTodayProgressCard(
                    consumedFeed: consumedFeed,
                    plannedFeed: plannedFeed,
                    completedRounds: dashboardState.roundFeedStatus.values
                        .where((s) => s == 'completed')
                        .length,
                    totalRounds: dashboardState.roundFeedAmounts.isNotEmpty
                        ? dashboardState.roundFeedAmounts.values.where((v) => v > 0).length
                        : (currentDoc <= 7 ? 2 : 4),
                    fcrTrend: fcrTrend,
                  ),
                  const SizedBox(height: 16),
                ],

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
                else if (dashboardState.roundFeedAmounts.isEmpty && currentDoc <= 30)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).t('no_feed_plan'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
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
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                /// ── TANK OPERATIONS ───────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).t('tank_operations'),
                    style: const TextStyle(
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

    return timelineItems.map<Widget>((itemData) {
      final bool isFeed = itemData['type'] == 'feed';

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
        // DOC 15–30: tray is optional — show the button but don't block progression.
        // DOC > 30:  tray is mandatory — handled by _isLocked/_getCurrentRound.
        // isPendingTray = tray not yet handled at all (neither logged nor skipped)
        final bool isPendingTray = isDone && currentDoc >= 15 && !isTrayLogged;

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

        card = FeedTimelineCard(
          round: round,
          time: time,
          feedQty: qty,
          state: cardState,
          isPendingTray: isPendingTray,
          isTraySkipped: isTraySkipped,
          trayStatuses: thisRoundLog?.isSkipped == true ? null : thisRoundLog?.trays,
          supplements: supplements,
          isSmartFeed: isSmartFeedEnabled,
          // MARK AS FED: always available on the current round, for all DOCs
          onMarkDone: isCurrent
              ? () {
                  if (qty > 0) {
                    ref.read(feedHistoryProvider.notifier).logFeeding(
                      pondId: selectedPond,
                      doc: currentDoc,
                      round: round,
                      qty: qty,
                    );
                    _logFeedSupplementApplication(
                      pondId: selectedPond,
                      pondName: pondName,
                      round: round,
                      feedQty: qty,
                      activePlansToday: activePlansToday,
                    );
                  }
                  // markFeedDone updates status in DB → loadTodayFeed → Riverpod rebuild
                  // Card then transitions: current → done (+ LOG TRAY if DOC >= 15)
                  ref.read(pondDashboardProvider.notifier).markFeedDone(round);
                }
              : null,
          // EDIT: only for DOC > 30, current round only (done/upcoming are not editable here)
          onEdit: currentDoc > 30 && cardState == FeedRoundState.current
              ? (double newQty) {
                  ref.read(pondDashboardProvider.notifier).updateRoundAmount(round, newQty);
                }
              : null,
          // LOG TRAY: pending = never logged, skipped = auto-skipped (show "Update Now")
          onLogTray: (isPendingTray || isTraySkipped) ? () => openTray(round, false) : null,
          isNext: isNext,
        );
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
    }).toList();
  }

  Widget _kpi(String title, String value, IconData icon, Color color,
      {double? trend, bool inverseColor = false}) {
    Color? trendColor;
    IconData? trendIcon;

    if (trend != null && (trend.abs() > 0.001)) {
      final isPositive = trend > 0;
      // inverseColor = true means decreasing (negative trend) is good (like FCR)
      final isGood = inverseColor ? !isPositive : isPositive;
      trendColor = isGood ? Colors.green : Colors.red;
      trendIcon =
          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    }

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Colors.black87)),
                    ),
                    if (trendIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(trendIcon, size: 12, color: trendColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 24, color: Colors.grey.shade300);
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

  // ── TODAY'S PROGRESS card (Smart Feed only) ───────────────────────
  Widget _buildTodayProgressCard({
    required double consumedFeed,
    required double plannedFeed,
    required int completedRounds,
    required int totalRounds,
    required double fcrTrend,
  }) {
    final progress = plannedFeed == 0 ? 0.0 : (consumedFeed / plannedFeed).clamp(0.0, 1.0);
    final isOnTrack = progress >= (completedRounds / totalRounds) - 0.1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: Feed Mode badge  |  rounds  |  status icon ────────
          Row(
            children: [
              // Feed Mode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  "FEED MODE",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              // Rounds counter
              Text(
                "$completedRounds / $totalRounds rounds",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 8),
              // On-track icon
              Icon(
                isOnTrack ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 15,
                color: isOnTrack ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // ── Progress bar + kg inline ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: isOnTrack ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${consumedFeed.toStringAsFixed(1)}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextSpan(
                      text: " / ${plannedFeed.toStringAsFixed(0)} kg",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                      Row(
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0x260D9488),
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
            Divider(height: 1, color: _tealBorder),
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
