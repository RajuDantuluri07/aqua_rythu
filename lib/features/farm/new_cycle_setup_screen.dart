import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../tray/tray_provider.dart';
import '../harvest/harvest_provider.dart';
import '../pond/pond_dashboard_provider.dart';

class NewCycleSetupScreen extends ConsumerStatefulWidget {
  final String pondId;
  const NewCycleSetupScreen({super.key, required this.pondId});

  @override
  ConsumerState<NewCycleSetupScreen> createState() => _NewCycleSetupScreenState();
}

class _NewCycleSetupScreenState extends ConsumerState<NewCycleSetupScreen> {
  final _countCtrl = TextEditingController(text: "100000");
  final _plSizeCtrl = TextEditingController(text: "10");
  DateTime _stockingDate = DateTime.now();

  @override
  void dispose() {
    _countCtrl.dispose();
    _plSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockingDate) {
      setState(() {
        _stockingDate = picked;
      });
    }
  }

  void _startCycle() {
    final count = int.tryParse(_countCtrl.text) ?? 100000;
    final plSize = int.tryParse(_plSizeCtrl.text) ?? 10;

    // 1. Reset Pond in Farm Provider
    ref.read(farmProvider.notifier).resetPond(
      widget.pondId,
      seedCount: count,
      plSize: plSize,
      stockingDate: _stockingDate,
    );

    // 2. Clear Harvest Logs
    ref.read(harvestProvider(widget.pondId).notifier).clearHarvests();

    // 3. Clear Tray Logs
    ref.read(trayProvider(widget.pondId).notifier).clearLogs(); 

    // 4. Force Feed Plan Recalculation
    ref.read(feedPlanProvider.notifier).createPlan(
      pondId: widget.pondId,
      seedCount: count,
      plSize: plSize,
    );

    // 5. Reset Dashboard State
    ref.read(pondDashboardProvider.notifier).selectPond(widget.pondId);

    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("New pond cycle started successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start New Cycle")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Initialize Pond",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Provide the initial data for the new cycle.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            _buildInput("Stocking Count", _countCtrl, Icons.group_work_rounded),
            const SizedBox(height: 20),
            _buildInput("PL Size (mm)", _plSizeCtrl, Icons.straighten_rounded),
            const SizedBox(height: 20),
            
            const Text("Stocking Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      "${_stockingDate.day}/${_stockingDate.month}/${_stockingDate.year}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startCycle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("START NEW CYCLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
