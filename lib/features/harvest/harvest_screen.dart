import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import 'harvest_provider.dart';
import 'harvest_summary_screen.dart';

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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Harvest Hub", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("Day of Culture: $doc", style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.black54),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Manage partial and final pond harvests here."),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.blue.shade600,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Actions Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showHarvestModal(context, ref, pondId, doc, "partial"),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: const Text("Log Partial", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showHarvestModal(context, ref, pondId, doc, "final"),
                    icon: const Icon(Icons.flag_rounded, size: 20),
                    label: const Text("Final Harvest", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Colors.red.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Ledger Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text("DATE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("TYPE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text("QTY (Kg)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 3,
                  child: Text("REVENUE (₹)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),

          // 3. List
          Expanded(
            child: harvests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
                          child: Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                        ),
                        const SizedBox(height: 16),
                        Text("No harvests recorded yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: harvests.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final h = harvests[index];
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('dd MMM').format(h.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text("DOC ${h.doc}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: h.type == 'final' ? Colors.red.shade50 : Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    h.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: h.type == 'final' ? Colors.red.shade700 : Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(h.quantity.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text("${h.countPerKg} Cnt", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₹${NumberFormat('#,##,###').format(h.revenue)}",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text("₹${h.pricePerKg}/kg", style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 4. Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  offset: const Offset(0, -5),
                  blurRadius: 20,
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TOTAL YIELD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                        "${NumberFormat('#,##,###').format(totalYield)} kg",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ],
                  ),
                  Container(height: 40, width: 1, color: Colors.grey.shade200),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("TOTAL REVENUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                        "₹${NumberFormat('#,##,###').format(totalRevenue)}",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showHarvestModal(BuildContext context, WidgetRef ref, String pondId, int doc, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HarvestLogModal(pondId: pondId, doc: doc, type: type),
    );
  }
}

class _HarvestLogModal extends ConsumerStatefulWidget {
  final String pondId;
  final int doc;
  final String type;
  const _HarvestLogModal({required this.pondId, required this.doc, required this.type});

  @override
  ConsumerState<_HarvestLogModal> createState() => _HarvestLogModalState();
}

class _HarvestLogModalState extends ConsumerState<_HarvestLogModal> {
  final _qtyCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _expensesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

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
    _expensesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinal = widget.type == 'final';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFinal ? Colors.red.shade50 : Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFinal ? Icons.flag_rounded : Icons.shopping_cart_rounded,
                  color: isFinal ? Colors.red.shade600 : Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Log ${isFinal ? 'Final' : 'Partial'} Harvest",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          
          if (isFinal) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This ends the current crop cycle. Feeding & sampling will be disabled.",
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else 
            const SizedBox(height: 32),

          // Inputs
          Row(
            children: [
              Expanded(child: _buildInput("Quantity", _qtyCtrl, "kg", Icons.scale_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _buildInput("Count", _countCtrl, "/ kg", Icons.numbers_rounded, isInteger: true)),
            ],
          ),
          _buildInput("Price", _priceCtrl, "₹ / kg", Icons.currency_rupee_rounded),
          const SizedBox(height: 20),
          _buildInput("Expenses", _expensesCtrl, "₹", Icons.money_off_rounded),
          const SizedBox(height: 20),
          _buildInput("Notes", _notesCtrl, "", Icons.notes_rounded),
          
          const SizedBox(height: 32),
          
          // Est Revenue Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor.withOpacity(0.05), Theme.of(context).primaryColor.withOpacity(0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Estimated Revenue", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    const Text("Based on qty & price", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(
                  "₹${NumberFormat('#,##,###').format(estimatedRevenue)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_qtyCtrl.text.isEmpty || _priceCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Quantity and Price are required"),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (isFinal) {
                  _showFinalConfirmation();
                } else {
                  _saveHarvest();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFinal ? Colors.red.shade600 : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: (isFinal ? Colors.red : Theme.of(context).primaryColor).withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(isFinal ? "COMPLETE CYCLE" : "SAVE HARVEST LOG", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Final Harvest Confirmation"),
        content: const Text("This will permanently close the pond cycle. You cannot add feed, tray logs, or supplements after this."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _saveHarvest(isFinal: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("CONFIRM HARVEST"),
          ),
        ],
      ),
    );
  }

  void _saveHarvest({bool isFinal = false}) {
    final entry = HarvestEntry(
      pondId: widget.pondId,
      date: DateTime.now(),
      doc: widget.doc,
      quantity: double.parse(_qtyCtrl.text),
      countPerKg: int.tryParse(_countCtrl.text) ?? 0,
      pricePerKg: double.parse(_priceCtrl.text),
      expenses: double.tryParse(_expensesCtrl.text) ?? 0,
      notes: _notesCtrl.text,
      type: widget.type,
    );

    ref.read(harvestProvider(widget.pondId).notifier).addHarvest(entry);
    
    if (isFinal) {
      ref.read(farmProvider.notifier).updatePondStatus(widget.pondId, PondStatus.completed);
      Navigator.pop(context); // Close modal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HarvestSummaryScreen(pondId: widget.pondId)),
      );
    } else {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFinal ? "Pond Cycle Completed!" : "Harvest logged successfully"),
        backgroundColor: isFinal ? Colors.purple : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Widget _buildInput(String label, TextEditingController ctrl, String suffix, IconData icon, {bool isInteger = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isInteger ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}