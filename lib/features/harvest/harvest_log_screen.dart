import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/features/farm/farm_provider.dart';
import 'package:aqua_rythu/core/services/pond_harvest_service.dart';

class HarvestLogScreen extends ConsumerStatefulWidget {
  final Pond pond;

  const HarvestLogScreen({super.key, required this.pond});

  @override
  ConsumerState<HarvestLogScreen> createState() => _HarvestLogScreenState();
}

class _HarvestLogScreenState extends ConsumerState<HarvestLogScreen> {
  static const _green = Color(0xFF1B8A4C);
  static const _amber = Color(0xFFE8A33D);

  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _countCtrl = TextEditingController();

  String _harvestType = 'partial';
  bool _loading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  int get _currentStock => widget.pond.stockCount ?? widget.pond.seedCount;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final qty = double.tryParse(_qtyCtrl.text.trim());

      if (qty == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid quantity. Please enter a valid number.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final count = _countCtrl.text.trim().isNotEmpty
          ? int.tryParse(_countCtrl.text.trim())
          : null;

      final result = await PondHarvestService().logHarvest(
        pondId: widget.pond.id,
        harvestType: _harvestType,
        quantityKg: qty,
        estimatedCount: count,
        abwAtHarvest: widget.pond.currentAbw,
        currentStockCount: _currentStock,
        initialStockCount: widget.pond.seedCount,
      );

      // Update local farm state
      ref.read(farmProvider.notifier).updatePondHarvest(
            pondId: widget.pond.id,
            newStockCount: result.newStockCount,
            activeStockPct: result.activeStockPct,
            harvestStage: _harvestType == 'full' ? 'completed' : 'partial',
            lastHarvestQty: qty,
          );

      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSheet(
          context,
          harvestType: _harvestType,
          quantityKg: qty,
          newStockCount: result.newStockCount,
          activeStockPct: result.activeStockPct,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessSheet(
    BuildContext context, {
    required String harvestType,
    required double quantityKg,
    required int newStockCount,
    required double activeStockPct,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _SuccessSheet(
        harvestType: harvestType,
        quantityKg: quantityKg,
        newStockCount: newStockCount,
        activeStockPct: activeStockPct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final abw = widget.pond.currentAbw;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text('Log Harvest'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pond info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8ECF0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child:
                        const Icon(Icons.water_drop, color: _green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.pond.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          'DOC ${widget.pond.doc} · Stock: ${_currentStock.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                  if (abw != null)
                    Column(
                      children: [
                        Text(
                          '${abw.toStringAsFixed(1)}g',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _green),
                        ),
                        const Text('ABW',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF888888))),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Harvest type selector
            _label('Harvest Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeOption('partial', 'Partial Harvest', Icons.moving_outlined,
                    _amber),
                const SizedBox(width: 10),
                _typeOption('full', 'Final Harvest', Icons.agriculture_outlined,
                    _green),
              ],
            ),

            const SizedBox(height: 20),

            // Quantity field
            _label('Harvest Quantity (kg)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco('e.g. 500', Icons.scale_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter quantity';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid quantity';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Count field (optional)
            _label('Estimated Count (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(
                  'Auto-calculated if left empty', Icons.numbers_outlined),
            ),

            // ABW auto-fill note
            if (abw != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: _green),
                    const SizedBox(width: 6),
                    Text(
                      'ABW ${abw.toStringAsFixed(1)}g auto-filled from last sampling',
                      style: const TextStyle(fontSize: 12, color: _green),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _harvestType == 'full' ? _green : _amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _harvestType == 'full'
                            ? 'Save Final Harvest'
                            : 'Save Partial Harvest',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption(String value, String label, IconData icon, Color color) {
    final selected = _harvestType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _harvestType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: selected ? color : const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF444444),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444)),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        prefixIcon: Icon(icon, color: const Color(0xFF888888), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _green, width: 2)),
      );
}

// ── Post-harvest success sheet ────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final String harvestType;
  final double quantityKg;
  final int newStockCount;
  final double activeStockPct;

  const _SuccessSheet({
    required this.harvestType,
    required this.quantityKg,
    required this.newStockCount,
    required this.activeStockPct,
  });

  static const _green = Color(0xFF1B8A4C);

  @override
  Widget build(BuildContext context) {
    final isFull = harvestType == 'full';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE), shape: BoxShape.circle),
            child:
                const Icon(Icons.check_circle_rounded, color: _green, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            isFull ? 'Harvest Recorded!' : 'Partial Harvest Saved!',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 4),
          Text(
            '${quantityKg.toStringAsFixed(1)} kg logged',
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 20),
          // Status chips
          _statusRow(Icons.inventory_2_outlined, 'Stock updated',
              'Active stock: ${(activeStockPct * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 10),
          _statusRow(Icons.set_meal_rounded, 'Feed adjusted',
              'Feed reduced to ${(activeStockPct * 100).toStringAsFixed(0)}% of baseline'),
          if (!isFull) ...[
            const SizedBox(height: 10),
            _statusRow(Icons.science_outlined, 'Sampling required',
                'Post-harvest sampling needed for recalibration',
                urgent: true),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String title, String sub,
      {bool urgent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFFF3E0) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: urgent ? const Color(0xFFFFCC80) : const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: urgent ? const Color(0xFFE65100) : _green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: urgent
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1A1A1A))),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
