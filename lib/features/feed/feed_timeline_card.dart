import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../systems/feed/feed_models.dart';
import '../../features/tray/enums/tray_status.dart';

enum FeedRoundState { done, current, upcoming }

// T11 — Mode gates features by DOC range
enum FeedMode { starter, guided, smart }

FeedMode feedModeFromDoc(int doc) {
  if (doc <= 7) return FeedMode.starter;
  if (doc <= 30) return FeedMode.guided; // Fix #4: smart_feeding = (doc >= 31)
  return FeedMode.smart;
}

String feedModeLabel(FeedMode mode) {
  switch (mode) {
    case FeedMode.starter:
      return 'Starter Mode — follow basic feeding';
    case FeedMode.guided:
      return 'Guided Mode — improving accuracy';
    case FeedMode.smart:
      return 'Smart Mode — AI optimized feeding';
  }
}

class FeedTimelineCard extends StatefulWidget {
  final int round;
  final String time;
  final double recommendedFeedKg;
  final double finalFeedKg;
  final bool isManuallyEdited;
  final FeedRoundState state;
  final bool isPendingTray;
  final List<TrayStatus>? trayStatuses;
  final List<String> supplements;
  final VoidCallback? onMarkDone;
  final VoidCallback? onLogTray;
  final void Function(double newQty)? onEdit;
  final double? lastFeedKg;
  final double? leftoverPercent;
  final double? correctionPercent;
  final String? adjustmentReason;
  final bool isNext;
  final bool isSmartFeed;

  /// True when the tray check was auto-skipped (farmer moved to next round
  /// without logging). Shows ⚠️ skipped banner + "Update Now" CTA.
  final bool isTraySkipped;

  /// SSOT for feed timing. When non-null, the card runs a live countdown
  /// and shows one of three states:
  ///   • Too Early   — nextFeedAt.isAfter(now)  → countdown + ghost CTA
  ///   • Window Open — nextFeedAt.isBefore(now) within 30 min → primary green
  ///   • Overdue     — nextFeedAt before now by >30 min → red urgent
  /// Null = no timer (done/upcoming cards, or no further rounds today).
  final DateTime? nextFeedAt;

  /// T7 — One-line AI insight shown below the feed quantity.
  final String? insight;

  /// T8 — Feeding progress: rounds completed vs total planned today.
  final int completedRounds;
  final int totalRounds;

  /// T9 — AI confidence score (0.0–1.0). Shows "AI X%" badge when provided.
  final double? confidenceScore;

  /// T10 — True when safety clamp was applied to the recommendation.
  final bool isSafetyClamped;

  /// T11 — DOC-derived feeding mode (Starter / Guided / Smart).
  final FeedMode feedMode;

  /// T13 — Show thumbs up/down feedback prompt on done card.
  final bool showFeedbackPrompt;

  /// T13 — Called when farmer rates the recommendation accuracy.
  final void Function(bool isAccurate)? onFeedback;

  /// Decision output from FeedDecisionEngine — action, delta, reason.
  /// When provided, replaces the manual % comparison logic in the reason line.
  final FeedDecision? decision;

  /// Feed recommendation instruction from FeedRecommendationEngine.
  /// Shows actionable next-feed guidance to the farmer.
  final String? recommendationInstruction;

  /// Whether this is the current round that should be worked on now.
  final bool isCurrent;

  /// Farmer's anchor feed (kg) — non-null only when DOC > 30 and anchor is set.
  /// When provided, the card shows "Base Feed (Your input)" + "Adjusted Feed (Tray-based)".
  final double? anchorFeedKg;

  const FeedTimelineCard({
    super.key,
    required this.round,
    required this.time,
    required this.recommendedFeedKg,
    required this.finalFeedKg,
    required this.isManuallyEdited,
    required this.state,
    this.isPendingTray = false,
    this.isTraySkipped = false,
    this.trayStatuses,
    this.supplements = const [],
    this.onMarkDone,
    this.onLogTray,
    this.onEdit,
    this.lastFeedKg,
    this.leftoverPercent,
    this.correctionPercent,
    this.adjustmentReason,
    this.isNext = false,
    this.isSmartFeed = false,
    this.nextFeedAt,
    this.insight,
    this.completedRounds = 0,
    this.totalRounds = 0,
    this.confidenceScore,
    this.isSafetyClamped = false,
    this.feedMode = FeedMode.guided,
    this.showFeedbackPrompt = false,
    this.onFeedback,
    this.decision,
    this.recommendationInstruction,
    this.isCurrent = false,
    this.anchorFeedKg,
  });

  @override
  State<FeedTimelineCard> createState() => _FeedTimelineCardState();
}

class _FeedTimelineCardState extends State<FeedTimelineCard> {
  bool _isSubmitting = false;

  // T13 — Feedback state for done card
  bool _feedbackGiven = false;

  // ── Live countdown timer ──────────────────────────────────────────────────
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _refreshRemaining();
    _scheduleNextTick();
  }

  @override
  void didUpdateWidget(FeedTimelineCard old) {
    super.didUpdateWidget(old);
    if (old.nextFeedAt != widget.nextFeedAt) {
      _refreshRemaining();
      _scheduleNextTick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshRemaining() {
    if (widget.nextFeedAt == null) {
      _timeRemaining = Duration.zero;
    } else {
      _timeRemaining = widget.nextFeedAt!.difference(DateTime.now());
    }
  }

  /// Ticks every second when < 60 s remain; every minute otherwise.
  /// Stops ticking once nextFeedAt is null (all done) or card is disposed.
  void _scheduleNextTick() {
    _timer?.cancel();
    if (widget.nextFeedAt == null) return;
    final tickIn = _timeRemaining.inSeconds.abs() < 60
        ? const Duration(seconds: 1)
        : const Duration(minutes: 1);
    _timer = Timer(tickIn, () {
      if (!mounted) return;
      setState(_refreshRemaining);
      _scheduleNextTick();
    });
  }

  // ── Countdown formatting ─────────────────────────────────────────────────
  /// Formats a Duration for display. Always positive input (caller passes abs()).
  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  // ── Feed-state helpers ────────────────────────────────────────────────────
  bool get _isTooEarly =>
      widget.nextFeedAt != null && _timeRemaining.inSeconds > 0;

  bool get _isOverdue =>
      widget.nextFeedAt != null && _timeRemaining.inMinutes < -30;

  static const _green = Color(0xFF16A34A);
  static const _greenLight = Color(0xFF22C55E);
  static const _greenBg = Color(0xFFF0FDF4);
  static const _greenBorder = Color(0xFFBBF7D0);
  static const _amber = Color(0xFFD97706);
  static const _amberBg = Color(0xFFFFFBEB);
  static const _amberBorder = Color(0xFFFDE68A);
  static const _red = Color(0xFFDC2626);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate500 = Color(0xFF64748B);
  static const _ink = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint(
          '🎯 Feed card rebuild | round: ${widget.round} | state: ${widget.state.name}');
      return true;
    }());
    final isDone = widget.state == FeedRoundState.done;
    final isCurrent = widget.state == FeedRoundState.current;

    if (isDone) return _smartDoneCard();
    if (isCurrent) return _smartCurrentCard();
    return _upcomingCard();
  }

  // ═══════════════════════════════════════════════════════════════════
  // SMART FEED — DONE CARD (rich: tray cols + supplements)
  // ═══════════════════════════════════════════════════════════════════

  Widget _smartDoneCard() {
    final hasTray =
        widget.trayStatuses != null && widget.trayStatuses!.isNotEmpty;
    final hasSupplements = widget.supplements.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: round label + amount ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "ROUND ${widget.round}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _green,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "COMPLETED",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _green,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onEdit != null)
                          GestureDetector(
                            onTap: () => _showEditDialog(context),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.edit_rounded,
                                  size: 14, color: _slate400),
                            ),
                          ),
                        Text(
                          widget.finalFeedKg <= 0
                              ? "Do not feed"
                              : "${widget.finalFeedKg.toStringAsFixed(1)} kg",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "DONE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tray results: 4 columns ──────────────────────────────────
          if (hasTray) ...[
            const Divider(height: 1, color: _greenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: List.generate(
                  widget.trayStatuses!.length.clamp(1, 4),
                  (i) {
                    final s = widget.trayStatuses![i];
                    final color = _trayColor(s);
                    final label = _trayLabel(s);
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TRAY ${i + 1}",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _slate400,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // ── Supplements used ──────────────────────────────────────────
          if (hasSupplements) ...[
            const Divider(height: 1, color: _greenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SUPPLEMENTS USED",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _slate400,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.supplements.map((s) {
                      final parts = _parseSupplementString(s);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _purple.withOpacity(0.2)),
                        ),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: parts[0],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _purple,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              TextSpan(
                                text: "  ${parts[1]}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          // ── Tray skipped banner ──────────────────────────────────────
          if (widget.isTraySkipped) ...[
            const Divider(height: 1, color: _greenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: _traySkippedBanner(),
            ),
          ],

          // ── Log tray button (pending, not yet skipped) ───────────────
          if (widget.isPendingTray && widget.onLogTray != null) ...[
            const Divider(height: 1, color: _greenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: _logTrayButton(),
            ),
          ],

          // T13 — Feedback prompt on the done card
          if (widget.showFeedbackPrompt && !_feedbackGiven) ...[
            const Divider(height: 1, color: _greenBorder),
            _feedbackRow(),
          ],
          if (widget.showFeedbackPrompt && _feedbackGiven) ...[
            const Divider(height: 1, color: _greenBorder),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: _green),
                  SizedBox(width: 6),
                  Text('Thanks! This helps improve recommendations.',
                      style: TextStyle(
                          fontSize: 11,
                          color: _green,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SMART FEED — CURRENT CARD (3 states: too early / window / overdue)
  // ═══════════════════════════════════════════════════════════════════

  Widget _smartCurrentCard() {
    const Color borderColor = _greenLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: borderColor.withOpacity(0.22),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ROUND label + ACTIVE badge + urgency
            Row(
              children: [
                Text(
                  "ROUND ${widget.round}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _green,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "ACTIVE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                ),
                if (widget.nextFeedAt != null) ...[
                  const SizedBox(width: 6),
                  _urgencyBadge(),
                ],
              ],
            ),
            // Mode label (subtle)
            const SizedBox(height: 3),
            Text(
              feedModeLabel(widget.feedMode),
              style: const TextStyle(
                  fontSize: 9, color: _slate400, fontWeight: FontWeight.w500),
            ),
            if (widget.feedMode == FeedMode.smart) ...[
              const SizedBox(height: 2),
              Text(
                widget.anchorFeedKg != null
                    ? 'Smart feed based on tray response'
                    : 'Estimated feed based on growth curve',
                style: const TextStyle(
                    fontSize: 9, color: _slate400, fontWeight: FontWeight.w500),
              ),
            ],
            // Feeding progress
            if (widget.totalRounds > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${(widget.completedRounds / widget.totalRounds * 100).round()}% feeding completed today',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Feed quantity display — anchor mode vs standard
            if (widget.anchorFeedKg != null &&
                widget.feedMode == FeedMode.smart) ...[
              // TASK 8: Base feed (farmer anchor) + adjusted feed (tray-based)
              _anchorFeedRow(
                label: 'Base Feed',
                sublabel: 'Your input',
                kg: widget.anchorFeedKg!,
                color: _slate500,
              ),
              const SizedBox(height: 6),
              _anchorFeedRow(
                label: 'Adjusted Feed',
                sublabel: 'Tray-based',
                kg: widget.recommendedFeedKg,
                color: _ink,
                isBold: true,
                onEdit: widget.onEdit != null
                    ? () => _showEditDialog(context)
                    : null,
              ),
            ] else ...[
              // Standard display
              Row(
                children: [
                  const Text(
                    "Recommended Feed:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.recommendedFeedKg <= 0
                        ? "Do not feed"
                        : "${widget.recommendedFeedKg.toStringAsFixed(1)} kg",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.onEdit != null)
                    GestureDetector(
                      onTap: () => _showEditDialog(context),
                      child: const Text(
                        "✏️",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
            ],
            // Safety clamp indicator
            if (widget.isSafetyClamped) ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 12, color: _amber),
                  SizedBox(width: 4),
                  Text(
                    'Adjusted for safety',
                    style: TextStyle(
                        fontSize: 10,
                        color: _amber,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],

            // Simple status message — one line, action-focused
            const SizedBox(height: 10),
            _simpleStatusLine(),

            if (_shouldShowTrustSignals()) ...[
              const SizedBox(height: 10),
              _feedTrustSignals(),
            ],

            // Confirm Feed Button — Enhanced for farmer accessibility
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52, // Larger touch target for farmers
              child: ElevatedButton.icon(
                onPressed: widget.onMarkDone != null && !_isSubmitting
                    ? () async {
                        HapticFeedback.mediumImpact(); // Tactile feedback
                        setState(() => _isSubmitting = true);
                        try {
                          await Future.sync(() => widget.onMarkDone!());
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: _slate300,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: _green.withOpacity(0.4),
                ),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: Text(
                  _isSubmitting
                      ? "Saving..."
                      : widget.recommendedFeedKg <= 0
                          ? "Confirm No Feed"
                          : "Confirm Feed",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anchorFeedRow({
    required String label,
    required String sublabel,
    required double kg,
    required Color color,
    bool isBold = false,
    VoidCallback? onEdit,
  }) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: isBold ? 15 : 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: '${kg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: isBold ? 15 : 13,
                    fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: '  ($sublabel)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('✏️', style: TextStyle(fontSize: 16)),
            ),
          ),
      ],
    );
  }

  bool _shouldShowTrustSignals() {
    return widget.decision != null &&
        (widget.decision!.recommendations.isNotEmpty ||
            widget.decision!.confidence.isNotEmpty ||
            widget.recommendedFeedKg <= 0);
  }

  Widget _feedTrustSignals() {
    final decision = widget.decision;
    final reasons = decision?.recommendations ?? const <String>[];
    final isStopped = widget.recommendedFeedKg <= 0 ||
        decision?.action.toLowerCase().contains('stop') == true;
    final showReasons = reasons.isNotEmpty || isStopped;
    final confidence = decision?.confidence ?? 'Normal';
    final confidenceReason =
        decision?.confidenceReason ?? 'Normal feeding confidence';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReasons) ...[
          Text(
            isStopped ? 'Stopped due to:' : 'Reduced due to:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _slate500,
            ),
          ),
          const SizedBox(height: 4),
          if (reasons.isEmpty && decision != null)
            _reasonBullet(decision.reason)
          else
            ...reasons.map(_reasonBullet),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 14, color: _slate400),
            const SizedBox(width: 5),
            Text(
              'Confidence: $confidence',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          confidenceReason,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _slate400,
          ),
        ),
      ],
    );
  }

  Widget _reasonBullet(String reason) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _slate500,
            ),
          ),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Simple status line — replaces analytics/FCR block ────────────────────
  // Shows one clear farming signal. No numbers, no comparisons, no trends.
  Widget _simpleStatusLine() {
    final String message;
    final Color color;
    final IconData icon;

    final bool highLeftover =
        widget.leftoverPercent != null && widget.leftoverPercent! > 15;
    final bool bigReduction =
        widget.correctionPercent != null && widget.correctionPercent! < -5;
    final bool smallReduction =
        widget.correctionPercent != null && widget.correctionPercent! < -2;

    if (widget.recommendedFeedKg <= 0) {
      message = 'Do not feed';
      color = _red;
      icon = Icons.block_rounded;
    } else if (highLeftover || bigReduction) {
      message = 'Reduce feed slightly';
      color = _amber;
      icon = Icons.trending_down_rounded;
    } else if (widget.isPendingTray || smallReduction) {
      message = 'Check tray before next feed';
      color = _amber;
      icon = Icons.checklist_rounded;
    } else {
      message = 'Feeding on track';
      color = _green;
      icon = Icons.check_circle_outline_rounded;
    }

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Tray feedback list ───────────────────────────────────────────────────
  List<Widget> _buildTrayFeedback() {
    if (widget.trayStatuses == null) return [];
    final counts = <TrayStatus, int>{};
    for (final status in widget.trayStatuses!) {
      counts[status] = (counts[status] ?? 0) + 1;
    }
    final avgLeftover = widget.leftoverPercent ?? 0;

    return [
      Text(
        "• ${counts[TrayStatus.heavy] ?? 0} Heavy",
        style: const TextStyle(fontSize: 14, color: _slate500),
      ),
      Text(
        "• ${counts[TrayStatus.light] ?? 0} Light",
        style: const TextStyle(fontSize: 14, color: _slate500),
      ),
      Text(
        "• Avg leftover: ${avgLeftover.toStringAsFixed(0)}%",
        style: const TextStyle(fontSize: 14, color: _slate500),
      ),
    ];
  }

  // ── Override warning ─────────────────────────────────────────────────────
  Widget _overrideWarning() {
    final diff = widget.finalFeedKg - widget.recommendedFeedKg;
    final percent = (diff / widget.recommendedFeedKg * 100).round();
    final isOver = diff > 0;
    final message = isOver
        ? "You are feeding ${percent.abs()}% more than recommended"
        : "You are feeding ${percent.abs()}% below recommended level";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _amberBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: _amber),
              const SizedBox(width: 4),
              Text(
                isOver ? "Overfeeding" : "Underfeeding",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: _slate500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOver
                ? "This may increase feed waste and FCR"
                : "Growth may slow down",
            style: const TextStyle(
              fontSize: 13,
              color: _slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ── T6 — Urgency badge ────────────────────────────────────────────────────
  Widget _urgencyBadge() {
    final mins = _timeRemaining.inMinutes;
    final Color color;
    final String label;
    if (_isOverdue) {
      color = _red;
      label = 'Feed Now';
    } else if (mins <= 30) {
      color = _red;
      label = 'Due Soon';
    } else if (mins <= 60) {
      color = _amber;
      label = 'Upcoming';
    } else {
      color = _green;
      label = 'Safe';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── T12 — Priority signal builder ────────────────────────────────────────
  // Picks the right body signals based on context severity.
  // Rules (max 2 visible signals):
  //   Critical (overdue or >20% correction) → insight only (urgency in header)
  //   Major issue (>20% leftover or >10% correction) → insight + impact only
  //   Normal / Starter mode → reason + impact (T4 style, no insight)
  //   Guided/Smart normal → reason + impact + insight (if available)
  List<Widget> _buildBodySignals() {
    final bool isCritical = _isOverdue ||
        (widget.correctionPercent != null &&
            widget.correctionPercent!.abs() > 20);
    final bool hasMajorIssue =
        (widget.leftoverPercent != null && widget.leftoverPercent! > 20) ||
            (widget.correctionPercent != null &&
                widget.correctionPercent!.abs() > 10);

    // T11 gate: AI insight only for Guided (limited) and Smart modes
    final bool insightAllowed =
        widget.insight != null && widget.feedMode != FeedMode.starter;

    if (isCritical && insightAllowed) {
      // Critical: show insight only — urgency badge already in header covers the 2nd signal
      return [_insightLine(widget.insight!)];
    }

    if (hasMajorIssue && insightAllowed) {
      // Major issue: insight replaces reason, impact stays
      return [_insightLine(widget.insight!)];
    }

    // Normal: reason + impact (always shown, including Starter mode)
    final reasonWidget = _feedReasonLine();
    if (!insightAllowed || widget.insight == null) {
      return [reasonWidget];
    }

    // Guided/Smart normal: reason + impact + insight (3 pieces of info but
    // reason+impact count as 1 signal since they're visually paired)
    return [
      reasonWidget,
      const SizedBox(height: 10),
      _insightLine(widget.insight!),
    ];
  }

  // ── T13 — Feedback row (thumbs up / down) ────────────────────────────────
  Widget _feedbackRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          const Text(
            'Was this recommendation accurate?',
            style: TextStyle(
                fontSize: 11, color: _slate500, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _feedbackGiven = true);
              widget.onFeedback?.call(true);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.3)),
              ),
              child:
                  const Icon(Icons.thumb_up_rounded, size: 16, color: _green),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _feedbackGiven = true);
              widget.onFeedback?.call(false);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _red.withOpacity(0.3)),
              ),
              child:
                  const Icon(Icons.thumb_down_rounded, size: 16, color: _red),
            ),
          ),
        ],
      ),
    );
  }

  // ── T4 — Feed reasoning line ──────────────────────────────────────────────
  // T4 + GAP 2 — reason WHY this feed + consequence WHAT it means
  Widget _feedReasonLine() {
    final String reason;
    final String impact;
    final Color impactColor;

    if (widget.adjustmentReason != null &&
        widget.adjustmentReason!.isNotEmpty) {
      reason = widget.adjustmentReason!;
      impact = 'Check tray result after feeding';
      impactColor = _slate400;
    } else if (widget.correctionPercent != null &&
        widget.correctionPercent! < -2) {
      final pct = widget.correctionPercent!.abs().round();
      reason = 'Reduced by $pct% — tray showed leftover';
      impact = 'Will help bring FCR down';
      impactColor = _green;
    } else if (widget.correctionPercent != null &&
        widget.correctionPercent! > 2) {
      final pct = widget.correctionPercent!.round();
      reason = 'Increased by $pct% — good consumption';
      impact = 'Good for growth this week';
      impactColor = _green;
    } else if (widget.leftoverPercent != null && widget.leftoverPercent! > 15) {
      reason = 'Maintained — some tray leftover seen';
      impact = 'Watch tray closely next round';
      impactColor = _amber;
    } else {
      reason = 'Maintained — good consumption';
      impact = 'Growth on track';
      impactColor = _green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: _slate400),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                reason,
                style: const TextStyle(
                    fontSize: 11,
                    color: _slate500,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Text(
            '→ $impact',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: impactColor),
          ),
        ),
      ],
    );
  }

  // ── T7 — AI Insight block ─────────────────────────────────────────────────
  Widget _insightLine(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 14, color: _blue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero countdown block ──────────────────────────────────────────────────
  Widget _timerHero({required String label, required Duration duration}) {
    final positive = duration.isNegative ? duration.abs() : duration;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amberBorder, width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _amber,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtDuration(positive),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: _amber,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Early feed guidance banner ────────────────────────────────────────────
  Widget _earlyWarningBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _amberBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: _amber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Best results when fed at the scheduled time",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _amber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overdue banner ────────────────────────────────────────────────────────
  Widget _overdueBanner() {
    final overdueBy = _fmtDuration(_timeRemaining.abs());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, size: 16, color: _red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Feed overdue by $overdueBy — feed now",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── "Feed Early Anyway" ghost button (STATE 1 only) ───────────────────────
  Widget _feedEarlyButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
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
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: _slate400),
              )
            : const Text(
                "Feed Early Anyway",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _slate500,
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // UPCOMING CARD — unified for both modes
  // ═══════════════════════════════════════════════════════════════════

  Widget _upcomingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _slate200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "ROUND ${widget.round}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _slate400,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (widget.isNext) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "NEXT",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _blue,
                                letterSpacing: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.time,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _slate400,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.finalFeedKg <= 0
                      ? "Do not feed"
                      : "${widget.finalFeedKg.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _slate500,
                  ),
                ),
                const Text(
                  "UPCOMING",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _slate300,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED SUB-WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Parses "NAME 135.0g" → ["NAME", "135.0g"]
  List<String> _parseSupplementString(String s) {
    final lastSpace = s.lastIndexOf(' ');
    if (lastSpace == -1) return [s, ''];
    return [s.substring(0, lastSpace), s.substring(lastSpace + 1)];
  }

  Widget _supplementGrid() {
    if (widget.supplements.isEmpty) return const SizedBox.shrink();

    // Display in 2-column grid (or single if only 1)
    final sups = widget.supplements;
    final rows = <Widget>[];

    for (int i = 0; i < sups.length; i += 2) {
      final row = <Widget>[];
      row.add(Expanded(child: _supplementGridCell(sups[i])));
      if (i + 1 < sups.length) {
        row.add(Container(
            width: 1,
            height: 40,
            color: _slate200,
            margin: const EdgeInsets.symmetric(horizontal: 8)));
        row.add(Expanded(child: _supplementGridCell(sups[i + 1])));
      }
      rows.add(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
      if (i + 2 < sups.length) rows.add(const SizedBox(height: 8));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _supplementGridCell(String sup) {
    final parts = _parseSupplementString(sup);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts[0],
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _purple,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          parts[1],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
      ],
    );
  }

  String _trayLabel(TrayStatus s) {
    switch (s) {
      case TrayStatus.empty:
        return 'EMPTY';
      case TrayStatus.light:
        return 'LIGHT';
      case TrayStatus.medium:
        return 'MEDIUM';
      case TrayStatus.heavy:
        return 'HEAVY';
    }
  }

  Color _trayColor(TrayStatus s) {
    switch (s) {
      case TrayStatus.empty:
        return _green;
      case TrayStatus.light:
        return _blue;
      case TrayStatus.medium:
        return _amber;
      case TrayStatus.heavy:
        return _red;
    }
  }

  // MARK AS FED button
  Widget _markAsFedButton() {
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
          backgroundColor: const Color(0xFF16A34A),
          disabledBackgroundColor: const Color(0xFF16A34A).withOpacity(0.5),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    "MARK AS FED",
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

  // Tray skipped banner — shown when tray was auto-skipped
  Widget _traySkippedBanner() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _amberBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 15, color: _amber),
                SizedBox(width: 6),
                Text(
                  "Tray check skipped",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _amber,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  "— next round unchanged",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _amber,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onLogTray != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onLogTray,
            style: TextButton.styleFrom(
              foregroundColor: _amber,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: _amberBorder),
              ),
            ),
            child: const Text(
              "Update",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  // Log tray button — Enhanced with haptic feedback
  Widget _logTrayButton() {
    final hasTray =
        widget.trayStatuses != null && widget.trayStatuses!.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 48, // Larger touch target
      child: OutlinedButton.icon(
        onPressed: widget.onLogTray != null
            ? () {
                HapticFeedback.lightImpact(); // Tactile feedback
                widget.onLogTray!();
              }
            : null,
        icon: Icon(
          hasTray ? Icons.fact_check_rounded : Icons.checklist_rounded,
          size: 20,
        ),
        label: Text(
          hasTray ? "Update Tray Check" : "Log Tray Check",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _amber, width: 1.5),
          foregroundColor: _amber,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Edit dialog ───────────────────────────────────────────────────

  void _showEditDialog(BuildContext context) {
    double editAmount = widget.finalFeedKg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text("Edit Round ${widget.round} Feed"),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepBtn(
                      icon: Icons.remove,
                      onTap: () => setDlg(() {
                            editAmount = (editAmount - 0.5).clamp(0.0, 500.0);
                          })),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () async {
                      final ctrl = TextEditingController(
                          text: editAmount.toStringAsFixed(1));
                      await showDialog(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: const Text("Enter amount"),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                suffix: Text("kg"),
                                border: OutlineInputBorder()),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel")),
                            ElevatedButton(
                              onPressed: () {
                                final v = double.tryParse(ctrl.text);
                                if (v != null && v >= 0 && v <= 500) {
                                  setDlg(() => editAmount =
                                      double.parse(v.toStringAsFixed(1)));
                                }
                                Navigator.pop(ctx);
                              },
                              child: const Text("Set"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "${editAmount.toStringAsFixed(1)} kg",
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: _ink),
                        ),
                        const Text("tap to type",
                            style: TextStyle(fontSize: 10, color: _slate400)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _stepBtn(
                      icon: Icons.add,
                      onTap: () => setDlg(() {
                            editAmount = (editAmount + 0.5).clamp(0.0, 500.0);
                          })),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEdit?.call(editAmount);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A)),
              child: const Text("Save",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: _slate100, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 22, color: _ink),
      ),
    );
  }
}

// ── Timeline dot helpers ──────────────────────────────────────────────────────

Widget buildTimelineDot(FeedRoundState state, {bool isPendingTray = false}) {
  const green = Color(0xFF16A34A);
  const amber = Color(0xFFD97706);
  const slate300 = Color(0xFFCBD5E1);

  switch (state) {
    case FeedRoundState.done:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
            color: isPendingTray ? amber : green, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    case FeedRoundState.current:
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: green, width: 2.5),
          color: Colors.white,
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration:
                const BoxDecoration(color: green, shape: BoxShape.circle),
          ),
        ),
      );
    case FeedRoundState.upcoming:
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: slate300, width: 2),
          color: Colors.white,
        ),
      );
  }
}
