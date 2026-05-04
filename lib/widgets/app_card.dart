import 'package:flutter/material.dart';
import 'package:aqua_rythu/core/theme/app_theme.dart';
import 'package:aqua_rythu/core/constants/spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;

  const AppCard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
