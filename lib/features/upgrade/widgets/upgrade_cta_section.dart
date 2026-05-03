import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/models/subscription_model.dart';
import '../subscription_provider.dart';

class UpgradeCTASection extends ConsumerWidget {
  const UpgradeCTASection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isPro = subscriptionState.isPro;
    final theme = Theme.of(context);

    // Hide CTAs for PRO users
    if (isPro) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Primary CTA Button - Outcome-based
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showUpgradeDialog(context, ref);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Start Saving Feed Today",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary CTA Button - Outcome-based
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: theme.colorScheme.outline,
                ),
              ),
              child: Text(
                "Continue with Basic Feeding",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upgrade to PRO'),
        content: const Text(
          'This will redirect you to the payment screen to complete your PRO upgrade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(subscriptionProvider.notifier).initiatePayment(PlanType.PRO);
            },
            child: const Text('Proceed to Payment'),
          ),
        ],
      ),
    );
  }
}
