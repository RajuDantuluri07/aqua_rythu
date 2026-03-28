import 'package:flutter/material.dart';
import '../../core/enums/tray_status.dart';
import '../../core/theme/app_theme.dart';

class CompletedRoundCard extends StatelessWidget {
  final int round;
  final String time;
  final double feedQty;
  final double? originalQty;
  final List<TrayStatus>? trayStatuses;
  final List<String> supplements;
  final bool showTraySummary;
  final VoidCallback? onLogTray;

  const CompletedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    this.originalQty,
    this.trayStatuses,
    this.supplements = const [],
    this.showTraySummary = true,
    this.onLogTray,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAutoAdjusted =
        originalQty != null && (feedQty - originalQty!).abs() > 0.01;
    final bool isIncreased = isAutoAdjusted && feedQty > originalQty!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s + 2),
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rBase,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔝 HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("DONE",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (isAutoAdjusted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isIncreased
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: isIncreased
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFDE68A)),
                          ),
                          child: Text("ADJUSTED",
                              style: TextStyle(
                                  color: isIncreased
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFD97706),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.hS,
                  Text(
                    "Round $round • $time",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        feedQty.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text("kg",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                    ],
                  ),
                  if (isAutoAdjusted && originalQty != null)
                    Text(
                      "${originalQty!.toStringAsFixed(1)} kg",
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

          /// 🧠 SUPPLEMENTS DISPLAY
          if (supplements.isNotEmpty) ...[
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
                      Icon(Icons.medication_liquid_rounded,
                          size: 14, color: Colors.indigo.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "SUPPLEMENTS APPLIED",
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
                    children: supplements.map((s) {
                      final IconData unitIcon = s.toLowerCase().contains('ml')
                          ? Icons.science_rounded
                          : Icons.grain_rounded;

                      return Row(
                        children: [
                          Icon(unitIcon,
                              size: 12, color: Colors.indigo.shade300),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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

          /// 📥 TRAY SUMMARY BOX
          if (showTraySummary &&
              trayStatuses != null &&
              trayStatuses!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (i) {
                  final status =
                      (trayStatuses != null && trayStatuses!.length > i)
                          ? trayStatuses![i]
                          : null;
                  return Column(
                    children: [
                      Text(
                        "TRAY ${i + 1}",
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Fix #1: Removed unnecessary string interpolation
                        status?.label ?? "EMPTY",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: status?.color ?? const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${(feedQty * 10).toInt()}g", // Logic: ~10% per tray approx
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],

          if (onLogTray != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogTray,
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: Text(
                    trayStatuses != null ? "Update Tray" : "Log Tray Outcome"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
