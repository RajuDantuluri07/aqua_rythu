import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'supplement_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SupplementMixScreen extends ConsumerWidget {
  final String pondId;
  const SupplementMixScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Get Current Context (DOC)
    final doc = ref.watch(docProvider(pondId));
    final allSupplements = ref.watch(supplementProvider);
    final logs = ref.watch(supplementLogProvider).where((l) => l.pondId == pondId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 2. Filter by Pond
    final pondSupplements = allSupplements.where((s) => 
      s.pondIds.contains(pondId) || s.pondIds.contains('ALL')
    ).toList();

    // 3. Filter by DOC Logic
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddSupplementMessage(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("ACTIVE TODAY (DOC $doc)"),
            if (active.isEmpty) 
              _buildEmptyState(context, "No active supplements for today."),
            ...active.map((s) => _SupplementCard(supplement: s, isActive: true)),

            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader("UPCOMING"),
              ...upcoming.map((s) => _SupplementCard(supplement: s, isActive: false)),
            ],

            if (expired.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader("COMPLETED / EXPIRED"),
              ...expired.map((s) => _SupplementCard(supplement: s, isActive: false, isExpired: true)),
            ],

            if (logs.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader("APPLICATION HISTORY"),
              ...logs.map((log) => _HistoryCard(
                log: log,
                planName: getPlanName(log.supplementId),
              )),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplementMessage(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD NEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showAddSupplementMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Add Supplement feature coming soon")),
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
      child: Column(
        children: [
          Text(msg, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showAddSupplementMessage(context),
            icon: const Icon(Icons.add),
            label: const Text("Add First Supplement"),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SupplementLog log;
  final String? planName;

  const _HistoryCard({required this.log, this.planName});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM, hh:mm a').format(log.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName ?? "Supplement Applied",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                  "${item.quantity}${item.unit}",
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

class _SupplementCard extends StatelessWidget {
  final Supplement supplement;
  final bool isActive;
  final bool isExpired;

  const _SupplementCard({
    required this.supplement,
    required this.isActive,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Theme.of(context).primaryColor.withOpacity(0.5) : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive ? [
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
              Text(
                supplement.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isExpired ? Colors.grey : Colors.black87,
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: supplement.items.map<Widget>((item) => Chip(
              label: Text("${item.name}: ${item.dosePerKg} ${item.unit}"),
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
        ],
      ),
    );
  }
}