import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'supplement_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'screens/add_supplement_screen.dart';
import 'screens/supplement_calculator.dart';

class SupplementMixScreen extends ConsumerStatefulWidget {
  final String pondId;
  const SupplementMixScreen({super.key, required this.pondId});

  @override
  ConsumerState<SupplementMixScreen> createState() => _SupplementMixScreenState();
}

class _SupplementMixScreenState extends ConsumerState<SupplementMixScreen> {
  SupplementType? _filterType;

  @override
  Widget build(BuildContext context) {
    final pondId = widget.pondId;
    final doc = ref.watch(docProvider(pondId));
    final allSupplements = ref.watch(supplementProvider);
    final logs = ref.watch(supplementLogProvider).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Get pond details for dose calculation
    final pondState = ref.watch(farmProvider);
    final currentFarm = pondState.currentFarm;
    final pond = currentFarm?.ponds.firstWhere((p) => p.id == pondId);
    final area = pond?.area ?? 1.0;

    // Track what has been applied today
    final today = DateTime.now();
    final appliedTodayIds = logs
        .where((l) =>
            l.timestamp.year == today.year &&
            l.timestamp.month == today.month &&
            l.timestamp.day == today.day)
        .map((l) => l.supplementId)
        .toSet();

    final pondSupplements = allSupplements.where((s) => 
      s.pondIds.contains(pondId) || s.pondIds.contains('ALL')
    ).toList();

    final active = pondSupplements.where((s) => 
      doc >= s.startDoc && doc <= s.endDoc
    ).toList();

    final upcoming = pondSupplements.where((s) => 
      doc < s.startDoc
    ).toList();
    
    final expired = pondSupplements.where((s) =>
      doc > s.endDoc
    ).toList();

    String getPlanName(String id) {
      try {
        return allSupplements.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return "Manual Application";
      }
    }

    String getPondName(String pid) {
      for (var f in pondState.farms) {
        for (var p in f.ponds) {
          if (p.id == pid) return p.name;
        }
      }
      return "Unknown Pond";
    }

    SupplementType? getSupplementType(String id) {
      try {
        return allSupplements.firstWhere((s) => s.id == id).type;
      } catch (_) {
        return null;
      }
    }

    final filteredLogs = _filterType == null
        ? logs
        : logs
            .where((l) => getSupplementType(l.supplementId) == _filterType)
            .toList();

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
            _buildSectionHeader("ACTIVE TODAY (DOC $doc)"),
            if (active.isEmpty)
              _buildEmptyState(context, "No active supplements for today."),
            ...active.map((s) => _SupplementCard(
                  supplement: s,
                  isActive: true,
                  isApplied: appliedTodayIds.contains(s.id),
                )),

            if (upcoming.isNotEmpty) ...[
              AppSpacing.hBase,
              _buildSectionHeader("UPCOMING"),
              ...upcoming.map((s) => _SupplementCard(
                    supplement: s,
                    isActive: false,
                    isApplied: false,
                  )),
            ],

            if (expired.isNotEmpty) ...[
              AppSpacing.hBase,
              _buildSectionHeader("COMPLETED / EXPIRED"),
              ...expired.map((s) => _SupplementCard(
                    supplement: s,
                    isActive: false,
                    isExpired: true,
                    isApplied: false,
                  )),
            ],

            if (logs.isNotEmpty) ...[
              AppSpacing.hXl,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader("APPLICATION HISTORY"),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        _filterChip(null, "ALL"),
                        const SizedBox(width: 8),
                        _filterChip(SupplementType.feedMix, "FEED"),
                        const SizedBox(width: 8),
                        _filterChip(SupplementType.waterMix, "WATER"),
                      ],
                    ),
                  ),
                ],
              ),
              ...filteredLogs.map((log) => _HistoryCard(
                log: log,
                planName: getPlanName(log.supplementId),
                pondName: getPondName(log.pondId),
                type: getSupplementType(log.supplementId),
              )),
              if (filteredLogs.isEmpty)
                _buildEmptyState(context, "No logs for selected filter."),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSupplementScreen(pondId: widget.pondId)),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildEmptyState(BuildContext context, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(msg, style: TextStyle(color: Colors.grey.shade500)),
      ),
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

class _HistoryCard extends StatelessWidget {
  final SupplementLog log;
  final String? planName;
  final String? pondName;
  final SupplementType? type;

  const _HistoryCard({required this.log, this.planName, this.pondName, this.type});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM, hh:mm a').format(log.timestamp);
    final isWater = type == SupplementType.waterMix;
    final accentColor = isWater ? Colors.teal : Colors.indigo;
    final icon = isWater ? Icons.water_drop_rounded : Icons.grain_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
          top: BorderSide(color: Colors.grey.shade100),
          right: BorderSide(color: Colors.grey.shade100),
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 10, color: accentColor),
                        const SizedBox(width: 4),
                        if (pondName != null)
                          Text(
                            pondName!.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              color: accentColor,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      planName ?? "Supplement Applied",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          ...log.appliedItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.name, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                Text(
                  "${item.quantity.toStringAsFixed(1)}${item.unit}",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _SupplementCard extends ConsumerWidget {
  final Supplement supplement;
  final bool isActive;
  final bool isExpired;
  final bool isApplied;
  final VoidCallback? onMarkDone;

  const _SupplementCard({
    required this.supplement,
    required this.isActive,
    this.isExpired = false,
    required this.isApplied,
    this.onMarkDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isActive && !supplement.isPaused) ? Theme.of(context).primaryColor.withOpacity(0.5) : Colors.grey.shade200,
          width: (isActive && !supplement.isPaused) ? 1.5 : 1.0,
        ),
        boxShadow: (isActive && !supplement.isPaused) ? [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isApplied)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("DONE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    if (isApplied) const SizedBox(width: 8),
                    if (supplement.isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("PAUSED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    if (supplement.isPaused) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        supplement.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: (isExpired || supplement.isPaused) ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isActive ? Colors.green.shade200 : Colors.grey.shade300),
                    ),
                    child: Text(
                      "DOC ${supplement.startDoc} - ${supplement.endDoc}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    onSelected: (val) => _handleAction(context, ref, val),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(supplement.isPaused ? Icons.play_arrow : Icons.pause, size: 20),
                            const SizedBox(width: 8),
                            Text(supplement.isPaused ? "Resume" : "Pause"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text("Edit"),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Delete", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: supplement.items.map<Widget>((item) => Chip(
              label: Text("${item.name}: ${item.quantity} ${item.unit}"),
              backgroundColor: Colors.grey.shade50,
              labelStyle: const TextStyle(fontSize: 11),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            "Schedule: ${supplement.feedingTimes.join(', ')}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          if (supplement.goal != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (supplement.goal == SupplementGoal.growthBoost
                          ? Colors.green
                          : supplement.goal == SupplementGoal.diseasePrevention
                              ? Colors.blue
                              : supplement.goal == SupplementGoal.waterCorrection
                                  ? Colors.teal
                                  : Colors.orange)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  supplement.goal == SupplementGoal.growthBoost
                      ? "Growth Booster"
                      : supplement.goal == SupplementGoal.diseasePrevention
                          ? "Disease Prevention"
                          : supplement.goal == SupplementGoal.waterCorrection
                              ? "Water Correction"
                              : "Stress Recovery",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: supplement.goal == SupplementGoal.growthBoost
                        ? Colors.green
                        : supplement.goal == SupplementGoal.diseasePrevention
                            ? Colors.blue
                            : supplement.goal == SupplementGoal.waterCorrection
                                ? Colors.teal
                                : Colors.orange,
                  ),
                ),
              ),
            ), // ✅ Added missing comma here
          if (isActive && !isApplied && onMarkDone != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("MARK DONE",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddSupplementScreen(supplement: supplement, pondId: supplement.pondIds.first)),
      );
    } else if (action == 'pause') {
      ref.read(supplementProvider.notifier).togglePause(supplement.id);
    } else if (action == 'delete') {
      _showDeleteConfirmation(context, ref);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rm),
        title: const Text("Delete Supplement?"),
        content: Text("Are you sure you want to delete '${supplement.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(supplementProvider.notifier).removeSupplement(supplement.id);
              Navigator.pop(dialogContext);
            },
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}