import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'feed_history_provider.dart';
import '../../core/theme/app_theme.dart';

class FeedHistoryScreen extends ConsumerWidget {
  final String pondId;
  const FeedHistoryScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyMap = ref.watch(feedHistoryProvider);
    final logs = historyMap[pondId] ?? [];
    final currentDoc = ref.watch(docProvider(pondId));

    // Summary Stats
    final total7d =
        logs.take(7).fold(0.0, (sum, log) => sum + log.total);
    final previous7d =
        logs.skip(7).take(7).fold(0.0, (sum, log) => sum + log.total);
    double avg7d =
        logs.isNotEmpty ? (total7d / (logs.length > 7 ? 7 : logs.length)) : 0;
    final double? trendPercent = previous7d > 0
        ? ((total7d - previous7d) / previous7d) * 100
        : null;

    return Scaffold(
      backgroundColor: AppColors.cardBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text("Feed History",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(
                "${pondId.toUpperCase()} | DOC $currentDoc",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_outlined, size: 20)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.table_rows_outlined, size: 20)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.file_download_outlined, size: 20)),
        ],
        elevation: 0.5,
        backgroundColor: AppColors.cardBg,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary Strip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.m),
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      children: [
                        const TextSpan(text: "Last 7d: "),
                        TextSpan(
                            text: "${total7d.toInt()}kg ",
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        TextSpan(
                          text: trendPercent == null
                              ? "(-- ) "
                              : "(${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}%) ",
                          style: TextStyle(
                            color: trendPercent == null
                                ? AppColors.textSecondary
                                : trendPercent >= 0
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: "| Avg: "),
                        TextSpan(
                            text: "${avg7d.toInt()}kg",
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius:
                        BorderRadius.circular(4), // Fixed: Explicit value
                  ),
                  child: Row(
                    children: [
                      const Text("DOC: ",
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold)),
                      Text("$currentDoc",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            color: const Color(0xFFF1F5F9), // Light blue-grey header
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            child: Row(
              children: [
                _headerCell("DATE", flex: 3),
                _headerCell("DOC", flex: 1),
                _headerCell("R1", flex: 1),
                _headerCell("R2", flex: 1),
                _headerCell("R3", flex: 1),
                _headerCell("R4", flex: 1),
                _headerCell("TOT", flex: 2),
                _headerCell("Δ", flex: 2),
                _headerCell("CUM", flex: 2),
                _headerCell("ST", flex: 1),
              ],
            ),
          ),

          // Scrollable List
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          "No feed logs yet",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Feed rounds you mark done will appear here.",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final prevLog =
                          (index + 1 < logs.length) ? logs[index + 1] : null;
                      final delta =
                          (prevLog != null) ? (log.total - prevLog.total) : 0.0;

                      return _buildHistoryRow(log, index == 0, delta);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHistoryRow(FeedHistoryLog log, bool isToday, double delta) {
    final dateFormat = DateFormat('dd MMM');
    final String dateStr = isToday
        ? "Today, ${dateFormat.format(log.date)}"
        : dateFormat.format(log.date);

    final bool incomplete = log.rounds.any((qty) => qty <= 0);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // DATE
            _dataCell(dateStr,
                flex: 3,
                bold: isToday,
                color: isToday ? Colors.orange.shade700 : Colors.black87),
            _vDivider(),
            // DOC
            _dataCell("${log.doc}",
                flex: 1,
                color: isToday ? Colors.black87 : Colors.grey.shade500,
                bold: isToday),
            _vDivider(),
            // R1-R4
            ...List.generate(4, (i) {
              final val = (i < log.rounds.length) ? log.rounds[i] : 0.0;
              final isMissing = val <= 0;
              return Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMissing ? "--" : val.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isToday ? FontWeight.w900 : FontWeight.w500,
                          color:
                              isMissing ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ),
                    _vDivider(),
                  ],
                ),
              );
            }),
            // TOT
            _dataCell(log.total.toStringAsFixed(1),
                flex: 2, color: const Color(0xFF10B981), bold: true),
            _vDivider(),
            // DELTA
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (delta != 0) ...[
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: delta > 0
                                  ? Colors.green.shade200
                                  : Colors.red.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              delta > 0 ? Icons.north_east : Icons.south_east,
                              size: 10,
                              color: delta > 0 ? Colors.green : Colors.red,
                            ),
                            Text(
                              delta.abs().toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: delta > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text("0.0",
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
            _vDivider(),
            // CUM
            _dataCell(log.cumulative.toInt().toString(),
                flex: 2, bold: true, color: Colors.grey.shade800),
            _vDivider(),
            // ST
            Expanded(
              flex: 1,
              child: Center(
                child: Icon(
                  incomplete
                      ? Icons.warning_amber_rounded
                      : Icons.check_rounded,
                  size: 16,
                  color: incomplete ? Colors.orange : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text,
      {required int flex, bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, color: AppColors.border.withOpacity(0.5));
}
