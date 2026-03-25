import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'harvest_provider.dart';
import '../feed/feed_history_provider.dart';

class HarvestSummaryScreen extends ConsumerWidget {
  final String pondId;
  const HarvestSummaryScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvests = ref.watch(harvestProvider(pondId));
    final notifier = ref.read(harvestProvider(pondId).notifier);
    final pond = ref.watch(farmProvider).farms
        .expand((f) => f.ponds)
        .firstWhere((p) => p.id == pondId);

    final totalYield = harvests.fold(0.0, (sum, h) => sum + h.quantity);
    final totalRevenue = harvests.fold(0.0, (sum, h) => sum + h.revenue);
    final totalExpenses = harvests.fold(0.0, (sum, h) => sum + h.expenses);
    final totalProfit = totalRevenue - totalExpenses;
    
    // Calculate FCR
    final historyMap = ref.watch(feedHistoryProvider);
    final feedLogs = historyMap[pondId] ?? [];
    final totalFeed = feedLogs.fold(0.0, (sum, log) => sum + log.total);
    final fcr = totalYield > 0 ? totalFeed / totalYield : 0.0;

    // Calculate survival % (est)
    final survivingCount = harvests.fold(0.0, (sum, h) => sum + (h.quantity * h.countPerKg));
    final survivalRate = (survivingCount / pond.seedCount * 100).clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.purple.shade700,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text("Harvest Summary", style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade800, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildMainStats(totalYield, totalRevenue, totalProfit),
                   const SizedBox(height: 24),
                   const Text("Performance Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   _buildDetailsGrid(pond, survivalRate, totalExpenses, fcr),
                   const SizedBox(height: 32),
                   _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStats(double yield, double revenue, double profit) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _statRow("Total Yield", "${yield.toStringAsFixed(0)} kg", Icons.scale_rounded, Colors.blue),
          const Divider(height: 32),
          _statRow("Total Revenue", "₹${NumberFormat('#,##,###').format(revenue)}", Icons.currency_rupee_rounded, Colors.green),
          const Divider(height: 32),
          _statRow("Net Profit", "₹${NumberFormat('#,##,###').format(profit)}", Icons.account_balance_wallet_rounded, Colors.purple),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsGrid(Pond pond, double survival, double expenses, double fcr) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _detailCard("FCR", fcr.toStringAsFixed(2), Icons.trending_up_rounded, Colors.blue),
        _detailCard("Duration", "${pond.doc} Days", Icons.calendar_today_rounded, Colors.orange),
        _detailCard("Survival", "${survival.toStringAsFixed(1)}%", Icons.health_and_safety_rounded, Colors.green),
        _detailCard("Expenses", "₹${NumberFormat('#,###').format(expenses)}", Icons.money_off_rounded, Colors.red),
      ],
    );
  }

  Widget _detailCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
               Navigator.pop(context); // Go back to pond dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("BACK TO DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              // TODO: Navigation to full reports
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple.shade700,
              side: BorderSide(color: Colors.purple.shade700, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("VIEW FULL REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
