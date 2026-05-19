import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/spacing.dart';
import '../providers/dashboard_metrics_provider.dart';
import '../providers/dashboard_access_provider.dart';
import '../models/dashboard_metrics_model.dart';
import 'dashboard_metric_card.dart';
import 'locked_dashboard_metric_card.dart';
import '../../upgrade/upgrade_to_pro_screen.dart';
import '../../../routes/app_routes.dart';

class DashboardMetricsGrid extends ConsumerStatefulWidget {
  final String farmId;

  const DashboardMetricsGrid({super.key, required this.farmId});

  @override
  ConsumerState<DashboardMetricsGrid> createState() =>
      _DashboardMetricsGridState();
}

class _DashboardMetricsGridState extends ConsumerState<DashboardMetricsGrid> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatKg(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}t';
    return '${kg.toStringAsFixed(1)} kg';
  }

  String _formatCurrency(double amount) {
    if (amount.abs() >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    }
    if (amount.abs() >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount.abs() >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  String _formatPercent(double pct) => '${pct.toStringAsFixed(1)}%';

  // 8 cards total → 2 pages of 4 (2×2 each)
  List<DashboardMetricCardData> _buildCards(DashboardMetrics m, bool isPro) {
    final hasPrices = m.feedCost > 0 || m.revenuePotential > 0;

    DashboardMetricCardData pro({
      required String title,
      required String value,
      required String subtitle,
      required IconData icon,
      required Color color,
    }) =>
        DashboardMetricCardData(
          title: title,
          value: value,
          subtitle: subtitle,
          icon: icon,
          color: color,
          access: DashboardMetricAccess.pro,
          isLocked: !isPro,
        );

    return [
      // ── Page 1 ──────────────────────────────────────────────────────────────
      DashboardMetricCardData(
        title: 'Estimated Biomass',
        value: m.estimatedBiomassKg > 0 ? _formatKg(m.estimatedBiomassKg) : '—',
        subtitle: 'from ${m.activePonds} pond${m.activePonds != 1 ? 's' : ''}',
        icon: Icons.scale_rounded,
        color: const Color(0xFF2A6BD1),
      ),
      DashboardMetricCardData(
        title: 'Total Feed',
        value: _formatKg(m.totalFeedKg),
        subtitle: 'cumulative all ponds',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFFE53935),
      ),
      DashboardMetricCardData(
        title: 'Survival Rate',
        value: _formatPercent(m.survivalPercent),
        subtitle: 'DOC-based estimate',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFF59E0B),
      ),
      pro(
        title: 'Revenue Potential',
        value: hasPrices && m.revenuePotential > 0
            ? _formatCurrency(m.revenuePotential)
            : '—',
        subtitle: 'estimated harvest value',
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF22C55E),
      ),
      // ── Page 2 ──────────────────────────────────────────────────────────────
      pro(
        title: 'Feed Cost',
        value: hasPrices && m.feedCost > 0 ? _formatCurrency(m.feedCost) : '—',
        subtitle: 'total feed expenditure',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFC75B1E),
      ),
      pro(
        title: 'Production Cost',
        value: hasPrices && m.productionCost > 0
            ? _formatCurrency(m.productionCost)
            : '—',
        subtitle: 'feed + other expenses',
        icon: Icons.factory_rounded,
        color: const Color(0xFF6B7280),
      ),
      pro(
        title: m.estimatedProfit >= 0 ? 'Estimated Profit' : 'Estimated Loss',
        value: hasPrices && m.revenuePotential > 0
            ? _formatCurrency(m.estimatedProfit.abs())
            : '—',
        subtitle: m.estimatedProfit >= 0 ? 'revenue minus costs' : 'costs exceed revenue',
        icon: Icons.account_balance_wallet_rounded,
        color: m.estimatedProfit >= 0
            ? const Color(0xFF14613B)
            : const Color(0xFFE53935),
      ),
      pro(
        title: 'Profit Margin',
        value: hasPrices && m.revenuePotential > 0
            ? _formatPercent(m.profitMargin)
            : '—',
        subtitle: 'net margin',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF0B8F5A),
      ),
    ];
  }

  void _openUpgrade(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeToProScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(dashboardMetricsProvider(widget.farmId));
    final isPro = ref.watch(dashboardAccessProvider).isProUser;

    if (metrics.activePonds == 0) {
      return const _EmptyState();
    }

    final cards = _buildCards(metrics, isPro);
    const cardsPerPage = 4;
    final pageCount = (cards.length / cardsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with label + page dots ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FARM INTELLIGENCE',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              Row(
                children: List.generate(pageCount, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // ── Swipeable pages ───────────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = Spacing.sm;
              final cardWidth = (constraints.maxWidth - gap) / 2;
              final cardHeight = cardWidth / 1.3;
              final gridHeight = cardHeight * 2 + gap;

              return SizedBox(
                height: gridHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, pageIndex) {
                    final start = pageIndex * cardsPerPage;
                    final end =
                        (start + cardsPerPage).clamp(0, cards.length);
                    final pageCards = cards.sublist(start, end);

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: pageCards.length,
                      itemBuilder: (_, i) {
                        final card = pageCards[i];
                        if (card.isLocked) {
                          return LockedDashboardMetricCard(
                            data: card,
                            onUnlock: () => _openUpgrade(context),
                          );
                        }
                        return DashboardMetricCard(data: card);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.water_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: Spacing.sm),
            Text(
              'No active ponds yet',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Start your first pond to see farm insights',
              style: AppTextStyles.secondaryText
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.addPond),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Pond'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
