import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// 3 KPI tiles: Fed Today · Avg Weight · FCR.
/// Shows "Est." suffix when values come from estimation, not real samples.
class KpiRow extends StatelessWidget {
  final KPIData data;

  const KpiRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Tile(
          label: 'FED TODAY',
          value: data.feedToday > 0 ? '${data.feedToday.toStringAsFixed(1)} kg' : '--',
          sub: data.plannedToday > 0 ? 'of ${data.plannedToday.toStringAsFixed(1)} kg' : 'DOC ${data.doc}',
          color: data.feedToday > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
        )),
        const SizedBox(width: 8),
        Expanded(child: _Tile(
          label: data.abwIsEstimated ? 'ABW (EST.)' : 'AVG WEIGHT',
          value: data.currentAbw > 0 ? '${data.currentAbw.toStringAsFixed(1)} g' : '--',
          sub: 'DOC ${data.doc}',
          color: const Color(0xFF7C3AED),
          dimmed: data.abwIsEstimated,
        )),
        const SizedBox(width: 8),
        Expanded(child: _Tile(
          label: data.fcrIsEstimated ? 'FCR (EST.)' : 'FCR LIVE',
          value: data.fcr > 0 ? data.fcr.toStringAsFixed(2) : '--',
          sub: _fcrLabel(data.fcr),
          color: _fcrColor(data.fcr),
          dimmed: data.fcrIsEstimated,
        )),
      ],
    );
  }

  String _fcrLabel(double v) {
    if (v <= 0)   return 'No data';
    if (v <= 1.2) return '✅ Excellent';
    if (v <= 1.4) return '🟡 Acceptable';
    return '🔴 Reduce feed';
  }

  Color _fcrColor(double v) {
    if (v <= 0)   return const Color(0xFF94A3B8);
    if (v <= 1.2) return const Color(0xFF16A34A);
    if (v <= 1.4) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool dimmed;

  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: dimmed ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: dimmed ? color.withOpacity(0.5) : color,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
