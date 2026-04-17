import 'package:flutter/material.dart';
import 'package:aqua_rythu/core/engines/insight_engine.dart';

/// Displays up to 3 insights from InsightEngine, each severity-coloured.
/// Returns SizedBox.shrink() when insights list is empty.
class SmartInsightBox extends StatelessWidget {
  final List<Insight> insights;

  const SmartInsightBox({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      children: insights
          .map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightCard(insight: insight),
              ))
          .toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(insight.severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(colors.icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.action,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.text.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _InsightColors _colorsFor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return const _InsightColors(
          bg: Color(0xFFFFF1F2),
          border: Color(0xFFFCA5A5),
          text: Color(0xFF991B1B),
          icon: '🔴',
        );
      case InsightSeverity.warning:
        return const _InsightColors(
          bg: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
          text: Color(0xFF92400E),
          icon: '⚠️',
        );
      case InsightSeverity.info:
        return const _InsightColors(
          bg: Color(0xFFF0F9FF),
          border: Color(0xFFBAE6FD),
          text: Color(0xFF0C4A6E),
          icon: '🧠',
        );
      case InsightSeverity.positive:
        return const _InsightColors(
          bg: Color(0xFFF0FDF4),
          border: Color(0xFF86EFAC),
          text: Color(0xFF166534),
          icon: '✅',
        );
    }
  }
}

class _InsightColors {
  final Color bg, border, text;
  final String icon;
  const _InsightColors({
    required this.bg,
    required this.border,
    required this.text,
    required this.icon,
  });
}
