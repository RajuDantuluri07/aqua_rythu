import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import 'debug_feed_provider.dart';

class DebugFeedScreen extends ConsumerStatefulWidget {
  final String pondId;
  final String pondName;

  const DebugFeedScreen({
    super.key,
    required this.pondId,
    required this.pondName,
  });

  @override
  ConsumerState<DebugFeedScreen> createState() => _DebugFeedScreenState();
}

class _DebugFeedScreenState extends ConsumerState<DebugFeedScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(debugFeedProvider(widget.pondId).notifier).load(widget.pondId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debugFeedProvider(widget.pondId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // dark bg for debug feel
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feed Engine Debug',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(widget.pondName,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => ref
                .read(debugFeedProvider(widget.pondId).notifier)
                .load(widget.pondId),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorView(error: state.error!)
              : state.latest == null
                  ? const _EmptyView()
                  : _DebugBody(state: state),
    );
  }
}

// ── MAIN BODY ────────────────────────────────────────────────────────────────

class _DebugBody extends StatelessWidget {
  final DebugState state;
  const _DebugBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final latest = state.latest!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(log: latest),
        const SizedBox(height: 12),
        _FactorBreakdown(log: latest),
        const SizedBox(height: 12),
        _TraySection(trayDays: state.trayDays),
        const SizedBox(height: 12),
        _FlagsSection(log: latest),
        const SizedBox(height: 12),
        _TimelineSection(logs: state.logs),
        const SizedBox(height: 12),
        _RawLogsSection(logs: state.logs),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── SECTION 1: SUMMARY CARD ──────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final DebugLog log;
  const _SummaryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final factor = log.finalFactor;
    final color = factor > 1.0
        ? AppColors.success
        : factor < 1.0
            ? AppColors.error
            : AppColors.textSecondary;
    final arrow = factor > 1.0 ? '▲' : factor < 1.0 ? '▼' : '▬';

    return _Card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('DOC ${log.doc}'),
                const SizedBox(height: 4),
                Text(
                  'Mode: ${log.mode.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Feed Change: ${log.changeLabel}',
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(arrow,
                  style: TextStyle(color: color, fontSize: 32)),
              Text(
                log.finalFactor.toStringAsFixed(3),
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const Text('Final Factor',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── SECTION 2: FACTOR BREAKDOWN ──────────────────────────────────────────────

class _FactorBreakdown extends StatelessWidget {
  final DebugLog log;
  const _FactorBreakdown({required this.log});

  @override
  Widget build(BuildContext context) {
    final hasSampling = (log.samplingFactor - 1.0).abs() > 0.005;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Factor Breakdown'),
          const SizedBox(height: 12),
          _FactorTile(label: 'Tray Factor', value: log.trayFactor),
          const SizedBox(height: 8),
          _FactorTile(label: 'Smart Factor', value: log.smartFactor),
          const SizedBox(height: 8),
          _FactorTile(
            label: 'Sampling Factor${hasSampling ? '' : ' (no sample)'}',
            value: log.samplingFactor,
          ),
          if (log.abw != null && log.expectedAbw != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'ABW: ${log.abw!.toStringAsFixed(1)}g  /  Expected: ${log.expectedAbw!.toStringAsFixed(1)}g',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
          const Divider(color: Colors.white12, height: 24),
          _FactorTile(
            label: 'Raw  (Tray × Smart × Sampling)',
            value: log.rawFactor,
          ),
          const SizedBox(height: 8),
          _FactorTile(
            label: 'Final (after guards)',
            value: log.finalFactor,
            highlight: true,
          ),
          if (log.reason != null) ...[
            const SizedBox(height: 8),
            Text('Reason: ${log.reason}',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _FactorTile extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _FactorTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = value > 1.005
        ? AppColors.success
        : value < 0.995
            ? AppColors.error
            : AppColors.textSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: highlight ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.normal)),
        Text(
          value.toStringAsFixed(4),
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

// ── SECTION 3: TRAY DATA ─────────────────────────────────────────────────────

class _TraySection extends StatelessWidget {
  final List<TrayDay> trayDays;
  const _TraySection({required this.trayDays});

  @override
  Widget build(BuildContext context) {
    if (trayDays.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Last 3 Days Tray Data'),
            const SizedBox(height: 8),
            const Text('No tray data available.',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final avgPct =
        trayDays.map((d) => d.pct).reduce((a, b) => a + b) / trayDays.length;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Last 3 Days Tray Data'),
          const SizedBox(height: 12),
          ...trayDays.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Text('${d.status}  (${d.pct}%)',
                        style: TextStyle(
                            color: _trayColor(d.status),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Avg Leftover',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('${avgPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Color _trayColor(String status) {
    if (status == 'Full') return AppColors.error;
    if (status == 'Empty') return AppColors.success;
    return AppColors.warning;
  }
}

// ── SECTION 4: DECISION FLAGS ────────────────────────────────────────────────

class _FlagsSection extends StatelessWidget {
  final DebugLog log;
  const _FlagsSection({required this.log});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Decision Flags'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FlagChip(
                label: 'Tray Applied',
                active: log.isTrayApplied,
                activeColor: AppColors.primary,
              ),
              _FlagChip(
                label: 'Smart Applied',
                active: log.isSmartApplied,
                activeColor: AppColors.primary,
              ),
              _FlagChip(
                label: 'Clamped',
                active: log.isClamped,
                activeColor: AppColors.warning,
                isWarning: true,
              ),
              _FlagChip(
                label: 'Overfeeding Hold',
                active: log.isOverfeedingHold,
                activeColor: AppColors.error,
                isWarning: true,
              ),
              _FlagChip(
                label: 'Decrease Streak Hold',
                active: log.isDecreaseStreakLimited,
                activeColor: AppColors.warning,
                isWarning: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final bool isWarning;

  const _FlagChip({
    required this.label,
    required this.active,
    required this.activeColor,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? activeColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? activeColor : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            active ? (isWarning ? '⚠ ' : '✔ ') : '✖ ',
            style: TextStyle(
                fontSize: 12, color: active ? activeColor : Colors.white24),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                color: active ? activeColor : Colors.white24,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}

// ── SECTION 5: TIMELINE ──────────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  final List<DebugLog> logs;
  const _TimelineSection({required this.logs});

  @override
  Widget build(BuildContext context) {
    final last5 = logs.take(5).toList().reversed.toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Factor Timeline (Last 5)'),
          const SizedBox(height: 12),
          ...last5.map((log) {
            final color = log.finalFactor > 1.0
                ? AppColors.success
                : log.finalFactor < 1.0
                    ? AppColors.error
                    : AppColors.textSecondary;
            final bar = _bar(log.finalFactor);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('DOC ${log.doc}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            )),
                        FractionallySizedBox(
                          widthFactor: bar,
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Text(
                      log.finalFactor.toStringAsFixed(2),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Maps factor [0.85–1.15] to a bar width fraction [0–1].
  double _bar(double factor) {
    return ((factor - 0.85) / 0.30).clamp(0.0, 1.0);
  }
}

// ── SECTION 6: RAW DEBUG LOGS ────────────────────────────────────────────────

class _RawLogsSection extends StatelessWidget {
  final List<DebugLog> logs;
  const _RawLogsSection({required this.logs});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white38,
        title: _sectionTitle('Raw Debug Logs (${logs.length})'),
        children: logs
            .map((log) => _RawLogRow(log: log))
            .toList(),
      ),
    );
  }
}

class _RawLogRow extends StatelessWidget {
  final DebugLog log;
  const _RawLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d MMM  HH:mm').format(log.createdAt.toLocal());

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      iconColor: Colors.white38,
      collapsedIconColor: Colors.white38,
      title: Text(
        '[DOC ${log.doc}  |  $time]',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mono('mode            : ${log.mode}'),
              _mono('base_feed       : ${log.baseFeed.toStringAsFixed(3)} kg'),
              _mono('tray_factor     : ${log.trayFactor.toStringAsFixed(4)}'),
              _mono('smart_factor    : ${log.smartFactor.toStringAsFixed(4)}'),
              _mono('sampling_factor : ${log.samplingFactor.toStringAsFixed(4)}'),
              if (log.abw != null)
                _mono('abw             : ${log.abw!.toStringAsFixed(2)} g'),
              if (log.expectedAbw != null)
                _mono('expected_abw    : ${log.expectedAbw!.toStringAsFixed(2)} g'),
              _mono('final_factor    : ${log.finalFactor.toStringAsFixed(4)}'),
              _mono('final_feed      : ${log.finalFeed.toStringAsFixed(3)} kg'),
              if (log.reason != null)
                _mono('reason      : ${log.reason}'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  if (log.isTrayApplied) _miniChip('tray_applied', AppColors.primary),
                  if (log.isSmartApplied) _miniChip('smart_applied', AppColors.primary),
                  if (log.isClamped) _miniChip('clamped', AppColors.warning),
                  if (log.isOverfeedingHold) _miniChip('overfeed_hold', AppColors.error),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mono(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace')),
      );

  Widget _miniChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 10)),
      );
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: child,
    );
  }
}

Widget _sectionTitle(String text) => Text(
      text,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4),
    );

Widget _label(String text) => Text(
      text,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold),
    );

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
          Text('No debug logs yet.',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          SizedBox(height: 4),
          Text('Engine logs appear after DOC 30.',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
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
      child: Text(error,
          style: const TextStyle(color: AppColors.error, fontSize: 13)),
    );
  }
}
