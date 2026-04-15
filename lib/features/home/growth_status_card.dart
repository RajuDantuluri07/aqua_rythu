import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// ABW vs ideal with colored status and delta %.
class GrowthStatusCard extends StatelessWidget {
  final GrowthData data;

  const GrowthStatusCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: data.hasData ? _withData() : _noData(),
    );
  }

  Widget _noData() {
    return const Row(
      children: [
        Icon(Icons.scale_outlined, size: 18, color: Color(0xFF94A3B8)),
        SizedBox(width: 10),
        Text(
          'No growth sample yet — add a sample to track ABW',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _withData() {
    final ratio = data.currentAbw / data.expectedAbw.clamp(0.001, double.infinity);
    final cfg = _config(ratio);
    final pct = ((ratio - 1.0) * 100).round();
    final pctStr = pct >= 0 ? '+$pct%' : '$pct%';

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GROWTH — ${cfg.label}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: cfg.color,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.currentAbw.toStringAsFixed(1)}g actual  ·  ${data.expectedAbw.toStringAsFixed(1)}g ideal at DOC ${data.doc}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          pctStr,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cfg.color),
        ),
      ],
    );
  }

  _GrowthCfg _config(double ratio) {
    if (ratio < 0.85) return const _GrowthCfg('Slow',   Color(0xFFDC2626));
    if (ratio < 1.10) return const _GrowthCfg('Medium', Color(0xFFD97706));
    if (ratio < 1.25) return const _GrowthCfg('Good',   Color(0xFF16A34A));
    return                    const _GrowthCfg('Fast',   Color(0xFF2563EB));
  }
}

class _GrowthCfg {
  final String label;
  final Color color;
  const _GrowthCfg(this.label, this.color);
}
