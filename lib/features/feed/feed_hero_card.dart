import 'dart:async';
import 'package:flutter/material.dart';

/// FeedHeroCard — the single decision block for the current feed round.
///
/// Merges timing context, tray signal, and action into one focused component.
/// Three states driven by [nextFeedAt]:
///   EARLY   — countdown dominates, ghost CTA
///   DUE     — quantity dominates, primary CTA
///   OVERDUE — calm prompt + quantity, primary CTA (no red panic)
class FeedHeroCard extends StatefulWidget {
  final int round;
  final String time;
  final double feedQty;

  /// Live timer SSOT. Null = no timer (treat as DUE immediately).
  final DateTime? nextFeedAt;

  /// Tray engine signal: INCREASE | REDUCE | MAINTAIN
  final String trayAction;
  final String trayReason;

  final bool isSmartFeed;

  /// ₹ saved vs plan today (positive only — never show loss here).
  final double? savedToday;

  /// Planned supplements for this round.
  final List<String> supplements;

  final VoidCallback? onMarkDone;
  final void Function(double newQty)? onEdit;

  const FeedHeroCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    required this.trayAction,
    required this.trayReason,
    this.nextFeedAt,
    this.isSmartFeed = false,
    this.savedToday,
    this.supplements = const [],
    this.onMarkDone,
    this.onEdit,
  });

  @override
  State<FeedHeroCard> createState() => _FeedHeroCardState();
}

class _FeedHeroCardState extends State<FeedHeroCard> {
  bool _isSubmitting = false;
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const _green = Color(0xFF16A34A);
  static const _greenLight = Color(0xFF22C55E);
  static const _amber = Color(0xFFD97706);
  static const _amberBorder = Color(0xFFFDE68A);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate500 = Color(0xFF64748B);
  static const _ink = Color(0xFF0F172A);

  // ── Timer ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _refresh();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(FeedHeroCard old) {
    super.didUpdateWidget(old);
    if (old.nextFeedAt != widget.nextFeedAt) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _timeRemaining = widget.nextFeedAt == null
        ? Duration.zero
        : widget.nextFeedAt!.difference(DateTime.now());
  }

  void _scheduleTick() {
    _timer?.cancel();
    if (widget.nextFeedAt == null) return;
    final tickIn = _timeRemaining.inSeconds.abs() < 60
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _timer = Timer(tickIn, () {
      if (!mounted) return;
      setState(_refresh);
      _scheduleTick();
    });
  }

  bool get _isEarly =>
      widget.nextFeedAt != null && _timeRemaining.inSeconds > 0;
  bool get _isOverdue =>
      widget.nextFeedAt != null && _timeRemaining.inMinutes < -30;

  String _fmt(Duration d) {
    final pos = d.isNegative ? d.abs() : d;
    final h = pos.inHours;
    final m = pos.inMinutes % 60;
    final s = pos.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isEarly) return _earlyState();
    if (_isOverdue) return _overdueState();
    return _dueState();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATE: EARLY — countdown is the hero
  // ══════════════════════════════════════════════════════════════════════════
  Widget _earlyState() {
    return _shell(
      borderColor: _amberBorder,
      bgColor: const Color(0xFFFFFBEB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 20),
          // Hero: big countdown
          Center(
            child: Column(
              children: [
                const Text(
                  'NEXT FEED IN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _amber,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _fmt(_timeRemaining),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: _amber,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Guidance hint
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: _slate400),
                const SizedBox(width: 5),
                Text(
                  '${widget.feedQty.toStringAsFixed(1)} kg at ${widget.time}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _slate500,
                  ),
                ),
              ],
            ),
          ),
          if (widget.trayAction != 'MAINTAIN' ||
              widget.trayReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _traySignal(),
          ],
          const SizedBox(height: 16),
          _earlyButton(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATE: DUE — feed quantity is the hero
  // ══════════════════════════════════════════════════════════════════════════
  Widget _dueState() {
    return _shell(
      borderColor: _greenLight,
      bgColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 20),
          // Hero: big quantity
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.feedQty.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' kg',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _slate400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _traySignal(),
          if (widget.supplements.isNotEmpty) ...[
            const SizedBox(height: 10),
            _supplementsRow(),
          ],
          if (widget.savedToday != null) ...[
            const SizedBox(height: 10),
            _savedRow(),
          ],
          const SizedBox(height: 16),
          _primaryButton(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATE: OVERDUE — calm, same green CTA (no red panic)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _overdueState() {
    return _shell(
      borderColor: _greenLight,
      bgColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Feed when ready',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _slate500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.feedQty.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' kg',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _slate400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _traySignal(),
          const SizedBox(height: 16),
          _primaryButton(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED SUB-WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _shell({
    required Color borderColor,
    required Color bgColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _header() {
    return Row(
      children: [
        Text(
          'Round ${widget.round}  •  ${widget.time}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _slate500,
          ),
        ),
        const Spacer(),
        if (widget.onEdit != null) ...[
          GestureDetector(
            onTap: () => _showEditDialog(context),
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.edit_rounded, size: 15, color: _slate400),
            ),
          ),
        ],
        if (widget.isSmartFeed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'SMART',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _blue,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _traySignal() {
    if (widget.trayAction == 'MAINTAIN') {
      return Center(
        child: Text(
          widget.trayReason,
          style: const TextStyle(
            fontSize: 12,
            color: _slate500,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    final Color c = widget.trayAction == 'INCREASE' ? _green : _amber;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Text(
            widget.trayAction,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.trayReason,
            style: const TextStyle(fontSize: 12, color: _slate500),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _supplementsRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: widget.supplements.map((s) {
        final i = s.lastIndexOf(' ');
        final name = i == -1 ? s : s.substring(0, i);
        final qty = i == -1 ? '' : s.substring(i + 1);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _purple.withOpacity(0.2)),
          ),
          child: Text(
            '$name  $qty',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _purple,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _savedRow() {
    final s = widget.savedToday!;
    final label =
        s >= 1000 ? '₹${(s / 1000).toStringAsFixed(1)}K' : '₹${s.toInt()}';
    return Center(
      child: Text(
        'Saved $label today',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _green,
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                try {
                  await Future.sync(() => widget.onMarkDone?.call());
                } finally {
                  if (mounted) setState(() => _isSubmitting = false);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: _green.withOpacity(0.5),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'MARK AS FED',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _earlyButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isSubmitting
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                try {
                  await Future.sync(() => widget.onMarkDone?.call());
                } finally {
                  if (mounted) setState(() => _isSubmitting = false);
                }
              },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _slate300, width: 1.5),
          foregroundColor: _slate500,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
              )
            : const Text(
                'Feed Early Anyway',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _slate500,
                ),
              ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.feedQty.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Feed Amount'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount (kg)',
            border: OutlineInputBorder(),
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) {
                widget.onEdit?.call(v);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
