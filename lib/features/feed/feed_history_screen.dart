import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'feed_history_provider.dart';

class FeedHistoryScreen extends ConsumerWidget {
  final String pondId;
  const FeedHistoryScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(feedHistoryProvider);

    // Calculate Summary Stats from mock data
    double total7d = 0;
    int count7d = 0;
    for (int i = 0; i < logs.length && i < 7; i++) {
       total7d += logs[i].total;
       count7d++;
    }
    double avg7d = count7d > 0 ? (total7d / count7d) : 0;
    
    // Hardcoded DOC for now based on first log if exists
    final currentDoc = logs.isNotEmpty ? logs.first.doc : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // 1. Premium Header
          SliverAppBar(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 50, bottom: 16),
              title: const Text(
                "Feed History",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.teal.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "POND 1 • DOC $currentDoc",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () {},
                tooltip: "Export PDF",
              ),
            ],
          ),

          // 2. Summary Strip
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SummaryStat(
                    label: "Last 7 Days",
                    value: "${total7d.toStringAsFixed(1)} kg",
                    icon: Icons.bar_chart_rounded,
                    color: Colors.blue,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _SummaryStat(
                    label: "Daily Avg",
                    value: "${avg7d.toStringAsFixed(1)} kg",
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),

          // 3. Ledger Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _LedgerHeaderCell("DATE", flex: 3),
                  _LedgerHeaderCell("DOC", flex: 2),
                  _LedgerHeaderCell("TOT", flex: 3),
                  _LedgerHeaderCell("Δ", flex: 2),
                  _LedgerHeaderCell("CUM", flex: 3),
                ],
              ),
            ),
          ),

          // 4. Ledger List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final log = logs[index];
                  final now = DateTime.now();
                  final isToday = log.date.year == now.year && log.date.month == now.month && log.date.day == now.day;
                  
                  return _LedgerRow(log: log, isToday: isToday);
                },
                childCount: logs.length,
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
            ],
          )
        ],
      ),
    );
  }
}

class _LedgerHeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _LedgerHeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _LedgerRow extends StatefulWidget {
  final FeedHistoryLog log;
  final bool isToday;

  const _LedgerRow({required this.log, required this.isToday});

  @override
  State<_LedgerRow> createState() => _LedgerRowState();
}

class _LedgerRowState extends State<_LedgerRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM');
    final String dateStr = widget.isToday ? "Today" : dateFormat.format(widget.log.date);
    
    final bool hasWarning = widget.log.isWarning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isToday ? Theme.of(context).primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: widget.isToday ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)) : Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
              child: Row(
                children: [
                  _Cell(dateStr, flex: 3, bold: widget.isToday, color: widget.isToday ? Theme.of(context).primaryColor : Colors.black87),
                  _Cell("${widget.log.doc}", flex: 2, color: Colors.grey.shade700),
                  _Cell(widget.log.total.toStringAsFixed(1), flex: 3, bold: true),
                  _Cell(
                    widget.log.delta > 0 ? "+${widget.log.delta.toStringAsFixed(1)}" : widget.log.delta.toStringAsFixed(1),
                    flex: 2,
                    color: widget.log.delta == 0 ? Colors.grey : (widget.log.delta > 0 ? Colors.green : Colors.red),
                    bold: widget.log.delta != 0,
                  ),
                  _Cell(widget.log.cumulative.toStringAsFixed(0), flex: 3, color: Colors.blue.shade700, bold: true),
                ],
              ),
            ),
            if (_expanded)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (hasWarning)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Feed consumption critically below expected (${widget.log.expected.toStringAsFixed(1)} kg). Check trays for uneaten feed.", style: TextStyle(color: Colors.red.shade900, fontSize: 12))),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(widget.log.rounds.length, (index) {
                        return Column(
                          children: [
                            Text("R${index + 1}", style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("${widget.log.rounds[index].toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;

  const _Cell(this.text, {required this.flex, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}