import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profit_provider.dart';
import 'profit_calculator_screen.dart';
import '../harvest/harvest_record_screen.dart';
import '../upgrade/subscription_provider.dart';
import '../upgrade/upgrade_to_pro_screen.dart';

class ProfitSummaryScreen extends ConsumerWidget {
  final String cropId;
  final String farmId;

  const ProfitSummaryScreen({
    super.key,
    required this.cropId,
    required this.farmId,
  });

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isProProvider)) {
      return _ProRequired(
        title: 'Profit & Cost Summary',
        onUpgrade: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UpgradeToProScreen()),
        ),
      );
    }

    final profitAsync = ref.watch(profitProvider(cropId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Cost Summary'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfitCalculatorScreen(
                    cropId: cropId,
                    farmId: farmId,
                  ),
                ),
              );
            },
            tooltip: 'Profit Calculator',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(profitProvider(cropId).notifier).refresh();
            },
          ),
        ],
      ),
      body: profitAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading profit data',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(profitProvider(cropId).notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          final todayCosts = summary['today'] as Map<String, dynamic>;
          final totalCosts = summary['total'] as Map<String, dynamic>;
          final hasHarvest = summary['has_harvest'] as bool? ?? false;
          final finalProfitData =
              summary['final_profit'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Final Profit Card (if harvest exists)
                if (hasHarvest && finalProfitData != null) ...[
                  _buildProfitCard(
                    title: 'Final Profit',
                    icon: Icons.trending_up,
                    iconColor: Colors.green[600]!,
                    profitData: finalProfitData,
                    isFinal: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Today's Summary Card
                _buildSummaryCard(
                  title: 'Today\'s Costs',
                  icon: Icons.today,
                  iconColor: Colors.blue[600]!,
                  costs: todayCosts,
                  isToday: true,
                ),
                const SizedBox(height: 16),

                // Total Summary Card
                _buildSummaryCard(
                  title: 'Total Costs (All Time)',
                  icon: Icons.account_balance,
                  iconColor: Colors.green[600]!,
                  costs: totalCosts,
                  isToday: false,
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            // Harvest Record Button (only show if no harvest exists)
                            if (!hasHarvest)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            HarvestRecordScreen(
                                          cropId: cropId,
                                          farmId: farmId,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.agriculture),
                                  label: const Text('Record Harvest'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),

                            // Action Buttons Row
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProfitCalculatorScreen(
                                            cropId: cropId,
                                            farmId: farmId,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.calculate),
                                    label: const Text('Calculate Profit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(profitProvider(cropId).notifier)
                                          .refresh();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Info Card
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem('Feed Cost',
                            'Calculated from daily feed usage and inventory prices'),
                        _buildInfoItem('Other Cost',
                            'All other expenses like labour, electricity, diesel, etc.'),
                        _buildInfoItem('Total Cost', 'Feed Cost + Other Cost'),
                        _buildInfoItem('Profit',
                            'Revenue (Harvest Weight × Selling Price) - Total Cost'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfitCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic> profitData,
    required bool isFinal,
  }) {
    final feedCost = profitData['feed_cost'] as double;
    final otherCost = profitData['other_cost'] as double;
    final totalCost = profitData['total_cost'] as double;
    final revenue = profitData['revenue'] as double;
    final profit = profitData['profit'] as double;

    return Card(
      elevation: 4,
      color: isFinal ? Colors.green[50] : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Revenue
            _buildCostRow('Revenue', revenue, Colors.green[600]!),
            const SizedBox(height: 12),

            // Cost Breakdown
            _buildCostRow('Feed Cost', feedCost, Colors.orange[600]!),
            _buildCostRow('Other Cost', otherCost, Colors.grey[600]!),
            const Divider(height: 24),

            // Total Cost
            _buildCostRow(
              'Total Cost',
              totalCost,
              Colors.black,
              isBold: true,
              isLarge: true,
            ),
            const Divider(height: 24),

            // Profit
            _buildCostRow(
              'PROFIT',
              profit,
              profit >= 0 ? Colors.green[700]! : Colors.red[700]!,
              isBold: true,
              isLarge: true,
            ),

            if (profit >= 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Profit margin: ${((profit / revenue) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Map<String, dynamic> costs,
    required bool isToday,
  }) {
    final feedCost = costs['feed_cost'] as double;
    final otherCost = costs['other_cost'] as double;
    final totalCost = costs['total_cost'] as double;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cost Breakdown
            _buildCostRow('Feed Cost', feedCost, Colors.orange[600]!),
            const SizedBox(height: 12),
            _buildCostRow('Other Cost', otherCost, Colors.grey[600]!),
            const Divider(height: 24),

            // Total Cost
            _buildCostRow(
              'Total Cost',
              totalCost,
              Colors.black,
              isBold: true,
              isLarge: true,
            ),

            if (isToday && totalCost > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Today\'s spending: ${_formatCurrency(totalCost)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color,
      {bool isBold = false, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          _formatCurrency(amount),
          style: TextStyle(
            fontSize: isLarge ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProRequired extends StatelessWidget {
  final String title;
  final VoidCallback onUpgrade;

  const _ProRequired({required this.title, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8A33D), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 36, color: Color(0xFFE8A33D)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PRO Feature',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0E1A1F)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Track exact costs, FCR, and profit per crop cycle.\nKnow what you made before the next season starts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5560),
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('Upgrade to PRO — ₹999/crop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A33D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later',
                    style: TextStyle(color: Color(0xFF4A5560))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
