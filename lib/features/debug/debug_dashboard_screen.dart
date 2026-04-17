import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/master_feed_engine.dart';
import '../../core/engines/feed_decision_engine.dart';
import '../../core/engines/feed_intelligence_engine.dart';
import '../../core/engines/feed_orchestrator.dart';
import '../../core/enums/feed_stage.dart';
import 'debug_dashboard_provider.dart';

class DebugDashboardScreen extends ConsumerStatefulWidget {
  final String pondId;

  const DebugDashboardScreen({super.key, required this.pondId});

  @override
  ConsumerState<DebugDashboardScreen> createState() =>
      _DebugDashboardScreenState();
}

class _DebugDashboardScreenState extends ConsumerState<DebugDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(debugDashboardProvider(widget.pondId).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debugDashboardProvider(widget.pondId));
    final notifier =
        ref.read(debugDashboardProvider(widget.pondId).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Feed Pipeline Debug',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Reload from DB',
            onPressed: notifier.load,
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white38))
          : state.error != null
              ? _ErrorView(error: state.error!)
              : state.debugData == null
                  ? const _EmptyView()
                  : _Body(pondId: widget.pondId, state: state),
    );
  }
}

// ── BODY ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  final String pondId;
  final DebugDashboardState state;

  const _Body({required this.pondId, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(debugDashboardProvider(pondId).notifier);
    final d = state.debugData!;
    final intel = state.intelligence;
    final result = state.orchestratorResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── PIPELINE BANNER ────────────────────────────────────────────────
        _PipelineBanner(result: result),
        const SizedBox(height: 12),

        // ── 1. POND CONTEXT ────────────────────────────────────────────────
        _Section(
          title: '1. Pond Context',
          children: [
            _Row(
              'Feed Stage',
              result != null ? _stageName(result.feedStage) : '—',
              bold: true,
              valueColor: _stageColor(result?.feedStage),
            ),
            _Row('Pond', state.pondName),
            _Row('DOC', '${state.doc}'),
            _Row('Stocking', state.stockingType.toUpperCase()),
            _Row('Density', '${state.density} shrimp'),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2. STAGE 1: MASTER FEED ENGINE (base) ─────────────────────────
        _Section(
          title: '2. Stage 1 — MasterFeedEngine (Base Feed)',
          accent: Colors.cyanAccent,
          children: [
            _Row('Base (per 100K)', '${d.baseFeed.toStringAsFixed(3)} kg',
                hint: _baseHint(state.stockingType, state.doc)),
            _Row('After Density', '${d.adjustedFeed.toStringAsFixed(3)} kg',
                hint: '× (${state.density} / 100000)'),
            _Row('Tray Factor', d.trayFactor.toStringAsFixed(2),
                valueColor: _trayColor(d.trayFactor)),
            _Row('Tray Reason', d.trayStatusReason,
                valueColor: Colors.white54),
            _Row('Raw Feed', '${d.rawFeed.toStringAsFixed(3)} kg'),
            _Row('Expected Feed', '${d.finalFeed.toStringAsFixed(3)} kg',
                bold: true, valueColor: Colors.cyanAccent),
          ],
        ),
        const SizedBox(height: 12),

        // ── 3. STAGE 2: INTELLIGENCE ENGINE ───────────────────────────────
        _Section(
          title: '3. Stage 2 — FeedIntelligenceEngine',
          accent: _statusColor(intel?.status),
          children: [
            _Row('Expected Feed', intel != null
                ? '${intel.expectedFeed.toStringAsFixed(3)} kg'
                : '—'),
            _Row('Actual (yesterday)', intel?.actualFeed != null
                ? '${intel!.actualFeed!.toStringAsFixed(3)} kg'
                : 'No data'),
            _Row('Deviation',
                intel?.deviation != null
                    ? '${intel!.deviation! >= 0 ? '+' : ''}${intel.deviation!.toStringAsFixed(3)} kg'
                    : '—',
                valueColor: _deviationColor(intel?.deviation)),
            _Row('Deviation %',
                intel?.deviationLabel ?? '—',
                valueColor: _deviationColor(intel?.deviation)),
            _Row('Status',
                intel?.statusLabel ?? '—',
                bold: true,
                valueColor: _statusColor(intel?.status)),
          ],
        ),
        const SizedBox(height: 12),

        // ── 4. STAGE 3: SMART FEED ENGINE (corrections) ───────────────────
        _Section(
          title: '4. Stage 3 — SmartFeedEngine (Corrections)',
          accent: Colors.amberAccent,
          children: [
            _Row('Tray Factor',
                result != null
                    ? result.correction.trayFactor.toStringAsFixed(3)
                    : '—',
                valueColor: _factorColor(result?.correction.trayFactor)),
            _Row('Growth Factor',
                result != null
                    ? result.correction.growthFactor.toStringAsFixed(3)
                    : '—',
                valueColor: _factorColor(result?.correction.growthFactor)),
            _Row('Sampling Factor',
                result != null
                    ? result.correction.samplingFactor.toStringAsFixed(3)
                    : '—',
                valueColor: _factorColor(result?.correction.samplingFactor)),
            _Row('Environment Factor',
                result != null
                    ? result.correction.environmentFactor.toStringAsFixed(3)
                    : '—',
                valueColor: _factorColor(result?.correction.environmentFactor)),
            _Row('FCR Factor',
                result != null
                    ? result.correction.fcrFactor.toStringAsFixed(3)
                    : '—',
                hint: '(only with valid sampling)',
                valueColor: _factorColor(result?.correction.fcrFactor)),
            _Row('Intelligence Factor',
                result != null
                    ? result.correction.intelligenceFactor.toStringAsFixed(3)
                    : '—',
                hint: '(deviation enforcement)',
                valueColor: _factorColor(result?.correction.intelligenceFactor)),
            _Row('Combined Factor',
                result != null
                    ? result.correction.combinedFactor.toStringAsFixed(3)
                    : '—',
                bold: true,
                valueColor: Colors.amberAccent),
          ],
        ),
        const SizedBox(height: 12),

        // ── 5. FINAL OUTPUT ────────────────────────────────────────────────
        _Section(
          title: '5. Final Feed Recommendation',
          accent: Colors.greenAccent,
          children: [
            _Row('Base Feed', '${d.finalFeed.toStringAsFixed(3)} kg'),
            _Row('× Combined Factor',
                result != null
                    ? '× ${result.correction.combinedFactor.toStringAsFixed(3)}'
                    : '—'),
            _Row('= Final Feed',
                result != null
                    ? '${result.finalFeed.toStringAsFixed(3)} kg'
                    : '${d.finalFeed.toStringAsFixed(3)} kg',
                bold: true,
                valueColor: Colors.greenAccent),
            if (result != null && result.correction.isCriticalStop)
              const _Row('⚠ CRITICAL STOP', 'No feeding',
                  valueColor: Colors.redAccent, bold: true),
          ],
        ),
        const SizedBox(height: 12),

        // ── 5b. DECISION OUTPUT ───────────────────────────────────────────
        if (result != null)
          _Section(
            title: '5b. Decision Output (FeedDecisionEngine)',
            accent: Colors.purpleAccent,
            children: [
              _Row(
                'Action',
                result.decision.action,
                bold: true,
                valueColor: _decisionColor(result.decision.action),
              ),
              _Row(
                'Delta',
                result.decision.formattedDelta,
                hint: 'finalFeed − baseFeed',
                valueColor: _decisionColor(result.decision.action),
              ),
              _Row(
                'Reason',
                result.decision.reason,
                valueColor: Colors.white70,
              ),
              if (result.decision.recommendations.isNotEmpty) ...[
                const SizedBox(height: 6),
                const _Row('Recommendations', ''),
                ...result.decision.recommendations.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      r,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              if (result.decision.decisionTrace.isNotEmpty) ...[
                const SizedBox(height: 6),
                const _Row('Trace', ''),
                ...result.decision.decisionTrace.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '  $t',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        if (result != null) const SizedBox(height: 12),

        // ── 6. SAFETY CLAMP ────────────────────────────────────────────────
        _Section(
          title: '6. Safety Clamp (MasterFeedEngine)',
          children: [
            _Row('Min Allowed', '${d.minFeed.toStringAsFixed(3)} kg',
                hint: 'adjustedBase × 0.70'),
            _Row('Max Allowed', '${d.maxFeed.toStringAsFixed(3)} kg',
                hint: 'adjustedBase × 1.30'),
            _Row(
              'Clamped',
              d.isClamped ? 'YES ⚠' : 'NO',
              valueColor:
                  d.isClamped ? Colors.orangeAccent : Colors.greenAccent,
            ),
            _Row('Input Clamped', d.wasInputClamped ? 'YES ⚠' : 'NO',
                valueColor: d.wasInputClamped
                    ? Colors.orangeAccent
                    : Colors.white54),
          ],
        ),
        const SizedBox(height: 12),

        // ── 7. TRAY SIMULATION ─────────────────────────────────────────────
        _Section(
          title: '7. Tray Data',
          children: [
            _Row('Tray Active', d.trayActive ? 'YES' : 'NO',
                valueColor:
                    d.trayActive ? Colors.greenAccent : Colors.white38),
            _Row(
              'Leftover (real)',
              state.latestLeftover != null
                  ? '${state.latestLeftover!.toStringAsFixed(0)}%'
                  : 'N/A',
            ),
            if (state.simulatedLeftover != null)
              _Row(
                'Leftover (simulated)',
                '${state.simulatedLeftover!.toStringAsFixed(0)}%',
                valueColor: Colors.amberAccent,
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ── ACTION BUTTONS ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recalculate'),
                onPressed: notifier.recalculate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Simulate Tray'),
                onPressed: () => _showSimulateDialog(context, ref, state),
              ),
            ),
          ],
        ),
        if (state.simulatedLeftover != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: notifier.clearSimulation,
            child: const Text('Clear Simulation',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  void _showSimulateDialog(
      BuildContext context, WidgetRef ref, DebugDashboardState state) {
    double sliderValue = state.simulatedLeftover ?? state.latestLeftover ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final factor = MasterFeedEngine.trayFactor(sliderValue);
            final factorColor = _trayColor(factor);

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Simulate Tray Leftover',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${sliderValue.toStringAsFixed(0)}% leftover',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tray Factor: ${factor.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: factorColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: sliderValue,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: factorColor,
                    label: '${sliderValue.toStringAsFixed(0)}%',
                    onChanged: (v) => setDlgState(() => sliderValue = v),
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    children: [
                      _LegendChip(label: '0% → 1.1×', color: Colors.greenAccent),
                      _LegendChip(label: '≤10% → 1.0×', color: Colors.white54),
                      _LegendChip(label: '≤25% → 0.9×', color: Colors.orangeAccent),
                      _LegendChip(label: '>25% → 0.75×', color: Colors.redAccent),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8)),
                  onPressed: () {
                    ref
                        .read(debugDashboardProvider(pondId).notifier)
                        .simulateTray(sliderValue);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Color helpers ──────────────────────────────────────────────────────────

  Color _trayColor(double factor) {
    if (factor > 1.0) return Colors.greenAccent;
    if (factor < 1.0) return Colors.redAccent;
    return Colors.white70;
  }

  Color _factorColor(double? factor) {
    if (factor == null) return Colors.white54;
    if (factor > 1.01) return Colors.greenAccent;
    if (factor < 0.99) return Colors.redAccent;
    return Colors.white70;
  }

  Color _deviationColor(double? deviation) {
    if (deviation == null) return Colors.white54;
    if (deviation > 0) return Colors.redAccent;
    if (deviation < 0) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  Color _statusColor(FeedStatus? status) {
    if (status == null) return Colors.white38;
    switch (status) {
      case FeedStatus.onTrack:
        return Colors.greenAccent;
      case FeedStatus.overfeeding:
        return Colors.redAccent;
      case FeedStatus.underfeeding:
        return Colors.orangeAccent;
    }
  }

  String _stageName(FeedStage stage) {
    switch (stage) {
      case FeedStage.blind:
        return 'BLIND (no corrections)';
      case FeedStage.transitional:
        return 'TRANSITIONAL (growth only)';
      case FeedStage.intelligent:
        return 'INTELLIGENT (full)';
    }
  }

  Color _stageColor(FeedStage? stage) {
    if (stage == null) return Colors.white38;
    switch (stage) {
      case FeedStage.blind:
        return Colors.white54;
      case FeedStage.transitional:
        return Colors.amberAccent;
      case FeedStage.intelligent:
        return Colors.greenAccent;
    }
  }

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

  String _baseHint(String stockingType, int doc) {
    if (stockingType == 'hatchery') {
      return '2.0 + (${doc - 1} × 0.15)';
    }
    return '4.0 + (${doc - 1} × 0.25)';
  }
}

// ── PIPELINE BANNER ──────────────────────────────────────────────────────────

class _PipelineBanner extends StatelessWidget {
  final OrchestratorResult? result;

  const _PipelineBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final stages = [
      'MasterFeed\n(Base)',
      'Intelligence\n(Deviation)',
      'SmartFeed\n(Corrections)',
      'Final\nFeed',
      'Decision\n(Action)',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Icon(Icons.arrow_forward,
                color: Colors.white24, size: 14);
          }
          final idx = i ~/ 2;
          return Expanded(
            child: Text(
              stages[idx],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;

  const _Section({
    required this.title,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent?.withOpacity(0.35) ??
              Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent ?? Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final bool bold;
  final Color? valueColor;

  const _Row(
    this.label,
    this.value, {
    this.hint,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bug_report_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('No data loaded.',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      ),
    );
  }
}
