import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/upgrade_stage.dart';
import '../../farm/farm_provider.dart';

class DynamicHeaderWidget extends ConsumerWidget {
  const DynamicHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    // Get the first pond's DOC for simplicity - in real app might average or use selected pond
    int doc = 0;
    SmartValueData? smartValueData;

    if (currentFarm != null && currentFarm.ponds.isNotEmpty) {
      final firstPond = currentFarm.ponds.first;
      // Extract DOC from pond data using the getter
      doc = firstPond.doc;

      // For demonstration, create mock smart value data when DOC >= 30
      if (doc >= 30) {
        // In real implementation, this would come from actual feed engine calculations
        smartValueData = SmartValueData(
          savingsAmount: 120 + (doc % 50), // Variable savings based on DOC
          reductionPercent: 5 + (doc % 10), // Variable reduction 5-14%
          confidenceLevel: 'high',
          reason: 'Tray analysis shows leftover feed',
        );
      }
    }

    final headerMessage =
        UpgradeStageCalculator.getHeaderMessage(doc, smartValueData);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          // 🔥 Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium,
              size: 48,
              color: theme.colorScheme.onPrimary,
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            headerMessage.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            headerMessage.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
