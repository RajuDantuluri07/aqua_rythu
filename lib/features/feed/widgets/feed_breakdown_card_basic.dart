import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/spacing.dart';
import '../../pond/enums/seed_type.dart';
import '../models/feed_explanation.dart';

/// BASIC MODE: Shows only Base Feed, Tray Adjustment, and Final Feed
/// Used for DOC 15-30 when tray data exists (early engagement phase)
class BasicFeedBreakdownCard extends StatelessWidget {
  final FeedExplanation explanation;

  const BasicFeedBreakdownCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(height: 1, indent: Spacing.lg, endIndent: Spacing.lg, color: AppColors.border),
          _buildBasicBreakdown(context),
          _buildFinalRow(context),
          if (explanation.savingsRupees != null && explanation.savingsRupees! > 0)
            _buildSavingsBanner(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isHatchery = explanation.seedType == SeedType.hatcherySmall;
    final accentColor = isHatchery ? AppColors.primary : AppColors.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 14, Spacing.lg, 12),
      child: Row(
        children: [
          Icon(Icons.auto_graph_rounded, color: accentColor, size: 18),
          const SizedBox(width: Spacing.sm),
          const Text(
            'Feed Adjustment (Tray Based)',
            style: AppTextStyles.subheading,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'DOC ${explanation.doc}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicBreakdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Column(
        children: [
          _breakdownRow(
            label: 'Base Feed',
            value: '${explanation.baseFeed.toStringAsFixed(2)} kg',
            sublabel: explanation.isSeedTablePhase
                ? '${explanation.seedType.displayName} table · DOC ${explanation.doc}'
                : 'Fallback curve · DOC ${explanation.doc}',
            icon: Icons.set_meal_rounded,
            iconColor: AppColors.textSecondary,
          ),
          const SizedBox(height: Spacing.md),
          _breakdownRow(
            label: 'Tray Adjustment',
            value: _signedPercent(explanation.trayImpact),
            sublabel: explanation.trayLabel,
            icon: Icons.grid_view_rounded,
            iconColor: _factorColor(explanation.trayImpact),
            valueColor: _factorColor(explanation.trayImpact),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: Spacing.sm),
          Text(
            'Final Feed Today',
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          Text(
            '${explanation.finalFeed.toStringAsFixed(2)} kg',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsBanner(BuildContext context) {
    final savings = explanation.savingsRupees!.round();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You saved ₹$savings today by avoiding overfeeding',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required String value,
    required String sublabel,
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  String _signedPercent(double factor) {
    final pct = (factor * 100).round();
    if (pct == 0) return '0%';
    return pct > 0 ? '+$pct%' : '$pct%';
  }

  Color _factorColor(double factor) {
    if (factor < 0) return const Color(0xFFE53935);
    if (factor > 0) return const Color(0xFF43A047);
    return Colors.grey.shade500;
  }
}
