import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../harvest/harvest_provider.dart';
import '../feed/feed_history_provider.dart';
import '../../core/theme/app_theme.dart';

class NewCycleSetupScreen extends ConsumerStatefulWidget {
  final String pondId;
  const NewCycleSetupScreen({super.key, required this.pondId});

  @override
  ConsumerState<NewCycleSetupScreen> createState() =>
      _NewCycleSetupScreenState();
}

class _NewCycleSetupScreenState extends ConsumerState<NewCycleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _seedCtrl = TextEditingController(text: "100000");
  final _plSizeCtrl = TextEditingController(text: "10");
  int _selectedTrays = 4; // Default to 4
  DateTime _stockingDate = DateTime.now();

  @override
  void dispose() {
    _seedCtrl.dispose();
    _plSizeCtrl.dispose();
    super.dispose();
  }

  void _startCycle() {
    if (_formKey.currentState!.validate()) {
      final seedCount = int.parse(_seedCtrl.text);
      final plSize = int.parse(_plSizeCtrl.text);

      // 1. Reset Pond Status & Data
      ref.read(farmProvider.notifier).resetPond(
            widget.pondId,
            seedCount: seedCount,
            plSize: plSize,
            stockingDate: _stockingDate,
            numTrays: _selectedTrays,
          );

      // 2. Generate New Blind Plan (Overwrites old plan)
      ref.read(feedPlanProvider.notifier).createPlan(
            pondId: widget.pondId,
            seedCount: seedCount,
            plSize: plSize,
          );

      // 3. Clear Old Data
      ref.read(harvestProvider(widget.pondId).notifier).clearHarvests();
      ref.read(feedHistoryProvider.notifier).clearHistory(widget.pondId);

      // Navigate back to Dashboard
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("New crop cycle started successfully!"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      appBar: AppBar(
        title: const Text("Start New Cycle"),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "This will reset the pond to DOC 1 and generate a new 30-day blind feed plan.",
                        style: TextStyle(
                            color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stocking Date
              Text("Stocking Date",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _stockingDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _stockingDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_stockingDate),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _buildInput("Seed Count", _seedCtrl, Icons.scatter_plot_rounded,
                  isNumber: true),
              const SizedBox(height: 20),
              _buildInput("PL Size", _plSizeCtrl, Icons.straighten_rounded,
                  isNumber: true),

              const SizedBox(height: 20),

              // TRAY SELECTION DROPDOWN
              Text("Number of Trays",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedTrays,
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.grid_view_rounded, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                items: [2, 4, 6]
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text("$e Trays"),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTrays = val);
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startCycle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("LAUNCH CYCLE",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
          validator: (val) => val == null || val.isEmpty ? "Required" : null,
        ),
      ],
    );
  }
}
