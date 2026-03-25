import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'growth_provider.dart';
import '../farm/farm_provider.dart';
import '../../core/theme/app_theme.dart';

class SamplingScreen extends ConsumerStatefulWidget {
  final String pondId;
  const SamplingScreen({super.key, required this.pondId});

  @override
  ConsumerState<SamplingScreen> createState() => _SamplingScreenState();
}

class _SamplingScreenState extends ConsumerState<SamplingScreen> {
  final _countCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  double get _abw {
    final count = int.tryParse(_countCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    if (count == 0) return 0;
    return weight / count;
  }

  double get _countPerKg {
    if (_abw == 0) return 0;
    return 1000 / _abw;
  }

  double _calculateBiomass(int seedCount, double survival) {
    if (_abw == 0) return 0;
    // Biomass = (Seed * Survival * ABW) / 1000
    return (seedCount * survival * _abw) / 1000;
  }

  @override
  void initState() {
    super.initState();
    _countCtrl.addListener(() => setState(() {}));
    _weightCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _saveSampling(int doc) {
    final count = int.tryParse(_countCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;

    if (count > 0 && weight > 0) {
      ref.read(growthProvider(widget.pondId).notifier).addLog(
        doc: doc,
        sampleCount: count,
        totalWeight: weight,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(growthProvider(widget.pondId));
    final doc = ref.watch(docProvider(widget.pondId));
    final farmState = ref.watch(farmProvider);
    
    // Find pond for seed count
    Pond? pond;
    for (var f in farmState.farms) {
      for (var p in f.ponds) {
        if (p.id == widget.pondId) {
          pond = p;
          break;
        }
      }
    }
    final seedCount = pond?.seedCount ?? 100000;
    
    // Simple survival model for V1
    double survival = 1.0;
    if (doc > 30) survival = 0.95;
    if (doc > 60) survival = 0.90;

    // Provider prepends new logs, so first is latest
    final currentAbw = logs.isNotEmpty ? logs.first.averageBodyWeight : 0.0;
    final targetAbw = 5.0; // Mock target for now or look up from table

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Growth Monitoring", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          children: [
            // ABW Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.rBase,
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("CURRENT ABW", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                        child: Text("TARGET ${targetAbw}g", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${currentAbw.toStringAsFixed(2)} g",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  // Mini Chips (Last 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: logs.take(3).map((log) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Chip(
                        label: Text("${log.averageBodyWeight.toStringAsFixed(1)}g"),
                        backgroundColor: Colors.white24,
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Inputs
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    controller: _countCtrl,
                    label: "Sample Count",
                    icon: Icons.people_outline_rounded,
                    hint: "e.g. 50",
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInput(
                    controller: _weightCtrl,
                    label: "Total Weight (g)",
                    icon: Icons.hourglass_empty_rounded,
                    hint: "e.g. 250",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Live Compute
            if (_abw > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: AppRadius.rs,
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _liveStat("AVG WEIGHT", "${_abw.toStringAsFixed(2)} g"),
                    _liveStat("COUNT/KG", "${_countPerKg.toInt()}"),
                    _liveStat("BIOMASS", "${_calculateBiomass(seedCount, survival).toInt()} kg"),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _saveSampling(doc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rs),
                ),
                child: const Text("SAVE & UPDATE GROWTH", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),

            // Ledger
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Logs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.rs,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _headerRow(),
                  ...logs.take(5).map((log) => _logRow(log)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, required IconData icon, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: AppRadius.rs, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rs, borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _liveStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green.shade800)),
      ],
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
        color: Color(0xFFF8FAFC),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text("DATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 1, child: Text("DOC", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Text("AVG.WT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Text("COUNT", textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary))),
        ],
      ),
    );
  }

  Widget _logRow(SamplingLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(DateFormat("dd MMM").format(log.date), style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 1, child: Text("${log.doc}", style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text("${log.averageBodyWeight.toStringAsFixed(2)}g", style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("${log.sampleCount}", textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}