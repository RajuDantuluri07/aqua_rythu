import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feeding_engine_v1.dart';
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
          'Feed Engine Debug V1',
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 1. POND CONTEXT ────────────────────────────────────────────────
        _Section(
          title: '1. Pond Context',
          children: [
            _Row('Pond', state.pondName),
            _Row('DOC', '${state.doc}'),
            _Row('Stocking', state.stockingType.toUpperCase()),
            _Row('Density', _fmt(state.density.toDouble(), suffix: ' shrimp')),
          ],
        ),
        const SizedBox(height: 12),

        // ── 2. FEED ENGINE BREAKDOWN ───────────────────────────────────────
        _Section(
          title: '2. Feed Engine Breakdown',
          accent: _feedColor(d),
          children: [
            _Row('Base Feed', '${d.baseFeed.toStringAsFixed(3)} kg',
                hint: _baseHint(state.stockingType, state.doc)),
            _Row('After Density', '${d.adjustedFeed.toStringAsFixed(3)} kg',
                hint: '× (${state.density} / 100000)'),
            _Row(
              'Tray Factor',
              d.trayFactor.toStringAsFixed(2),
              valueColor: _trayColor(d.trayFactor),
            ),
            _Row('Raw Feed', '${d.rawFeed.toStringAsFixed(3)} kg'),
            _Row(
              'Final Feed',
              '${d.finalFeed.toStringAsFixed(3)} kg',
              bold: true,
              valueColor: _feedColor(d),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 3. TRAY DATA ───────────────────────────────────────────────────
        _Section(
          title: '3. Tray Data',
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
            _Row('Input Missing', d.leftover == null ? 'YES' : 'NO',
                valueColor:
                    d.leftover == null ? Colors.orangeAccent : Colors.white54),
          ],
        ),
        const SizedBox(height: 12),

        // ── 4. SAFETY CLAMP ────────────────────────────────────────────────
        _Section(
          title: '4. Safety Clamp',
          children: [
            _Row('Min Allowed', '${d.minFeed.toStringAsFixed(3)} kg',
                hint: '(adjustedBase × 0.7)'),
            _Row('Max Allowed', '${d.maxFeed.toStringAsFixed(3)} kg',
                hint: '(adjustedBase × 1.3)'),
            _Row(
              'Clamped',
              d.isClamped ? 'YES ⚠' : 'NO',
              valueColor:
                  d.isClamped ? Colors.orangeAccent : Colors.greenAccent,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 5. ENGINE FLAGS ────────────────────────────────────────────────
        _Section(
          title: '5. Engine Flags',
          children: [
            _Row('Engine', 'V1', valueColor: Colors.greenAccent),
            _Row('FCR', 'OFF', valueColor: Colors.redAccent),
            _Row('Biomass Engine', 'OFF', valueColor: Colors.redAccent),
            _Row('235 Normalization', 'OFF', valueColor: Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),

        // ── 6. ACTION BUTTONS ──────────────────────────────────────────────
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
            final factor = FeedingEngineV1.trayFactor(sliderValue);
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
                  // Legend
                  Wrap(
                    spacing: 8,
                    children: const [
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(double v, {String suffix = ''}) =>
      '${v.toStringAsFixed(0)}$suffix';

  String _baseHint(String stockingType, int doc) {
    if (stockingType == 'hatchery') {
      return '2.0 + (${doc - 1} × 0.15)';
    }
    return '4.0 + (${doc - 1} × 0.25)';
  }

  Color _feedColor(FeedDebugData d) {
    if (d.trayFactor > 1.0) return Colors.greenAccent;
    if (d.trayFactor < 1.0) return Colors.redAccent;
    return Colors.white70;
  }

  Color _trayColor(double factor) {
    if (factor > 1.0) return Colors.greenAccent;   // 🟢 increased
    if (factor < 1.0) return Colors.redAccent;     // 🔴 reduced
    return Colors.white70;                          // no change
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
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10)),
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
