import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// Feed waste insight with suggested correction factor.
/// Returns SizedBox.shrink() when no tray data exists.
class WasteInsightCard extends StatelessWidget {
  final WasteData data;

  const WasteInsightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.hasData) return const SizedBox.shrink();

    final cfg = _config(data.wastePercent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(cfg.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FEED WASTE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cfg.textColor,
                  ),
                ),
                // Show suggested correction only when non-neutral
                if (data.suggestedFeedFactor < 0.99) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Suggested next feed: ×${data.suggestedFeedFactor.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${data.wastePercent.round()}%',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: cfg.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _Cfg _config(double pct) {
    if (pct < 5)  return const _Cfg('✅', Color(0xFF16A34A));
    if (pct < 10) return const _Cfg('🟡', Color(0xFFD97706));
    if (pct < 20) return const _Cfg('🟠', Color(0xFFEA580C));
    return               const _Cfg('⚠️', Color(0xFFDC2626));
  }
}

class _Cfg {
  final String icon;
  final Color textColor;
  const _Cfg(this.icon, this.textColor);
}
