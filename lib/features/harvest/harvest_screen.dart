import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'harvest_provider.dart';

class HarvestScreen extends ConsumerStatefulWidget {
  final String pondId;
  const HarvestScreen({super.key, required this.pondId});

  @override
  ConsumerState<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends ConsumerState<HarvestScreen> {

  void _openHarvestForm(BuildContext context, {required bool isFinal}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HarvestFormSheet(isFinal: isFinal),
    );

    if (result != null && result is Map<String, String>) {
      final qty = double.tryParse(result["qty"] ?? "0") ?? 0;
      final doc = int.tryParse(result["doc"] ?? "0") ?? 0;
      final type = result["type"] ?? "partial";

      ref.read(harvestProvider(widget.pondId).notifier).addHarvest(
            HarvestEntry(
              doc: doc,
              quantity: qty,
              type: type.toLowerCase(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {

    final harvestList = ref.watch(harvestProvider(widget.pondId));
    final harvestNotifier = ref.watch(harvestProvider(widget.pondId).notifier);
    final doc = ref.watch(docProvider(widget.pondId));

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.pondId} • Harvest Hub"),
      ),
      body: Column(
        children: [

          /// CONTENT
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                /// HEADER
                Row(
                  children: [
                    Chip(label: Text("DOC: $doc")),
                    const SizedBox(width: 10),
                    Text(
                      "Total Yield: ${harvestNotifier.totalHarvest.toStringAsFixed(0)} kg",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// BUTTONS
                OutlinedButton.icon(
                  onPressed: () => _openHarvestForm(context, isFinal: false),
                  icon: const Icon(Icons.add),
                  label: const Text("Log Partial Harvest"),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () => _openHarvestForm(context, isFinal: true),
                  icon: const Icon(Icons.flag),
                  label: const Text("Final Harvest"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),

                const SizedBox(height: 20),

                /// LEDGER HEADER
                const Text(
                  "Harvest History",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                /// TABLE
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      _tableHeader(),
                      const Divider(),

                      /// 🔥 REAL DATA
                      ...harvestList.map((h) => _row({
                            "date": "Today",
                            "doc": h.doc.toString(),
                            "type": h.type.toUpperCase(),
                            "qty": h.quantity.toString(),
                            "size": "-",
                            "price": "-",
                          })),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// EMPTY STATE
                if (harvestList.isEmpty)
                  Column(
                    children: const [
                      Icon(Icons.insert_drive_file,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 5),
                      Text("No harvest data yet",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
              ],
            ),
          ),

          /// SUMMARY
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TOTAL YIELD: ${harvestNotifier.totalHarvest.toStringAsFixed(0)} kg",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  "₹ --",
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return const Row(
      children: [
        _Cell("DATE"),
        _Cell("DOC"),
        _Cell("TYPE"),
        _Cell("QTY"),
        _Cell("SIZE"),
        _Cell("PRICE"),
      ],
    );
  }

  Widget _row(Map<String, String> item) {
    return Row(
      children: [
        _Cell(item["date"] ?? ""),
        _Cell(item["doc"] ?? ""),
        _Cell(item["type"] ?? ""),
        _Cell(item["qty"] ?? ""),
        _Cell(item["size"] ?? ""),
        _Cell(item["price"] ?? ""),
      ],
    );
  }
}

/// CELL
class _Cell extends StatelessWidget {
  final String text;
  const _Cell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(6),
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}