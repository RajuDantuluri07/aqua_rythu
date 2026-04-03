import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/models/feed_output.dart';
import 'smart_feed_provider.dart';

/// 🎯 SIMPLIFIED ROUND CARD for MVP
/// 
/// Shows:
/// - Planned feed (from feed_plans table - single source of truth)
/// - Manual override capability
/// - Basic feed logging functionality

class SmartFeedRoundCard extends ConsumerStatefulWidget {
  final String pondId;
  final int round;
  final String time;
  final double plannedFeed;
  final int doc;  // ✅ Days on cluster (for DOC-based tray logic)
  final bool showTrayCTA;  // ✅ Whether to show tray CTA after feeding
  final Function(double overrideFeed) onMarkFed;  // ✅ Now accepts override amount
  final bool isFeedDone; // ✅ Indicates if the feed for this round is already marked done
  final VoidCallback? onLogTray;  // ✅ Callback to log tray (optional)

  const SmartFeedRoundCard({
    super.key,
    required this.pondId,
    required this.round,
    required this.time,
    required this.plannedFeed,
    required this.doc,
    required this.showTrayCTA,
    required this.isFeedDone,
    required this.onMarkFed,
    this.onLogTray,
  });

  @override
  ConsumerState<SmartFeedRoundCard> createState() =>
      _SmartFeedRoundCardState();
}

class _SmartFeedRoundCardState extends ConsumerState<SmartFeedRoundCard> { // No longer needs _isMarked
  late double _overrideAmount;

  @override
  void initState() {
    super.initState();
    _overrideAmount = widget.plannedFeed; // Use planned feed as default for MVP
  }

  void _showOverrideDialog() {
    _overrideAmount = widget.plannedFeed; // Use planned feed for MVP

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Manual Feed Override"),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Stepper: [ − ] VALUE [ + ]
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _overrideAmount = double.parse(
                          (_overrideAmount - 0.25).clamp(0.0, 1000.0).toStringAsFixed(1),
                        );
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.remove, size: 24, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Value display (tappable for manual input)
                  GestureDetector(
                    onTap: () {
                      _showManualInputDialog(context, setState);
                    },
                    child: Column(
                      children: [
                        Text(
                          "${_overrideAmount.toStringAsFixed(1)} kg",
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "tap to edit",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Plus button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _overrideAmount = double.parse(
                          (_overrideAmount + 0.25).clamp(0.0, 1000.0).toStringAsFixed(1),
                        );
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 24, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Mark feed with manual override amount
              widget.onMarkFed(_overrideAmount);
              // Success feedback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "✅ Logged ${_overrideAmount.toStringAsFixed(1)} kg",
                  ),
                  backgroundColor: Colors.green[700],
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog(BuildContext parentContext, Function(VoidCallback) setDialogState) {
    final controller = TextEditingController(text: _overrideAmount.toStringAsFixed(1));

    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text("Enter Feed Amount"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: "e.g., 2.5",
            labelText: "Feed (kg)",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              double? value = double.tryParse(controller.text);
              if (value != null && value >= 0 && value <= 1000) {
                value = double.parse(value.toStringAsFixed(1));
                setDialogState(() {
                  _overrideAmount = value!;
                });
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Enter a value between 0 and 1000 kg"),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text("Set"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          /// 🔝 HEADER
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Round ${widget.round} • ${widget.time}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "READY",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 📊 FEED AMOUNT SECTION (MVP - Simple)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Planned Feed Amount
                Row(
                  children: [
                    Expanded(
                      child: _buildFeedColumn("Planned Feed", widget.plannedFeed, Colors.blue),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// 📝 INFO
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Feed amount based on farm plan for DOC ${widget.doc}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// 🔘 ACTION BUTTONS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                if (!widget.isFeedDone) // If feed is NOT done, show Mark as Fed/Edit
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Use planned feed for MVP
                        final feedAmount = widget.plannedFeed;
                        widget.onMarkFed(feedAmount);
                        // Then log tray if available
                        if (widget.onLogTray != null) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            widget.onLogTray!();
                          });
                        }
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Mark as Fed"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                /// 2️⃣ EDIT BUTTON (only before marking)
                // Show edit button if feed is NOT done, or if feed is done but tray is still pending (allowing adjustment)
                // The logic for showing edit button for pending tray is complex, for now, only show if feed is not done.
                if (!widget.isFeedDone)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      tooltip: "Edit feed amount",
                      onPressed: () {
                        _showOverrideDialog();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: const Color(0xFF1E293B),
                      ),
                    ),
                  ),

                /// 3️⃣ LOG TRAY CTA (if feed is done AND tray is required/pending)
                if (widget.isFeedDone && widget.showTrayCTA && widget.onLogTray != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onLogTray,
                      icon: const Icon(Icons.checklist_rounded),
                      label: Text(
                        widget.doc > 30 ? "Log Tray (Required)" : "Log Tray"
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[50],
                        foregroundColor: Colors.orange[700],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedColumn(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${value.toStringAsFixed(1)} kg",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 📋 OVERRIDE DIALOG
void showFeedOverrideDialog(
  BuildContext context, {
  required double suggestedFeed,
  required double plannedFeed,
  required Function(double actualFeed, String reason) onSave,
}) {
  final TextEditingController controller = TextEditingController(
    text: suggestedFeed.toStringAsFixed(1),
  );

  String? selectedReason;
  final reasons = [
    "Farmer observation",
    "Fish behavior",
    "Equipment issue",
    "Other",
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Override Feed Quantity",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            /// Suggested vs Planned comparison
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        "Suggested",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${suggestedFeed.toStringAsFixed(1)} kg",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        "Planned",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${plannedFeed.toStringAsFixed(1)} kg",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// Input field
            const Text(
              "Enter actual feed quantity",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: "e.g., 14.5",
                suffix: const Text("kg"),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Reason selection
            const Text(
              "Reason for override",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: reasons
                  .map((r) => FilterChip(
                        label: Text(r),
                        selected: selectedReason == r,
                        onSelected: (selected) {
                          setState(() {
                            selectedReason = selected ? r : null;
                          });
                        },
                      ))
                  .toList(),
            ),

            const SizedBox(height: 20),

            /// Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  if (value != null && selectedReason != null) {
                    onSave(value, selectedReason!);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save Override"),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
