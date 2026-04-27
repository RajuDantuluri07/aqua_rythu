import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../upgrade_insight_provider.dart';

class DynamicSavingsHero extends ConsumerStatefulWidget {
  final VoidCallback? onPrimaryCta;

  const DynamicSavingsHero({super.key, this.onPrimaryCta});

  @override
  ConsumerState<DynamicSavingsHero> createState() => _DynamicSavingsHeroState();
}

class _DynamicSavingsHeroState extends ConsumerState<DynamicSavingsHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _countAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insight = ref.watch(upgradeLossInsightProvider).value ??
        UpgradeLossInsight.simulated();
    final theme = Theme.of(context);
    final lossColor = Colors.red.shade700;
    final orange = Colors.orange.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade700,
            Colors.deepOrange.shade600,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.14),
              blurRadius: 16,
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: lossColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S FEED LOSS",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: lossColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${insight.insightMode} • DOC ${insight.doc}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _RiskBadge(label: insight.riskLabel),
              ],
            ),
            const SizedBox(height: 16),
            _FeedMathRow(insight: insight),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _countAnim,
              builder: (context, _) {
                final animatedLoss = insight.moneyLoss * _countAnim.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${UpgradeLossInsight.formatCurrency(animatedLoss)} wasted today',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: lossColor,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.cropLossRangeLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: orange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  UpgradeMetrics.trackCtaClick(
                    source: 'loss_hero',
                    plan: '499_crop',
                    insight: insight,
                  );
                  widget.onPrimaryCta?.call();
                },
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unlock Smart Feeding -> Save ₹100/day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedMathRow extends StatelessWidget {
  final UpgradeLossInsight insight;

  const _FeedMathRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Feed given',
            value: insight.actualFeedLabel,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Actual needed',
            value: insight.expectedFeedLabel,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'Extra feed',
            value: insight.extraFeedLabel,
            color: Colors.orange.shade800,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;

  const _RiskBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = label == 'HIGH'
        ? Colors.red.shade700
        : label == 'MEDIUM'
            ? Colors.orange.shade700
            : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        '$label RISK',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}
