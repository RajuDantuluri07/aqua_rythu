import 'package:flutter/material.dart';
import '../../core/engines/feed/master_feed_engine.dart';
import '../../core/enums/feed_stage.dart';

class SmartFeedDebugScreen extends StatelessWidget {
  final OrchestratorResult data;

  const SmartFeedDebugScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Feed Decision Debug',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _feedSummaryCard(),
            const SizedBox(height: 12),
            _factorsCard(),
            const SizedBox(height: 12),
            _reasoningCard(),
            const SizedBox(height: 12),
            _contextCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Section 1: Feed Summary ───────────────────────────────────────────────

  Widget _feedSummaryCard() {
    return _card(
      title: 'Feed Summary',
      accent: Colors.greenAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Base Feed', '${data.baseFeed.toStringAsFixed(2)} kg'),
          _row(
            'Final Feed',
            '${data.finalFeed.toStringAsFixed(2)} kg',
            bold: true,
            valueColor: Colors.greenAccent,
          ),
          if (data.correction.isCriticalStop)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '🚨 CRITICAL STOP — No feeding',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // ── Section 2: Factors ────────────────────────────────────────────────────

  Widget _factorsCard() {
    return _card(
      title: 'Factors',
      accent: Colors.amberAccent,
      child: Column(
        children: [
          _factorRow('Tray Factor', data.trayFactor),
          _factorRow('Smart Factor', data.smartFactor,
              hint: 'SmartFeedEngineV2 combined'),
          _factorRow('Raw Combined', data.debugInfo.rawCombinedFactor,
              hint: 'V2 × FCR × intelligence (pre-clamp)'),
          _factorRow('Combined Factor', data.combinedFactor,
              bold: true, hint: 'clamped to [0.70, 1.30]'),
          _factorRow('FCR Factor', data.fcrFactor),
          _factorRow('Environment Factor', data.correction.environmentFactor),
          if ((data.debugInfo.rawCombinedFactor - data.combinedFactor).abs() >
              0.2)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '⚠ High stacking: raw=${data.debugInfo.rawCombinedFactor.toStringAsFixed(3)} '
                'clamped=${data.combinedFactor.toStringAsFixed(3)}',
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _factorRow(String label, double value,
      {String? hint, bool bold = false}) {
    Color color;
    if (value > 1.01) {
      color = Colors.greenAccent;
    } else if (value < 0.99) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.white70;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
                if (hint != null)
                  Text(hint,
                      style:
                          const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Reasoning ──────────────────────────────────────────────────

  Widget _reasoningCard() {
    final reasons = data.correction.factorExplanations;
    final combinedPct = ((data.combinedFactor - 1.0) * 100).round();
    final combinedLabel = combinedPct > 0
        ? '+$combinedPct%'
        : combinedPct < 0
            ? '$combinedPct%'
            : '0%';

    return _card(
      title: 'Reasoning',
      accent: Colors.tealAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.correction.isCriticalStop)
            const Text(
              '🚨 Critical stop — dissolved oxygen too low. No feeding.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            )
          else if (reasons.isEmpty)
            const Text(
              'No adjustments — feed is at base level.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            )
          else ...[
            ...reasons.entries.map((e) {
              final isPositive = e.value.contains('+');
              final isNegative =
                  e.value.contains('-') && !e.value.startsWith('CRITICAL');
              final color = isPositive
                  ? Colors.greenAccent
                  : isNegative
                      ? Colors.orangeAccent
                      : Colors.white54;
              final prefix = isPositive ? '+' : isNegative ? '−' : '•';
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('$prefix ${e.value}',
                    style: TextStyle(color: color, fontSize: 13)),
              );
            }),
            const Divider(color: Colors.white12, height: 20),
            Text(
              'Final adjustment: $combinedLabel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section 4: Context ────────────────────────────────────────────────────

  Widget _contextCard() {
    final stage = data.feedStage;
    final stageName = stage == FeedStage.blind
        ? 'Blind (no corrections)'
        : stage == FeedStage.transitional
            ? 'Transitional (growth only)'
            : 'Intelligent (full)';

    return _card(
      title: 'Context',
      accent: Colors.white38,
      child: Column(
        children: [
          _row('DOC', '${data.debugInfo.doc}'),
          _row('Engine Version', data.engineVersion),
          _row(
            'Sampling present',
            data.intelligence.hasActualData ? 'Yes' : 'No',
            valueColor: data.intelligence.hasActualData
                ? Colors.greenAccent
                : Colors.white54,
          ),
          _row(
            'Smart corrections',
            data.isSmartApplied ? 'Active (DOC > 30)' : 'Not active (DOC ≤ 30)',
            valueColor:
                data.isSmartApplied ? Colors.greenAccent : Colors.white54,
          ),
          _row('Feed stage', stageName),
          _row('Decision', data.decision.action,
              valueColor: _decisionColor(data.decision.action)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _decisionColor(String action) {
    switch (action) {
      case 'Stop Feeding':
        return Colors.redAccent;
      case 'Reduce Feeding':
        return Colors.orangeAccent;
      case 'Increase Feeding':
        return Colors.cyanAccent;
      default:
        return Colors.greenAccent;
    }
  }

  Widget _card(
      {required String title,
      required Widget child,
      Color accent = Colors.white38}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent == Colors.white38 ? Colors.white60 : accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
