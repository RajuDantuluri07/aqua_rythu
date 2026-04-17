import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// 7-day Actual vs Ideal sparkline with deviation shading.
///
/// Shading rules:
///   actual > ideal → red tint area (overfeeding)
///   actual < ideal → yellow tint area (underfeeding)
class FeedTrendCard extends StatelessWidget {
  final FeedTrendData data;

  const FeedTrendCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.hasData) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FEED VS IDEAL — LAST 7 DAYS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(actual: data.actual, ideal: data.ideal),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _Dot(color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              const Text('Actual', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              const _Dot(color: Color(0xFFCBD5E1)),
              const SizedBox(width: 4),
              const Text('Ideal', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const Spacer(),
              if (data.insight.isNotEmpty)
                Flexible(
                  child: Text(
                    data.insight,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _SparklinePainter extends CustomPainter {
  final List<double> actual;
  final List<double> ideal;

  const _SparklinePainter({required this.actual, required this.ideal});

  @override
  void paint(Canvas canvas, Size size) {
    if (actual.isEmpty || actual.length != ideal.length) return;

    final all  = [...actual, ...ideal];
    final maxV = all.reduce((a, b) => a > b ? a : b);
    final minV = all.reduce((a, b) => a < b ? a : b);
    final rng  = (maxV - minV).clamp(0.1, double.infinity);

    double toY(double v) => size.height - 4 - ((v - minV) / rng * (size.height - 8));
    double toX(int i)    => actual.length == 1 ? size.width / 2 : i * size.width / (actual.length - 1);

    // ── Deviation fill ────────────────────────────────────────────────────────
    // For each consecutive pair: shade the area between actual and ideal.
    for (int i = 0; i < actual.length - 1; i++) {
      final x0 = toX(i);     final x1 = toX(i + 1);
      final aY0 = toY(actual[i]); final aY1 = toY(actual[i + 1]);
      final iY0 = toY(ideal[i]);  final iY1 = toY(ideal[i + 1]);

      // Determine dominant deviation for this segment
      final avgActual = (actual[i] + actual[i + 1]) / 2;
      final avgIdeal  = (ideal[i]  + ideal[i + 1])  / 2;
      final Color fillColor = avgActual > avgIdeal
          ? const Color(0xFFEF4444).withOpacity(0.08)  // overfeeding → red tint
          : const Color(0xFFF59E0B).withOpacity(0.08); // underfeeding → amber tint

      final fill = Path()
        ..moveTo(x0, aY0)
        ..lineTo(x1, aY1)
        ..lineTo(x1, iY1)
        ..lineTo(x0, iY0)
        ..close();

      canvas.drawPath(fill, Paint()..color = fillColor..style = PaintingStyle.fill);
    }

    // ── Ideal line (grey) ─────────────────────────────────────────────────────
    final idealPath = Path();
    for (int i = 0; i < ideal.length; i++) {
      i == 0 ? idealPath.moveTo(toX(i), toY(ideal[i])) : idealPath.lineTo(toX(i), toY(ideal[i]));
    }
    canvas.drawPath(idealPath, Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke);

    // ── Actual line (green) ───────────────────────────────────────────────────
    final actualPath = Path();
    for (int i = 0; i < actual.length; i++) {
      i == 0 ? actualPath.moveTo(toX(i), toY(actual[i])) : actualPath.lineTo(toX(i), toY(actual[i]));
    }
    canvas.drawPath(actualPath, Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // ── Dots on actual ────────────────────────────────────────────────────────
    final dotPaint = Paint()..color = const Color(0xFF16A34A);
    for (int i = 0; i < actual.length; i++) {
      canvas.drawCircle(Offset(toX(i), toY(actual[i])), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.actual != actual || old.ideal != ideal;
}
