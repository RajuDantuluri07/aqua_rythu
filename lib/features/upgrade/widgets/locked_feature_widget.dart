import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../upgrade_to_pro_screen.dart';
import '../subscription_provider.dart';

class LockedFeatureWidget extends ConsumerWidget {
  final String featureName;
  final String featureId;
  final Widget child;
  final String? upgradeMessage;

  const LockedFeatureWidget({
    super.key,
    required this.featureName,
    required this.featureId,
    required this.child,
    this.upgradeMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isPro = subscriptionState.isPro;

    // If user has PRO, just show the normal child
    if (isPro) {
      return child;
    }

    // For FREE users, show locked overlay
    return GestureDetector(
      onTap: () => _showUpgradeDialog(context),
      child: Stack(
        children: [
          // Original widget with reduced opacity
          Opacity(
            opacity: 0.6,
            child: child,
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.workspace_premium),
            const SizedBox(width: 8),
            Text('$featureName (PRO)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upgradeMessage ?? 'Upgrade to PRO to unlock $featureName',
            ),
            const SizedBox(height: 12),
            Text(
              'This feature helps you reduce feed waste and increase profits.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UpgradeToProScreen(),
                ),
              );
            },
            child: const Text('Upgrade to PRO'),
          ),
        ],
      ),
    );
  }
}

// Simple locked feature indicator for inline use
class LockedFeatureIndicator extends ConsumerWidget {
  final String featureName;
  final String featureId;
  final VoidCallback? onTap;

  const LockedFeatureIndicator({
    super.key,
    required this.featureName,
    required this.featureId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isPro = subscriptionState.isPro;

    // Hide for PRO users
    if (isPro) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap ?? () => _navigateToUpgrade(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              '$featureName (PRO)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToUpgrade(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UpgradeToProScreen(),
      ),
    );
  }
}
