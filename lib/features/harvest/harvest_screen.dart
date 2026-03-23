import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'harvest_provider.dart';

class HarvestScreen extends ConsumerWidget {
  final String pondId;
  const HarvestScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvests = ref.watch(harvestProvider(pondId));
    final doc = ref.watch(docProvider(pondId));
    final notifier = ref.read(harvestProvider(pondId).notifier);

    final totalYield = notifier.totalHarvest;
    final totalRevenue = notifier.totalRevenue;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Harvest Hub",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("DOC $doc",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 1. Actions Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showHarvestModal(
                        context, ref, pondId, doc, "partial"),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Log Partial"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showHarvestModal(context, ref, pondId, doc, "final"),
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text("Final Harvest"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Ledger Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text("DATE",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(
                    flex: 2,
                    child: Text("TYPE",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(
                    flex: 2,
                    child: Text("QTY (Kg)",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(
                    flex: 2,
                    child: Text("REV (₹)",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
          ),

          // 3. List
          Expanded(
            child: harvests.isEmpty
                ? Center(
                    child: Text("No harvests recorded",
                        style: TextStyle(color: Colors.grey.shade400)))
                : ListView.separated(
                    itemCount: harvests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final h = harvests[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('dd MMM').format(h.date),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                    Text("DOC ${h.doc}",
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  ],
                                )),
                            Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: h.type == 'final'
                                          ? Colors.red.shade50
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    h.type.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: h.type == 'final'
                                            ? Colors.red
                                            : Colors.blue),
                                    textAlign: TextAlign.center,
                                  ),
                                )),
                            Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(h.quantity.toStringAsFixed(0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text("Cnt ${h.countPerKg}",
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  ],
                                )),
                            Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        "₹${(h.revenue / 1000).toStringAsFixed(1)}k",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green)),
                                    Text("₹${h.pricePerKg}/kg",
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  ],
                                )),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 4. Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10)
            ]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TOTAL YIELD",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      Text("${totalYield.toStringAsFixed(0)} kg",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text("TOTAL REVENUE",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  Text("₹${NumberFormat('#,##,###').format(totalRevenue)}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ]),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showHarvestModal(BuildContext context, WidgetRef ref, String pondId,
      int doc, String type) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) =>
            _HarvestLogModal(pondId: pondId, doc: doc, type: type));
  }
}

class _HarvestLogModal extends ConsumerStatefulWidget {
  final String pondId;
  final int doc;
  final String type;
  const _HarvestLogModal(
      {required this.pondId, required this.doc, required this.type});

  @override
  ConsumerState<_HarvestLogModal> createState() => _HarvestLogModalState();
}

class _HarvestLogModalState extends ConsumerState<_HarvestLogModal> {
  final _qtyCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  double get estimatedRevenue {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    return qty * price;
  }

  @override
  void initState() {
    super.initState();
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _countCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "Log ${widget.type == 'final' ? 'Final' : 'Partial'} Harvest",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _buildInput("Quantity (kg)", _qtyCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput("Count / kg", _countCtrl)),
            ]),
            const SizedBox(height: 16),
            _buildInput("Price (₹ / kg)", _priceCtrl),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Est. Revenue",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        "₹${NumberFormat('#,##,###').format(estimatedRevenue)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green)),
                  ]),
            ),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_qtyCtrl.text.isEmpty || _priceCtrl.text.isEmpty)
                      return;

                    final entry = HarvestEntry(
                      pondId: widget.pondId,
                      date: DateTime.now(),
                      doc: widget.doc,
                      quantity: double.parse(_qtyCtrl.text),
                      countPerKg: int.tryParse(_countCtrl.text) ?? 0,
                      pricePerKg: double.parse(_priceCtrl.text),
                      type: widget.type,
                    );

                    ref
                        .read(harvestProvider(widget.pondId).notifier)
                        .addHarvest(entry);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("SAVE HARVEST LOG"),
                )),
            const SizedBox(height: 24),
          ],
        ));
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }
}