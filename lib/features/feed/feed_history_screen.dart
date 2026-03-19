import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tray/tray_provider.dart';
import 'feed_provider.dart';
import 'feed_adjustment_engine.dart';

class FeedHistoryScreen extends ConsumerWidget {
  final String pondId;
  const FeedHistoryScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider(pondId));
    final notifier = ref.watch(feedProvider(pondId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Feed History"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddFeed(context, ref),
        child: const Icon(Icons.add),
      ),

      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (feeds) {
          /// 🔥 GROUP BY DOC
          Map<int, List<FeedEntry>> grouped = {};
          for (var f in feeds) {
            grouped.putIfAbsent(f.doc, () => []).add(f);
          }

          final docs = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          final totalFeed = notifier.totalFeed;
          final todayFeed = notifier.todayTotalFeed();

          return Column(
            children: [
              /// 🔝 HEADER
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text("Total Entries: ${feeds.length}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Total Feed: ${totalFeed.toStringAsFixed(2)} kg"),
                    Text("Today Feed: ${todayFeed.toStringAsFixed(2)} kg"),
                  ],
                ),
              ),

              /// 📊 HEADER
              Container(
                color: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  children: [
                    _Cell("DOC", flex: 2),
                    _Cell("R1"),
                    _Cell("R2"),
                    _Cell("R3"),
                    _Cell("R4"),
                    _Cell("TOT"),
                  ],
                ),
              ),

              /// 📋 BODY
              Expanded(
                child: feeds.isEmpty
                    ? const Center(child: Text("No feed added yet"))
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final list = grouped[doc]!;

                          double r1 = 0, r2 = 0, r3 = 0, r4 = 0;
                          bool a1 = false, a2 = false, a3 = false, a4 = false;

                          for (var f in list) {
                            if (f.round == 1) { r1 += f.quantity; if (f.wasAdjusted) a1 = true; }
                            if (f.round == 2) { r2 += f.quantity; if (f.wasAdjusted) a2 = true; }
                            if (f.round == 3) { r3 += f.quantity; if (f.wasAdjusted) a3 = true; }
                            if (f.round == 4) { r4 += f.quantity; if (f.wasAdjusted) a4 = true; }
                          }

                          final total = r1 + r2 + r3 + r4;

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey),
                              ),
                            ),
                            child: Row(
                              children: [
                                _Cell("$doc", flex: 2, isBold: true),
                                _Cell(r1 == 0 ? "-" : r1.toString(), isAdjusted: a1),
                                _Cell(r2 == 0 ? "-" : r2.toString(), isAdjusted: a2),
                                _Cell(r3 == 0 ? "-" : r3.toString(), isAdjusted: a3),
                                _Cell(r4 == 0 ? "-" : r4.toString(), isAdjusted: a4),
                                _Cell(
                                  total.toStringAsFixed(1),
                                  isBold: true,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 🔥 ADD FEED WITH TRAY LOGIC
  void _openAddFeed(BuildContext context, WidgetRef ref) {
    final qtyController = TextEditingController();
    final docController = TextEditingController();
    int round = 1;
    String feedType = "Grower";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {

            /// 🔥 GET TRAY FACTOR
            final trayState = ref.watch(trayProvider(pondId));
            final adjustment = FeedAdjustmentEngine.getFeedAdjustment(trayState);
            final trayFactor = 1.0 + adjustment;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// DOC
                  TextField(
                    controller: docController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "DOC"),
                  ),

                  /// QTY
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Quantity (kg)"),
                  ),

                  const SizedBox(height: 10),

                  /// ROUND
                  DropdownButton<int>(
                    value: round,
                    isExpanded: true,
                    items: [1, 2, 3, 4]
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text("Round $r"),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => round = v!);
                    },
                  ),

                  /// FEED TYPE
                  DropdownButton<String>(
                    value: feedType,
                    isExpanded: true,
                    items: ["Starter", "Grower", "Finisher"]
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => feedType = v!);
                    },
                  ),

                  const SizedBox(height: 10),

                  /// 🔥 SHOW ADJUSTMENT
                  Text("Tray Factor: x${trayFactor.toStringAsFixed(2)}"),

                  const SizedBox(height: 10),

                  /// SAVE
                  ElevatedButton(
                    onPressed: () {
                      final baseQty =
                          double.tryParse(qtyController.text) ?? 0;
                      final doc =
                          int.tryParse(docController.text) ?? 0;

                      if (baseQty <= 0 || doc <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Enter valid values")),
                        );
                        return;
                      }

                      /// 🔥 APPLY TRAY LOGIC
                      final adjustedQty = baseQty * trayFactor;
                      final bool wasAdjusted = trayFactor != 1.0;

                      ref
                          .read(feedProvider(pondId).notifier)
                          .addFeed( // Async action, fire and forget
                        FeedEntry(
                          doc: doc,
                          round: round,
                          quantity: adjustedQty,
                          feedType: feedType,
                          time: DateTime.now(),
                          wasAdjusted: wasAdjusted,
                        ),
                      );

                      Navigator.pop(context);
                    },
                    child: const Text("Save Feed"),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// TABLE CELL
class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;
  final Color? color;
  final bool isAdjusted;

  const _Cell(
    this.text, {
    this.flex = 1,
    this.isBold = false,
    this.color,
    this.isAdjusted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
          if (isAdjusted) ...[
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 14, color: Colors.orange),
          ]
        ],
      ),
    );
  }
}