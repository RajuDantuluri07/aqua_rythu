import 'package:flutter/material.dart';
import '../enums/seed_type.dart';

class SeedTypeBadge extends StatelessWidget {
  final SeedType seedType;
  final bool compact;

  const SeedTypeBadge({
    super.key,
    required this.seedType,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isHatchery = seedType == SeedType.hatcherySmall;
    final color = isHatchery ? const Color(0xFF2196F3) : const Color(0xFF4CAF50);
    final label = compact
        ? (isHatchery ? 'Hatchery' : 'Nursery')
        : seedType.displayName;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHatchery ? Icons.water_drop_rounded : Icons.eco_rounded,
            size: compact ? 10 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
