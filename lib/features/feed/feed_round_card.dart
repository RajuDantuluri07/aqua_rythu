import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aqua_rythu/features/pond/pond_dashboard_provider.dart';
import 'package:aqua_rythu/features/supplements/supplement_provider.dart';
import 'package:aqua_rythu/features/supplements/feed_mix_engine.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/supplement_chip.dart';

/// 🔁 Round → Feeding Time
/// UPDATED: Basic mapping. For full PRD compliance (6 rounds),
/// the underlying data model needs to support r5/r6.
String mapRoundToTimeKey(int round, int doc) {
  // PRD 5.5: DOC 1-15 (6 rounds) - 6, 8:30, 11, 1:30, 4, 6:30
  // Since we only have 4 slots in DB, we map the 4 most critical times for now.
  if (doc <= 15) {
     // Temporary mapping for Beginner mode until DB migration
     if (round == 1) return "6:00 AM";
     if (round == 2) return "10:00 AM"; // merged
     if (round == 3) return "2:00 PM";  // merged
     if (round == 4) return "6:00 PM";
  }
  
  switch (round) {
    case 1:
      return "6 AM";
    case 2:
      return "10 AM";
    case 3:
      return "2 PM";
    case 4:
      return "6 PM";
    default:
      return "6 AM";
  }

}

class FeedRoundCard extends ConsumerStatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final double? originalQty; // Added for strikethrough display
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showTrayCTA;
  final bool isPendingTray;
  final bool isAutoAdjusted;
  final Function(int) onOpenTray;
  final VoidCallback? onMarkDone;

  const FeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    this.originalQty,
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showTrayCTA,
    this.isPendingTray = false,
    this.isAutoAdjusted = false,
    required this.onOpenTray,
    this.onMarkDone,
  });

  @override
  ConsumerState<FeedRoundCard> createState() => _FeedRoundCardState();
}

class _FeedRoundCardState extends ConsumerState<FeedRoundCard> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final supplements = ref.watch(supplementProvider);

    final trayStatus = dashboardState.trayResults[widget.round];
    final tray = trayStatus?.name;

    /// ✅ FROM PROVIDER
    final currentDoc = dashboardState.doc;

    /// 🔁 Map round
    final feedingTime = mapRoundToTimeKey(widget.round, currentDoc);

    /// 🧠 Calculate supplements
    final supplementResults = SupplementCalculator.calculate(
      supplements: supplements,
      currentDoc: currentDoc,
      currentFeedingTime: feedingTime,
      feedQty: widget.feedQty, // ✅ Uses passed qty (plan-based), not static state
    );

    // Determine adjustment direction
    final bool isIncreased = widget.isAutoAdjusted && widget.originalQty != null && widget.feedQty > widget.originalQty!;
    final bool isDecreased = widget.isAutoAdjusted && widget.originalQty != null && widget.feedQty < widget.originalQty!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s + 2),
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      decoration: BoxDecoration(
        color: widget.isLocked ? Colors.grey.shade100 : (widget.isCurrent ? AppColors.success.withOpacity(0.05) : Colors.white),
        borderRadius: AppRadius.rBase,
        border: widget.isLocked
            ? Border.all(color: AppColors.border)
            : (widget.isPendingTray 
                ? Border.all(color: AppColors.warning, width: 2) // ⚠️ Pending Tray Border
                : widget.isCurrent
                ? Border.all(color: AppColors.success, width: 2)
                : Border.all(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔝 TOP HEADER ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row
                    Row(
                      children: [
                        if (widget.isCurrent) ...[
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4), // Fixed: Explicit value
                            ),
                            child: const Text("NOW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (widget.isAutoAdjusted) ...[
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isIncreased ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB), // Green for up, Amber for down
                              borderRadius: BorderRadius.circular(4), // Fixed: Explicit value
                              border: Border.all(color: isIncreased ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                            ),
                            child: Text("AUTO ADJUSTED", style: TextStyle(color: isIncreased ? const Color(0xFF059669) : const Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    AppSpacing.hS,
                    Text(
                      "Round ${widget.round} • ${widget.time}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.isCurrent && !widget.isDone && !widget.isLocked) ...[
                      AppSpacing.hS,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(6), // Fixed: Explicit value
                        ),
                        child: const Text(
                          "RECOMMENDED ACTION",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              /// ⚖️ WEIGHT DISPLAY (TOP RIGHT)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${widget.feedQty.toStringAsFixed(1)}",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        "kg",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  if (widget.isAutoAdjusted && widget.originalQty != null)
                    Text(
                      "${widget.originalQty!.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          if (!widget.isCurrent && widget.isLocked)
             const Padding(
               padding: EdgeInsets.only(top: 8),
               child: Icon(Icons.lock, size: 16, color: Colors.grey),
             ),

          if (widget.isPendingTray)
             Padding(
               padding: const EdgeInsets.only(top: AppSpacing.m),
               child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                  AppSpacing.wS,
                  const Text("TRAY CHECK PENDING", style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold)),
                ],
              ),
             ),



          const SizedBox(height: 8),

          /// ⚠️ ADJUSTMENT INFO (Reduced)
          if (isDecreased) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.m),
              margin: const EdgeInsets.only(bottom: AppSpacing.m, top: AppSpacing.s),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFCE8),
                borderRadius: AppRadius.rm,
                border: Border.all(color: const Color(0xFFFEF08A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFF854D0E)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Feed reduced due to leftover",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF854D0E), fontSize: 13),
                        ),
                        Text(
                          "Previous: ${widget.originalQty!.toStringAsFixed(1)} kg → Now: ${widget.feedQty.toStringAsFixed(1)} kg",
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          /// 📈 ADJUSTMENT INFO (Increased)
          if (isIncreased) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.m),
              margin: const EdgeInsets.only(bottom: AppSpacing.m, top: AppSpacing.s),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: AppRadius.rm,
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 20, color: Color(0xFF047857)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Feed increased (Good appetite)",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 13),
                        ),
                        Text(
                          "Previous: ${widget.originalQty!.toStringAsFixed(1)} kg → Now: ${widget.feedQty.toStringAsFixed(1)} kg",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],


          /// TRAY
          if (tray != null)
            Text(
              "Tray: $tray",
              style: const TextStyle(color: Colors.grey),
            ),

          /// 🧠 SUPPLEMENTS (COMPACT)
          if (!widget.isLocked && supplementResults.isNotEmpty) ...[
            AppSpacing.hS,
            _buildCompactSupplements(context, supplementResults),
          ],

          AppSpacing.hS,

          /// BUTTONS
          if (widget.isCurrent && !widget.isDone && !widget.isLocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () async {
                  if (widget.onMarkDone != null) {
                    setState(() => _isSubmitting = true);
                    widget.onMarkDone!(); 
                    // Note: Widget typically rebuilds as DONE immediately after state update, 
                    // so resetting _isSubmitting to false isn't strictly visible but good practice.
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        AppSpacing.wS,
                        const Text("MARK AS FED", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
              ),
            )


          else if (widget.isDone && !widget.isPendingTray)
            Row( // Only show simple "Feeding Completed" if tray is also done (or not needed)
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                AppSpacing.wS,
                const Text("Feeding Completed", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),

          if (widget.showTrayCTA) ...[
             AppSpacing.hS,
             SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.onOpenTray(widget.round),
                child: Text(trayStatus != null ? "Update Tray" : "Log Tray Check"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSupplements(BuildContext context, List<CalculatedItem> results) {
    final List<SupplementItem> items = results.map((item) => SupplementItem(
          name: item.name,
          unit: item.unit,
          dosePerKg: item.quantity,
        )).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    if (items.length <= 2) {
      // Case A: ≤ 2 items → Horizontal row
      return Row(
        children: items.map((s) => SupplementChip(item: s)).toList(),
      );
    } else if (items.length <= 4) {
      // Case B: 3–4 items → 2-column grid
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.5,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: items.map((s) => SupplementChip(item: s)).toList(),
      );
    } else {
      // Case C: > 4 items → Show first 2 + “+N more”
      return Row(
        children: [
          SupplementChip(item: items[0]),
          SupplementChip(item: items[1]),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              "+${items.length - 2} more",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
        ],
      );
    }
  }
}