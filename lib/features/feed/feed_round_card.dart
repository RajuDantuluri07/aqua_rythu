import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/features/pond/pond_dashboard_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

/// 🔁 Round → Feeding Time
String mapRoundToTimeKey(int round) {
  switch (round) {
    case 1:
      return "R1";
    case 2:
      return "R2";
    case 3:
      return "R3";
    case 4:
      return "R4";
    default:
      return "R1";
  }
}

class FeedRoundCard extends ConsumerStatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final double? originalQty;
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showTrayCTA;
  final bool isPendingTray;
  final bool isAutoAdjusted;
  final Function(int) onOpenTray;
  final List<SupplementItem> supplements;
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
    this.supplements = const [],
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

    final trayStatus = dashboardState.trayResults[widget.round];
    final tray = trayStatus?.name;

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
                ? Border.all(color: AppColors.warning, width: 2)
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
                    Row(
                      children: [
                        if (widget.isCurrent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text("NOW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: AppSpacing.s),
                        ],
                        if (widget.isAutoAdjusted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isIncreased ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isIncreased ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                            ),
                            child: Text("AUTO ADJUSTED", style: TextStyle(color: isIncreased ? const Color(0xFF059669) : const Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: AppSpacing.s),
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
                          borderRadius: BorderRadius.circular(6),
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
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.feedQty.toStringAsFixed(1),
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
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.m),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                  AppSpacing.wS,
                  Text("TRAY CHECK PENDING", style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const SizedBox(height: 8),

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

          if (tray != null)
            Text(
              "Tray: $tray",
              style: const TextStyle(color: Colors.grey),
            ),

          /// 🧠 SUPPLEMENTS DISPLAY
          if (!widget.isLocked && widget.supplements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medication, size: 14, color: Colors.indigo.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "SUPPLEMENTS TO USE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 4.5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 8,
                    children: widget.supplements.map((s) {
                      final IconData unitIcon = s.unit.toLowerCase().contains('ml')
                          ? Icons.science_rounded
                          : Icons.grain_rounded;

                      return Row(
                        children: [
                          Icon(unitIcon, size: 12, color: Colors.indigo.shade300),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${s.name} ${s.quantity.toStringAsFixed(1)}${s.unit}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          AppSpacing.hS,

          if (widget.isCurrent && !widget.isDone && !widget.isLocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () async {
                  if (widget.onMarkDone != null) {
                    setState(() => _isSubmitting = true);
                    widget.onMarkDone!();
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20),
                        AppSpacing.wS,
                        Text("MARK AS FED", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
              ),
            )
          else if (widget.isDone && !widget.isPendingTray)
            const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                AppSpacing.wS,
                Text("Feeding Completed", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
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
}