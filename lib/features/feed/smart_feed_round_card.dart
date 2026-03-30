import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/engines/models/feed_output.dart';
import 'smart_feed_provider.dart';
import 'feed_history_provider.dart';

/// 🎯 ENHANCED ROUND CARD with Planned vs Smart vs Actual comparison
/// 
/// Shows:
/// - Planned feed (from blind plan)
/// - Smart feed (real-time calculation)
/// - Actual feed (logged by user)
/// - Reasons for adjustment
/// - Override capability

class SmartFeedRoundCard extends ConsumerStatefulWidget {
  final String pondId;
  final int round;
  final String time;
  final double plannedFeed;
  final double? smartFeed;
  final FeedOutput? engineOutput;
  final VoidCallback onMarkFed;
  final VoidCallback onOverride;

  const SmartFeedRoundCard({
    super.key,
    required this.pondId,
    required this.round,
    required this.time,
    required this.plannedFeed,
    this.smartFeed,
    this.engineOutput,
    required this.onMarkFed,
    required this.onOverride,
  });

  @override
  ConsumerState<SmartFeedRoundCard> createState() =>
      _SmartFeedRoundCardState();
}

class _SmartFeedRoundCardState extends ConsumerState<SmartFeedRoundCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final smartFeed = ref.watch(smartFeedProvider(widget.pondId));

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

          /// 📊 COMPARISON SECTION
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Planned vs Smart vs Actual
                Row(
                  children: [
                    _buildFeedColumn("Planned", widget.plannedFeed, Colors.grey),
                    const SizedBox(width: 12),
                    if (smartFeed.when(
                      data: (data) => data != null,
                      loading: () => false,
                      error: (_, __) => false,
                    ))
                      _buildFeedColumn(
                        "Smart",
                        smartFeed.whenData((data) => data?.engineOutput.recommendedFeed ?? 0).maybeWhen(
                          data: (v) => v,
                          orElse: () => 0,
                        ),
                        Colors.blue,
                      )
                    else
                      _buildFeedColumn("Smart", widget.plannedFeed, Colors.grey),
                    const SizedBox(width: 12),
                    _buildFeedColumn("Actual", 0, Colors.green),
                  ],
                ),

                const SizedBox(height: 16),

                /// 📝 REASONS
                if (smartFeed.whenData((data) => data?.engineOutput.reasons).maybeWhen(
                  data: (reasons) => reasons != null && reasons.isNotEmpty,
                  orElse: () => false,
                ))
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 14, color: Color(0xFF0284C7)),
                            SizedBox(width: 6),
                            Text(
                              "ADJUSTMENT REASONS",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...smartFeed.whenData((data) => data?.engineOutput.reasons).maybeWhen(
                          data: (reasons) => reasons
                              ?.map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF0284C7),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList() ??
                              [],
                          orElse: () => [],
                        ),
                      ],
                    ),
                  ),

                /// ⚠️ CRITICAL ALERTS
                if (smartFeed.whenData((data) => data?.isStopFeeding).maybeWhen(
                  data: (isStop) => isStop,
                  orElse: () => false,
                ))
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            size: 18, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            smartFeed.whenData((data) => data?.stopReason).maybeWhen(
                              data: (reason) => reason ?? "Stop feeding",
                              orElse: () => "Stop feeding",
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onMarkFed,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Mark as Fed"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onOverride,
                  icon: const Icon(Icons.edit),
                  label: const Text("Override"),
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
