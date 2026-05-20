import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/supplement_schedule.dart';
import '../../core/providers/product_provider.dart';
import '../../core/repositories/schedule_repository.dart';
import '../../core/theme/app_theme.dart';
import 'screens/add_supplement_screen.dart';
import 'supplement_provider.dart';

class SupplementMixScreen extends ConsumerStatefulWidget {
  final String pondId;
  final String? farmId;

  const SupplementMixScreen({
    super.key,
    required this.pondId,
    this.farmId,
  });

  @override
  ConsumerState<SupplementMixScreen> createState() => _SupplementMixScreenState();
}

class _SupplementMixScreenState extends ConsumerState<SupplementMixScreen> {
  SupplementType? _filterType;
  final _scheduleRepo = ScheduleRepository();

  Future<void> _pauseSchedule(SupplementSchedule s) async {
    await _scheduleRepo.updateSchedule(
      s.copyWith(isPaused: true, updatedAt: DateTime.now()),
    );
    ref.invalidate(supplementSchedulesProvider((pondId: widget.pondId, farmId: widget.farmId ?? '')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule paused'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _resumeSchedule(SupplementSchedule s) async {
    await _scheduleRepo.updateSchedule(
      s.copyWith(isPaused: false, updatedAt: DateTime.now()),
    );
    ref.invalidate(supplementSchedulesProvider((pondId: widget.pondId, farmId: widget.farmId ?? '')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule resumed'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _markScheduleApplied(SupplementSchedule s) async {
    try {
      // Build applied items from products[] (multi-product) or scalar fields.
      final items = s.products.isNotEmpty
          ? s.products
              .map((p) => CalculatedItem(
                    name: p['productName'] as String? ?? '',
                    quantity: (p['quantity'] as num?)?.toDouble() ?? 0.0,
                    unit: p['unit'] as String? ?? '',
                  ))
              .toList()
          : (s.productName != null
              ? [
                  CalculatedItem(
                    name: s.productName!,
                    quantity: s.quantity ?? 0.0,
                    unit: s.unit ?? '',
                  )
                ]
              : <CalculatedItem>[]);

      final type = s.applicationType == 'feed_mix'
          ? SupplementType.feedMix
          : SupplementType.waterMix;

      // logApplication inserts the DB row AND does an optimistic state prepend,
      // so the history list and appliedTodayIds update immediately.
      final warnings = await ref
          .read(supplementLogProvider(widget.pondId).notifier)
          .logApplication(
            supplementId: s.id,
            supplementName: s.productName ?? s.categoryName ?? 'Supplement',
            items: items,
            supplementType: type,
            farmId: widget.farmId,
            // inputUnit = 'acre' lets SupplementLog.fromDbLog infer waterMix type
            // so the WATER filter in Application History works correctly.
            inputUnit: 'acre',
          );

      if (!mounted) return;
      final name = s.productName ?? s.categoryName ?? 'Supplement';
      final msg = warnings.isEmpty
          ? '$name marked as applied'
          : '$name applied. ${warnings.first}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopSchedule(SupplementSchedule s) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stop Schedule?'),
            content: Text(
              "Stop '${s.productName ?? s.categoryName ?? 'this treatment'}' from today? "
              'You can re-add it later if needed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Stop', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm || !mounted) return;
    await _scheduleRepo.updateSchedule(
      s.copyWith(stopDate: DateTime.now(), updatedAt: DateTime.now()),
    );
    ref.invalidate(supplementSchedulesProvider((pondId: widget.pondId, farmId: widget.farmId ?? '')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule stopped'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _openPlanEditor(Supplement plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplementScreen(
          pondId: widget.pondId,
          farmId: widget.farmId,
          supplement: plan,
        ),
      ),
    );
  }

  void _togglePlanPause(Supplement plan) {
    ref.read(supplementProvider.notifier).togglePause(plan.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(plan.isPaused ? "Plan resumed" : "Plan paused"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _stopPlan(Supplement plan) async {
    final shouldStop = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Stop Supplement Plan?"),
            content: Text(
              "This will remove '${plan.name}' from active supplement plans.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  "Stop Plan",
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldStop) return;
    if (!mounted) return;
    ref.read(supplementProvider.notifier).deleteSupplement(plan.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Supplement plan stopped"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref
        .watch(supplementProvider)
        .where((plan) => plan.appliesToPond(widget.pondId))
        .toList()
      ..sort((a, b) {
        final aDate = a.type == SupplementType.feedMix ? a.startDate : a.date;
        final bDate = b.type == SupplementType.feedMix ? b.startDate : b.date;
        return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
      });
    final logsAsync = ref.watch(supplementLogProvider(widget.pondId));
    final logs = logsAsync.valueOrNull ?? [];
    final today = DateTime.now();

    // IDs of schedules already applied today — used to filter Active Today.
    final appliedTodayIds = logs
        .where((l) {
          final t = l.timestamp;
          return t.year == today.year &&
              t.month == today.month &&
              t.day == today.day;
        })
        .map((l) => l.supplementId)
        .toSet();

    final todayPlans = plans.where((plan) => plan.isActiveOnDate(today)).toList();
    final activePlans = todayPlans.where((plan) => !plan.isPaused).toList();
    final pausedPlans = todayPlans.where((plan) => plan.isPaused).toList();
    final sortedLogs = [...logs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final filteredHistory = _filterType == null
        ? sortedLogs
        : sortedLogs.where((log) => log.supplementType == _filterType).toList();
    final schedulesAsync = ref.watch(supplementSchedulesProvider((pondId: widget.pondId, farmId: widget.farmId ?? '')));

    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: const Text("Supplement Mix", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("ACTIVE TODAY"),
            if (activePlans.isEmpty && pausedPlans.isEmpty)
              _emptyState("No active supplements for today."),
            ...activePlans.map((plan) => _PlanCard(
                  plan: plan,
                  highlight: true,
                  onEdit: () => _openPlanEditor(plan),
                  onTogglePause: () => _togglePlanPause(plan),
                  onStop: () => _stopPlan(plan),
                )),
            if (pausedPlans.isNotEmpty) ...[
              AppSpacing.hBase,
              _sectionHeader("PAUSED PLANS"),
              ...pausedPlans.map((plan) => _PlanCard(
                    plan: plan,
                    onEdit: () => _openPlanEditor(plan),
                    onTogglePause: () => _togglePlanPause(plan),
                    onStop: () => _stopPlan(plan),
                  )),
            ],
            AppSpacing.hXl,
            _sectionHeader("SUPPLEMENT SCHEDULES"),
            schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return _emptyState("No supplement schedules.");
                }

                // Active today = active status + fires today + not yet applied today.
                final activeSchedules = schedules
                    .where((s) =>
                        s.isActive &&
                        !s.isPaused &&
                        s.isActiveOnDate(today) &&
                        !appliedTodayIds.contains(s.id))
                    .toList();

                // Upcoming = active status + start date strictly in the future.
                final todayDateOnly = DateTime(today.year, today.month, today.day);
                final upcomingSchedules = schedules
                    .where((s) =>
                        s.isActive &&
                        DateTime(s.startDate.year, s.startDate.month, s.startDate.day)
                            .isAfter(todayDateOnly))
                    .toList();

                final pastSchedules = schedules
                    .where((s) =>
                        s.endDate.isBefore(todayDateOnly) ||
                        (s.stopDate != null && s.stopDate!.isBefore(todayDateOnly)))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Today — pending schedules with Mark as Applied action
                    if (activeSchedules.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 8, left: 4),
                        child: Text(
                          "Active Today",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      ...activeSchedules.map((schedule) => _ScheduleCard(
                            schedule: schedule,
                            pondId: widget.pondId,
                            onPause: _pauseSchedule,
                            onResume: _resumeSchedule,
                            onStop: _stopSchedule,
                            // Feed supplements are applied only via feed round cards.
                            // Water supplements can be applied directly here.
                            onMarkApplied: schedule.applicationType == 'water_mix'
                                ? _markScheduleApplied
                                : null,
                            activeToday: true,
                          )),
                    ] else ...[
                      _emptyState("No active schedules for today."),
                    ],

                    // Upcoming
                    if (upcomingSchedules.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, top: 8, left: 4),
                        child: Text(
                          "Upcoming",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      ...upcomingSchedules
                          .map((schedule) =>
                              _ScheduleCard(schedule: schedule, pondId: widget.pondId, onPause: _pauseSchedule, onResume: _resumeSchedule, onStop: _stopSchedule)),
                    ],

                    // Past Schedules (collapsible)
                    if (pastSchedules.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _PastSchedulesAccordion(
                        schedules: pastSchedules,
                        pondId: widget.pondId,
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) =>
                  _emptyState("Error loading schedules"),
            ),
            AppSpacing.hXl,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader("APPLICATION HISTORY"),
                Row(
                  children: [
                    _filterChip(null, "ALL"),
                    const SizedBox(width: 8),
                    _filterChip(SupplementType.feedMix, "FEED"),
                    const SizedBox(width: 8),
                    _filterChip(SupplementType.waterMix, "WATER"),
                  ],
                ),
              ],
            ),
            if (filteredHistory.isEmpty)
              _emptyState("No application history found.")
            else
              _ApplicationLedger(logs: filteredHistory),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddSupplementScreen(
              pondId: widget.pondId,
              farmId: widget.farmId,
            ),
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(child: Text(text, style: TextStyle(color: Colors.grey.shade500))),
    );
  }

  Widget _filterChip(SupplementType? type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _PastSchedulesAccordion extends StatefulWidget {
  final List<SupplementSchedule> schedules;
  final String pondId;

  const _PastSchedulesAccordion({
    required this.schedules,
    required this.pondId,
  });

  @override
  State<_PastSchedulesAccordion> createState() => _PastSchedulesAccordionState();
}

class _PastSchedulesAccordionState extends State<_PastSchedulesAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Past Schedules (${widget.schedules.length})",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: widget.schedules
                    .map((schedule) =>
                        _ScheduleCard(schedule: schedule, pondId: widget.pondId))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Supplement plan;
  final bool highlight;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePause;
  final VoidCallback? onStop;

  const _PlanCard({
    required this.plan,
    this.highlight = false,
    this.onEdit,
    this.onTogglePause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isFeed = plan.type == SupplementType.feedMix;
    final accent = isFeed ? Colors.indigo : Colors.teal;
    final subtitle = isFeed
        ? "${_dateRange(plan.startDate, plan.endDate)} • ${plan.feedingTimes.join(', ')}"
        : "${_singleDate(plan.date)} • ${plan.effectiveWaterTime != null ? _formatTime(plan.effectiveWaterTime!) : 'No time set'} • ${_repeatText(plan.frequencyDays)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? accent.withOpacity(0.25) : Colors.grey.shade200,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFeed ? "FEED" : "WATER",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
              if (plan.isPaused) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "PAUSED",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit?.call();
                  } else if (value == 'pause') {
                    onTogglePause?.call();
                  } else if (value == 'stop') {
                    onStop?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text("Edit Plan"),
                  ),
                  PopupMenuItem<String>(
                    value: 'pause',
                    child: Text(plan.isPaused ? "Resume Plan" : "Pause Plan"),
                  ),
                  const PopupMenuItem<String>(
                    value: 'stop',
                    child: Text("Stop Plan"),
                  ),
                ],
              ),
              Text(
                plan.pondIds.contains('ALL') ? "ALL PONDS" : "THIS POND",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.goal != null ? _goalText(plan.goal!) : plan.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (plan.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "No items",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ),
          ...plan.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${item.quantity.toStringAsFixed(1)} ${item.unit}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static String _goalText(SupplementGoal goal) {
    switch (goal) {
      case SupplementGoal.growthBoost:
        return "Growth / Mineral";
      case SupplementGoal.diseasePrevention:
        return "Immunity";
      case SupplementGoal.waterCorrection:
        return "Water Quality";
      case SupplementGoal.stressRecovery:
        return "Stress";
    }
  }

  static String _dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return "No date";
    return "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM').format(end)}";
  }

  static String _singleDate(DateTime? date) {
    if (date == null) return "No date";
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String _formatTime(String value) {
    try {
      final parts = value.split(':');
      if (parts.length == 2) {
        final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Time format failed for "$value": $e');
    }
    return value;
  }

  static String _repeatText(int? frequency) {
    if (frequency == null || frequency == 0) return "Today only";
    if (frequency == 7) return "Every 7 days";
    return "Every $frequency days";
  }
}

class _ApplicationLedger extends StatelessWidget {
  final List<SupplementLog> logs;

  const _ApplicationLedger({required this.logs});

  @override
  Widget build(BuildContext context) {
    final displayed = logs.take(20).toList();
    final hasMore = logs.length > 20;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rs,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displayed.asMap().entries.map(
                (e) => _ApplicationLogRow(
                  log: e.value,
                  isLast: !hasMore && e.key == displayed.length - 1,
                ),
              ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              child: Text(
                "Showing 20 of ${logs.length} entries",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplicationLogRow extends StatelessWidget {
  final SupplementLog log;
  final bool isLast;

  const _ApplicationLogRow({required this.log, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isFeed = log.supplementType == SupplementType.feedMix;
    final accent = isFeed ? Colors.indigo : Colors.teal;
    final dateText = DateFormat('dd MMM, hh:mm a').format(log.timestamp);
    final title = log.supplementName ??
        (isFeed ? "Feed R${log.feedRound ?? '-'} Mix" : "Water Mix");
    final contextText = isFeed
        ? "R${log.feedRound ?? '-'} • ${(log.inputValue ?? 0).toStringAsFixed(1)} ${log.inputUnit ?? 'kg'}"
        : "${(log.inputValue ?? 0).toStringAsFixed(2)} ${log.inputUnit ?? 'acre'}";
    final mixDetails = log.appliedItems.isEmpty
        ? title
        : log.appliedItems
            .map((item) => item.name)
            .take(3)
            .join(", ");
    final qtyUsed = log.appliedItems.isEmpty
        ? "--"
        : log.appliedItems
            .map((item) => "${item.quantity.toStringAsFixed(1)} ${item.unit}")
            .take(3)
            .join(", ");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateText,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isFeed ? "FEED" : "WATER",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ledgerField("Context", contextText),
          const SizedBox(height: 8),
          _ledgerField("Mix Details", "$title${mixDetails == title ? '' : ' • $mixDetails'}"),
          const SizedBox(height: 8),
          _ledgerField("Qty Used", qtyUsed, emphasize: true),
        ],
      ),
    );
  }

  Widget _ledgerField(String label, String value, {bool emphasize = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final SupplementSchedule schedule;
  final String pondId;
  final Future<void> Function(SupplementSchedule)? onPause;
  final Future<void> Function(SupplementSchedule)? onResume;
  final Future<void> Function(SupplementSchedule)? onStop;
  final Future<void> Function(SupplementSchedule)? onEdit;
  final Future<void> Function(SupplementSchedule)? onDelete;

  const _ScheduleCard({
    required this.schedule,
    required this.pondId,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final isFeed = s.applicationType == 'feed_mix';
    final accent = isFeed ? Colors.indigo : Colors.teal;
    final isStopped = s.stopDate != null && !DateTime.now().isBefore(s.stopDate!);

    // Resolve product list: prefer products[] (multi-product), fall back to scalar.
    final productList = s.products.isNotEmpty
        ? s.products
        : (s.productName != null
            ? [
                {
                  'productName': s.productName,
                  'quantity': s.quantity,
                  'unit': s.unit,
                }
              ]
            : <Map<String, dynamic>>[]);

    return Opacity(
      opacity: (s.isPaused || isStopped) ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: accent.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productList.length > 1
                            ? '${productList.length} Products'
                            : (s.productName ?? s.categoryName ?? 'Supplement'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFeed
                            ? '${DateFormat('dd MMM').format(s.startDate)} – ${DateFormat('dd MMM').format(s.endDate)}'
                            : '${DateFormat('dd MMM yyyy').format(s.startDate)}  ·  ${s.recurrenceLabel()}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (s.isPaused) ...[
                        const SizedBox(height: 4),
                        Text(
                          'PAUSED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ] else if (isStopped) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'STOPPED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isFeed ? 'FEED' : 'WATER',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accent),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: Colors.grey.shade500),
                      itemBuilder: (_) => [
                        // Pause / Resume toggle
                        if (!isStopped)
                          PopupMenuItem(
                            value: s.isPaused ? 'resume' : 'pause',
                            child: Text(
                                s.isPaused ? 'Resume Schedule' : 'Pause Schedule'),
                          ),
                        // Stop
                        if (!isStopped)
                          const PopupMenuItem(
                            value: 'stop',
                            child: Text('Stop Schedule',
                                style: TextStyle(color: Colors.orange)),
                          ),
                        // Edit
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Schedule'),
                        ),
                        // Delete
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Schedule',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (action) {
                        switch (action) {
                          case 'pause':
                            onPause?.call(s);
                          case 'resume':
                            onResume?.call(s);
                          case 'stop':
                            onStop?.call(s);
                          case 'edit':
                            onEdit?.call(s);
                          case 'delete':
                            onDelete?.call(s);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),

            // ── Multi-product list ────────────────────────────────────────
            if (productList.length > 1) ...[
              const SizedBox(height: 10),
              ...productList.map((p) {
                final name = p['productName'] as String? ?? '';
                final qty = (p['quantity'] as num?)?.toDouble();
                final unit = p['unit'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      if (qty != null && qty > 0)
                        Text(
                          '${qty.toStringAsFixed(qty < 10 ? 1 : 0)} $unit'.trim(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                );
              }),
            ],

            // ── Feed round chips ──────────────────────────────────────────
            if (isFeed && s.selectedFeedRounds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: s.selectedFeedRounds
                    .map((round) => Chip(
                          label: Text(round,
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: accent.withOpacity(0.1),
                          labelStyle: TextStyle(color: accent),
                        ))
                    .toList(),
              ),
            ],

            if (s.notes != null && s.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                s.notes!,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
