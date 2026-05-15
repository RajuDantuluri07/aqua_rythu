import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/spacing.dart';
import 'dashboard_metric_card.dart';

class LockedDashboardMetricCard extends StatelessWidget {
  final DashboardMetricCardData data;
  final VoidCallback onUnlock;

  const LockedDashboardMetricCard({
    super.key,
    required this.data,
    required this.onUnlock,
  });

  static const _amber = Color(0xFFF59E0B);
  static const _amberDark = Color(0xFFB45309);
  static const _cardTint = Color(0xFFFFFBF0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnlock,
      child: Opacity(
        opacity: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: _cardTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _amber.withOpacity(0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      data.icon,
                      color: data.color.withOpacity(0.45),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      data.title,
                      style: AppTextStyles.smallLabel.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.lock_rounded, size: 13, color: _amber),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '•••••',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Unlock PRO',
                  style: AppTextStyles.meta.copyWith(
                    color: _amberDark,
                    fontWeight: FontWeight.w600,
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
