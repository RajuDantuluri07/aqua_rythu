import 'package:flutter/material.dart';
import '../../core/enums/tray_status.dart';

enum FeedRoundState { done, current, upcoming }

class FeedTimelineCard extends StatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final FeedRoundState state;
  final bool isPendingTray;
  final List<TrayStatus>? trayStatuses;
  final List<String> supplements;
  final VoidCallback? onMarkDone;
  final VoidCallback? onLogTray;
  final void Function(double newQty)? onEdit;
  final double? originalFeedQty;
  final String? adjustmentReason;
  final bool isNext;
  final bool isSmartFeed;

  const FeedTimelineCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    required this.state,
    this.isPendingTray = false,
    this.trayStatuses,
    this.supplements = const [],
    this.onMarkDone,
    this.onLogTray,
    this.onEdit,
    this.originalFeedQty,
    this.adjustmentReason,
    this.isNext = false,
    this.isSmartFeed = false,
  });

  @override
  State<FeedTimelineCard> createState() => _FeedTimelineCardState();
}

class _FeedTimelineCardState extends State<FeedTimelineCard> {
  bool _isSubmitting = false;

  static const _green      = Color(0xFF16A34A);
  static const _greenLight = Color(0xFF22C55E);
  static const _greenBg    = Color(0xFFF0FDF4);
  static const _greenBorder= Color(0xFFBBF7D0);
  static const _amber      = Color(0xFFD97706);
  static const _amberBg    = Color(0xFFFFFBEB);
  static const _amberBorder= Color(0xFFFDE68A);
  static const _red        = Color(0xFFDC2626);
  static const _blue       = Color(0xFF2563EB);
  static const _purple     = Color(0xFF7C3AED);
  static const _slate100   = Color(0xFFF1F5F9);
  static const _slate200   = Color(0xFFE2E8F0);
  static const _slate300   = Color(0xFFCBD5E1);
  static const _slate400   = Color(0xFF94A3B8);
  static const _slate500   = Color(0xFF64748B);
  static const _ink        = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final isDone     = widget.state == FeedRoundState.done;
    final isCurrent  = widget.state == FeedRoundState.current;
    final isAdjusted = widget.originalFeedQty != null &&
        (widget.originalFeedQty! - widget.feedQty).abs() > 0.01;

    if (isDone)    return _smartDoneCard();
    if (isCurrent) return _smartCurrentCard(isAdjusted);
    return _upcomingCard();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BLIND FEED — DONE CARD (simple, green accent)
  // ═══════════════════════════════════════════════════════════════════

  Widget _blindDoneCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "ROUND ${widget.round}  •  ${widget.time}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${widget.feedQty.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _green,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BLIND FEED — CURRENT CARD (green border, action-focused)
  // ═══════════════════════════════════════════════════════════════════

  Widget _blindCurrentCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _greenLight, width: 2),
        boxShadow: [
          BoxShadow(color: _greenLight.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "ROUND ${widget.round}  •  ${widget.time}",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _slate500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${widget.feedQty.toStringAsFixed(1)} kg",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "CURRENT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _markAsFedButton(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SMART FEED — DONE CARD (rich: tray cols + supplements)
  // ═══════════════════════════════════════════════════════════════════

  Widget _smartDoneCard() {
    final hasTray = widget.trayStatuses != null && widget.trayStatuses!.isNotEmpty;
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.edit_rounded, size: 14, color: _slate400),
                            ),
                          ),
                        Text(
                          "${widget.feedQty.toStringAsFixed(1)} kg",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            Divider(height: 1, color: _greenBorder),
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
            Divider(height: 1, color: _greenBorder),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // ── Log tray button ─────────────────────────────────────────
          if (widget.isPendingTray && widget.onLogTray != null) ...[
            Divider(height: 1, color: _greenBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: _logTrayButton(),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SMART FEED — CURRENT CARD (rich: badges, supplement grid, warning)
  // ═══════════════════════════════════════════════════════════════════

  Widget _smartCurrentCard(bool isAdjusted) {
    final borderColor = isAdjusted ? _amber : _greenLight;
    final hasSupplements = widget.supplements.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: borderColor.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: badges row + amount ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge("CURRENT ROUND", _slate400, _slate100),
                          _badge("NOW", Colors.white, _red),
                          if (isAdjusted)
                            _badge("AUTO ADJUSTED", Colors.white, _blue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Round & time
                      Text(
                        "Round ${widget.round}  •  ${widget.time}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Amount column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onEdit != null)
                          GestureDetector(
                            onTap: () => _showEditDialog(context),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.edit_rounded, size: 13, color: _slate400),
                            ),
                          ),
                        Text(
                          "${widget.feedQty.toStringAsFixed(1)} kg",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    if (isAdjusted && widget.originalFeedQty != null)
                      Text(
                        "${widget.originalFeedQty!.toStringAsFixed(1)} kg",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _slate400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── RECOMMENDED ACTION label ──────────────────────────────────
          if (hasSupplements) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: const Text(
                  "RECOMMENDED ACTION",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _amber,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Supplement Required box ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _slate200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_rounded, size: 14, color: _purple),
                        const SizedBox(width: 6),
                        const Text(
                          "SUPPLEMENT REQUIRED",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _purple,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "MANDATORY",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _red,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 2-column supplement grid
                    _supplementGrid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Adjustment warning box ────────────────────────────────────
          if (isAdjusted && widget.originalFeedQty != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _amberBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _amberBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: _amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Feed reduced due to leftover",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _amber,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Previous: ${widget.originalFeedQty!.toStringAsFixed(1)} kg → Now: ${widget.feedQty.toStringAsFixed(1)} kg",
                            style: const TextStyle(
                              fontSize: 11,
                              color: _amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── MARK AS FED button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            child: _markAsFedButton(),
          ),
        ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "NEXT",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _blue, letterSpacing: 0.4),
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
                  "${widget.feedQty.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _slate300,
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
        row.add(Container(width: 1, height: 40, color: _slate200, margin: const EdgeInsets.symmetric(horizontal: 8)));
        row.add(Expanded(child: _supplementGridCell(sups[i + 1])));
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
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
      case TrayStatus.empty:   return 'EMPTY';
      case TrayStatus.partial: return 'HALF';
      case TrayStatus.full:    return 'FULL';
    }
  }

  Color _trayColor(TrayStatus s) {
    switch (s) {
      case TrayStatus.empty:   return _green;
      case TrayStatus.partial: return _amber;
      case TrayStatus.full:    return _red;
    }
  }

  // MARK AS FED button
  Widget _markAsFedButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                widget.onMarkDone?.call();
                if (mounted) setState(() => _isSubmitting = false);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          disabledBackgroundColor: const Color(0xFF16A34A).withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
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

  // Log tray button
  Widget _logTrayButton() {
    final hasTray = widget.trayStatuses != null && widget.trayStatuses!.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onLogTray,
        icon: const Icon(Icons.checklist_rounded, size: 16),
        label: Text(hasTray ? "Update Tray Check" : "Log Tray Check"),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _amber, width: 1.5),
          foregroundColor: _amber,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Edit dialog ───────────────────────────────────────────────────

  void _showEditDialog(BuildContext context) {
    double editAmount = widget.feedQty;

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
                  _stepBtn(icon: Icons.remove, onTap: () => setDlg(() {
                    editAmount = (editAmount - 0.5).clamp(0.0, 500.0);
                  })),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () async {
                      final ctrl = TextEditingController(text: editAmount.toStringAsFixed(1));
                      await showDialog(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: const Text("Enter amount"),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(suffix: Text("kg"), border: OutlineInputBorder()),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                            ElevatedButton(
                              onPressed: () {
                                final v = double.tryParse(ctrl.text);
                                if (v != null && v >= 0 && v <= 500) {
                                  setDlg(() => editAmount = double.parse(v.toStringAsFixed(1)));
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
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        const Text("tap to type", style: TextStyle(fontSize: 10, color: _slate400)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _stepBtn(icon: Icons.add, onTap: () => setDlg(() {
                    editAmount = (editAmount + 0.5).clamp(0.0, 500.0);
                  })),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEdit?.call(editAmount);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(color: _slate100, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 22, color: _ink),
      ),
    );
  }
}

// ── Timeline dot helpers ──────────────────────────────────────────────────────

Widget buildTimelineDot(FeedRoundState state, {bool isPendingTray = false}) {
  const green    = Color(0xFF16A34A);
  const amber    = Color(0xFFD97706);
  const slate300 = Color(0xFFCBD5E1);

  switch (state) {
    case FeedRoundState.done:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: isPendingTray ? amber : green, shape: BoxShape.circle),
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
            decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
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
