import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../subscription_provider.dart';
import '../upgrade_insight_provider.dart';

class PricingCardsSection extends ConsumerWidget {
  const PricingCardsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final isPro = subscriptionState.isPro;
    final isLoading = subscriptionState.isLoading;
    final insight = ref.watch(upgradeLossInsightProvider).value ??
        UpgradeLossInsight.simulated();
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose Your Plan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '₹499 is selected because it recovers fastest from feed savings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.68),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _CropPlanCard(
                  isPro: isPro,
                  isLoading: isLoading,
                  insight: insight,
                  onTap: () => _startUpgrade(
                    context,
                    ref,
                    insight,
                    source: 'pricing_crop',
                    plan: '499_crop',
                  ),
                ),
                _YearlyPlanCard(
                  isPro: isPro,
                  isLoading: isLoading,
                  onTap: () => _startUpgrade(
                    context,
                    ref,
                    insight,
                    source: 'pricing_yearly',
                    plan: '999_year',
                  ),
                ),
              ];

              if (constraints.maxWidth > 740) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(flex: 10, child: cards[1]),
                  ],
                );
              }

              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 14),
                  cards[1],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _TrustChip(icon: Icons.lock_rounded, text: 'Secure payment'),
              _TrustChip(
                  icon: Icons.receipt_long_rounded,
                  text: 'One-time crop payment'),
              _TrustChip(
                  icon: Icons.support_agent_rounded, text: 'Farmer support'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startUpgrade(
    BuildContext context,
    WidgetRef ref,
    UpgradeLossInsight insight, {
    required String source,
    required String plan,
  }) async {
    UpgradeMetrics.trackCtaClick(source: source, plan: plan, insight: insight);
    await ref.read(subscriptionProvider.notifier).upgradeToPro();
    UpgradeMetrics.track('purchase_complete', {
      'source': source,
      'plan': plan,
      'loss_today': insight.roundedLoss,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PRO access unlocked for this demo')),
    );
  }
}

class _CropPlanCard extends StatelessWidget {
  final bool isPro;
  final bool isLoading;
  final UpgradeLossInsight insight;
  final VoidCallback onTap;

  const _CropPlanCard({
    required this.isPro,
    required this.isLoading,
    required this.insight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = Colors.green.shade700;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: upgradeExperimentFlags.highlightPopularPlan
              ? green
              : Colors.green.shade200,
          width: upgradeExperimentFlags.highlightPopularPlan ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'MOST POPULAR',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Smart Crop Plan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹499',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: green,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  '/ crop',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SavingsBox(
            icon: Icons.trending_down_rounded,
            color: green,
            text: 'You save ${insight.cropLossRangeLabel}',
          ),
          const SizedBox(height: 14),
          const _PlanLine(text: 'Smart feed engine'),
          const _PlanLine(text: 'Tray correction and feed optimization'),
          const _PlanLine(text: 'Daily savings and crop ROI tracking'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPro || isLoading ? null : onTap,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.savings_rounded, size: 18),
              label: Text(isPro ? 'Current Plan' : 'Start Saving Feed Today'),
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyPlanCard extends StatelessWidget {
  final bool isPro;
  final bool isLoading;
  final VoidCallback onTap;

  const _YearlyPlanCard({
    required this.isPro,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blue = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: blue.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: blue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: blue.withOpacity(0.18)),
            ),
            child: Text(
              'MULTI CROP SAVER PLAN',
              style: theme.textTheme.labelSmall?.copyWith(
                color: blue,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Multi Crop Saver Plan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹999',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: blue,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text(
                  '/ year',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SavingsBox(
            icon: Icons.auto_awesome_rounded,
            color: blue,
            text: 'Best for 2-3 crops. Save ₹200-₹500 extra.',
          ),
          const SizedBox(height: 14),
          const _PlanLine(text: 'Full access across crops'),
          const _PlanLine(text: 'Best for multiple active ponds'),
          const _PlanLine(text: 'Priority support for growth decisions'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isPro || isLoading ? null : onTap,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(isPro ? 'Current Plan' : 'Unlock Full Access'),
              style: OutlinedButton.styleFrom(
                foregroundColor: blue,
                side: BorderSide(color: blue, width: 1.4),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _SavingsBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  final String text;

  const _PlanLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.green.shade600, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.76),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.68),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
