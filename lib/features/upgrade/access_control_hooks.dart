import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'subscription_provider.dart';
import 'upgrade_to_pro_screen.dart';

class AccessControlHooks {
  static bool canAccessFeature(WidgetRef ref, String featureId) {
    final subscriptionState = ref.read(subscriptionProvider);
    final feature = PlanFeatures.getFeatureById(featureId);

    if (feature == null) return true; // Unknown features allowed by default

    // FREE users can access free features
    if (!feature.isProFeature) return true;

    // PRO features require PRO subscription
    return subscriptionState.isPro;
  }

  static void showUpgradeDialog(BuildContext context, String featureId) {
    final feature = PlanFeatures.getFeatureById(featureId);
    final message =
        feature?.upgradeMessage ?? 'Upgrade to PRO to access this feature';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('PRO Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            if (feature != null) ...[
              Text(
                feature.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                feature.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
            ],
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

  static Widget withProAccessControl({
    required WidgetRef ref,
    required String featureId,
    required Widget child,
    Widget? lockedChild,
  }) {
    final canAccess = canAccessFeature(ref, featureId);

    if (canAccess) {
      return child;
    }

    return lockedChild ?? _buildLockedWidget(ref, featureId, child);
  }

  static Widget _buildLockedWidget(
      WidgetRef ref, String featureId, Widget child) {
    return Consumer(
      builder: (context, ref, _) => GestureDetector(
        onTap: () => showUpgradeDialog(context, featureId),
        child: Opacity(
          opacity: 0.6,
          child: Stack(
            children: [
              child,
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'PRO Feature',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tap to upgrade',
                          style: TextStyle(
                            color: Colors.white,
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
        ),
      ),
    );
  }
}

// Extension for easier access control
extension AccessControlExtension on WidgetRef {
  bool canAccess(String featureId) =>
      AccessControlHooks.canAccessFeature(this, featureId);

  void requirePro(String featureId, {VoidCallback? onBlocked}) {
    if (!AccessControlHooks.canAccessFeature(this, featureId)) {
      onBlocked?.call();
    }
  }
}

// Pro Feature Wrapper Widget
class ProFeatureWrapper extends ConsumerWidget {
  final String featureId;
  final Widget child;
  final Widget? lockedChild;
  final VoidCallback? onUpgradeRequested;

  const ProFeatureWrapper({
    super.key,
    required this.featureId,
    required this.child,
    this.lockedChild,
    this.onUpgradeRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccessControlHooks.withProAccessControl(
      ref: ref,
      featureId: featureId,
      child: child,
      lockedChild: lockedChild,
    );
  }
}

// Feature Constants for easy reference
class FeatureIds {
  static const String smartFeedEngine = 'smart_feed_engine';
  static const String trayBasedCorrection = 'tray_based_correction';
  static const String growthIntelligence = 'growth_intelligence';
  static const String profitTracking = 'profit_tracking';
  static const String multiPondComparison = 'multi_pond_comparison';
  static const String cropReport = 'crop_report';
  static const String workerRoles = 'worker_roles';
}
