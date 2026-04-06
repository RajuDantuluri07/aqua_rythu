import 'package:flutter/material.dart';
import '../../core/enums/tray_status.dart';

enum FeedRoundState { done, current, upcoming }

class FeedTimelineCard extends StatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final FeedRoundState state;

  /// Feed done but tray check still required (DOC > 30 only)
  final bool isPendingTray;

  /// Tray statuses from a logged tray check — shown on done card
  final List<TrayStatus>? trayStatuses;

  /// Supplement names to display (applied for done, planned for others)
  final List<String> supplements;

  final VoidCallback? onMarkDone;
  final VoidCallback? onLogTray;

  /// Called with the new amount when the user edits and confirms.
  /// If null, no edit button is shown.
  final void Function(double newQty)? onEdit;

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
  });

  @override
  State<FeedTimelineCard> createState() => _FeedTimelineCardState();
}

class _FeedTimelineCardState extends State<FeedTimelineCard> {
  bool _isSubmitting = false;

  static const _green = Color(0xFF22C55E);
  static const _greenDark = Color(0xFF16A34A);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _ink = Color(0xFF1E293B);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final isDone = widget.state == FeedRoundState.done;
    final isCurrent = widget.state == FeedRoundState.current;
    final isUpcoming = widget.state == FeedRoundState.upcoming;

    // Amber border when fed but tray check is still required
    final Color borderColor = widget.isPendingTray
        ? _amber
        : isCurrent
            ? _green
            : _slate200;
    final double borderWidth = (isCurrent || widget.isPendingTray) ? 2.0 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (isCurrent)
            BoxShadow(color: _green.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))
          else if (widget.isPendingTray)
            BoxShadow(color: _amber.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3))
          else
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ROUND ${widget.round} • ${widget.time}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isCurrent ? _greenDark : _slate400,
                  ),
                ),
                Row(
                  children: [
                    // Edit button — available on current & done rounds (not upcoming)
                    if (!isUpcoming && widget.onEdit != null)
                      GestureDetector(
                        onTap: () => _showEditDialog(context),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.edit_rounded, size: 13, color: _slate400),
                        ),
                      ),
                    _badge(isDone, isCurrent),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Feed amount ─────────────────────────────────────────────
            Text(
              "${widget.feedQty.toStringAsFixed(1)} kg",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isUpcoming ? _slate400 : _ink,
              ),
            ),

            // ── Tray check pending hint (DOC > 30, fed but tray not logged) ─
            if (widget.isPendingTray) ...[
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.pending_actions_rounded, size: 12, color: _amber),
                  SizedBox(width: 4),
                  Text(
                    "Tray check required",
                    style: TextStyle(fontSize: 11, color: _amber, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],

            // ── Tray statuses once logged ────────────────────────────────
            if (isDone &&
                !widget.isPendingTray &&
                widget.trayStatuses != null &&
                widget.trayStatuses!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _trayStatusRow(),
            ],

            // ── Supplements ─────────────────────────────────────────────
            if (widget.supplements.isNotEmpty && !isUpcoming) ...[
              const SizedBox(height: 10),
              _supplementsRow(),
            ],

            // ── MARK AS FED button (current, unfed) ─────────────────────
            if (isCurrent && widget.onMarkDone != null) ...[
              const SizedBox(height: 14),
              _markAsFedButton(),
            ],

            // ── LOG TRAY button (done but tray pending) ──────────────────
            if (isDone && widget.isPendingTray && widget.onLogTray != null) ...[
              const SizedBox(height: 10),
              _logTrayButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Badge ─────────────────────────────────────────────────────────────────

  Widget _badge(bool isDone, bool isCurrent) {
    if (isDone) {
      // Always "DONE" — tray pending state is communicated by the amber button below
      return _chip(
        label: "DONE",
        textColor: _green,
        border: Border.all(color: _green, width: 1.5),
        bg: Colors.transparent,
      );
    } else if (isCurrent) {
      return _chip(label: "CURRENT", textColor: Colors.white, bg: _green);
    } else {
      return _chip(label: "UPCOMING", textColor: _slate400, bg: _slate100);
    }
  }

  Widget _chip({
    required String label,
    required Color textColor,
    Color bg = Colors.transparent,
    Border? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Edit dialog ───────────────────────────────────────────────────────────

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
                  // Minus
                  _stepBtn(
                    icon: Icons.remove,
                    onTap: () => setDlg(() {
                      editAmount = (editAmount - 0.5).clamp(0.0, 500.0);
                    }),
                  ),
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
                            color: _ink,
                          ),
                        ),
                        const Text("tap to type",
                            style: TextStyle(fontSize: 10, color: _slate400)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Plus
                  _stepBtn(
                    icon: Icons.add,
                    onTap: () => setDlg(() {
                      editAmount = (editAmount + 0.5).clamp(0.0, 500.0);
                    }),
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: _green),
              child: const Text("Save",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: _ink),
      ),
    );
  }

  // ── MARK AS FED ───────────────────────────────────────────────────────────

  Widget _markAsFedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                widget.onMarkDone?.call();
                if (mounted) setState(() => _isSubmitting = false);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                "MARK AS FED",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }

  // ── LOG TRAY ──────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── Tray status grid ──────────────────────────────────────────────────────

  Widget _trayStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(widget.trayStatuses!.length.clamp(1, 4), (i) {
          final status = widget.trayStatuses![i];
          return Column(
            children: [
              Text(
                "T${i + 1}",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _slate400,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: status.color,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Supplements ───────────────────────────────────────────────────────────

  Widget _supplementsRow() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: widget.supplements.map((s) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grain_rounded, size: 10, color: Color(0xFF818CF8)),
              const SizedBox(width: 4),
              Text(
                s,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3730A3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Timeline dot helpers (used in pond_dashboard_screen) ─────────────────────

Widget buildTimelineDot(FeedRoundState state, {bool isPendingTray = false}) {
  const green = Color(0xFF22C55E);
  const amber = Color(0xFFF59E0B);
  const slate300 = Color(0xFFCBD5E1);

  switch (state) {
    case FeedRoundState.done:
      // Amber check when tray is still required; green check when fully done
      final color = isPendingTray ? amber : green;
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );

    case FeedRoundState.current:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: green, width: 2.5),
          color: Colors.white,
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
          ),
        ),
      );

    case FeedRoundState.upcoming:
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: slate300, width: 2),
          color: Colors.white,
        ),
      );
  }
}
