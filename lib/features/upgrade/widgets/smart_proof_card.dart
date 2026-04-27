import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/upgrade_stage.dart';
import '../../farm/farm_provider.dart';

class SmartProofCard extends ConsumerWidget {
  const SmartProofCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    // Get data for smart proof card
    int doc = 0;
    SmartValueData? smartValueData;

    if (currentFarm != null && currentFarm.ponds.isNotEmpty) {
      final firstPond = currentFarm.ponds.first;
      doc = firstPond.doc;

      // For demonstration, create mock smart value data when DOC >= 30
      if (doc >= 30) {
        smartValueData = SmartValueData(
          savingsAmount: 120 + (doc % 50),
          reductionPercent: 5 + (doc % 10),
          confidenceLevel: 'high',
          reason: 'Tray analysis shows leftover feed',
        );
      }
    }

    // Hide card for DOC < 30 or no smart data
    if (doc < 30 || smartValueData == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_down,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Tray leftover detected → reduce feed by ${smartValueData.reductionPercent}%",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Comparison
          Row(
            children: [
              // Without AquaRythu
              Expanded(
                child: _buildComparisonColumn(
                  context,
                  "Without AquaRythu:",
                  "Waste ₹${smartValueData.savingsAmount}",
                  Colors.red.shade600,
                  Icons.money_off,
                ),
              ),

              const SizedBox(width: 16),

              // With AquaRythu
              Expanded(
                child: _buildComparisonColumn(
                  context,
                  "With AquaRythu:",
                  "Saved ₹${smartValueData.savingsAmount}",
                  Colors.green.shade600,
                  Icons.savings,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confidence level
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  "Confidence: ${smartValueData.confidenceLevel}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.withOpacity(0.8),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
