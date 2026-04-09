import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import 'screens/add_supplement_screen.dart';
import 'supplement_provider.dart';

class SupplementMixScreen extends ConsumerStatefulWidget {
  final String pondId;

  const SupplementMixScreen({super.key, required this.pondId});

  @override
  ConsumerState<SupplementMixScreen> createState() => _SupplementMixScreenState();
}

class _SupplementMixScreenState extends ConsumerState<SupplementMixScreen> {
  SupplementType? _filterType;

  Future<void> _openPlanEditor(Supplement plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplementScreen(
          pondId: widget.pondId,
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
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldStop || !mounted) {
      return;
    }

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
    final plans = _pondPlans();
    final logs = _pondLogs();
    final today = DateTime.now();
    final todayPlans = plans.where((plan) => plan.isActiveOnDate(today)).toList();
    final activePlans = todayPlans.where((plan) => !plan.isPaused).toList();
    final pausedPlans = todayPlans.where((plan) => plan.isPaused).toList();
    final filteredHistory = _filterType == null
        ? logs
        : logs.where((log) => log.supplementType == _filterType).toList();

    return Scaffold(
      backgroundColor: AppColors.cardBg,
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
          MaterialPageRoute(builder: (_) => AddSupplementScreen(pondId: widget.pondId)),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  List<Supplement> _pondPlans() {
    return ref
        .watch(supplementProvider)
        .where((plan) => plan.appliesToPond(widget.pondId))
        .toList()
      ..sort((a, b) {
        final aDate = a.type == SupplementType.feedMix ? a.startDate : a.date;
        final bDate = b.type == SupplementType.feedMix ? b.startDate : b.date;
        return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
      });
  }

  List<SupplementLog> _pondLogs() {
    return ref
        .watch(supplementLogProvider)
        .where((log) => log.pondId == widget.pondId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
        : "${_singleDate(plan.date)} • ${_formatTime(plan.effectiveWaterTime ?? '')} • ${_repeatText(plan.frequencyDays)}";

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rs,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...logs.take(20).map((log) => _ApplicationLogRow(log: log)),
        ],
      ),
    );
  }
}

class _ApplicationLogRow extends StatelessWidget {
  final SupplementLog log;

  const _ApplicationLogRow({required this.log});

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
      decoration: const BoxDecoration(
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
