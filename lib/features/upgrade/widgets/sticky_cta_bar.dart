import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../subscription_provider.dart';
import '../upgrade_insight_provider.dart';

class StickyCTABar extends ConsumerStatefulWidget {
  const StickyCTABar({super.key});

  @override
  ConsumerState<StickyCTABar> createState() => _StickyCTABarState();
}

class _StickyCTABarState extends ConsumerState<StickyCTABar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final insight = ref.watch(upgradeLossInsightProvider).value ??
        UpgradeLossInsight.simulated();
    final theme = Theme.of(context);

    if (subscriptionState.isPro) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.red.shade100),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              ),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.red.shade700,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You are losing ${insight.lossTodayLabel} today',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: subscriptionState.isLoading
                  ? null
                  : () async {
                      UpgradeMetrics.trackCtaClick(
                        source: 'sticky_bar',
                        plan: '499_crop',
                        insight: insight,
                      );
                      await ref
                          .read(subscriptionProvider.notifier)
                          .upgradeToPro();
                      UpgradeMetrics.track('purchase_complete', {
                        'source': 'sticky_bar',
                        'plan': '499_crop',
                        'loss_today': insight.roundedLoss,
                      });
                    },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Save Feed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
