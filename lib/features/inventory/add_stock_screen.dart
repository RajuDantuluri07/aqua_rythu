import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';

class AddStockScreen extends ConsumerStatefulWidget {
  final InventoryItem item;

  const AddStockScreen({super.key, required this.item});

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _packsController = TextEditingController();
  final _costPerPackController = TextEditingController();
  final _quantityController = TextEditingController();
  final _pricePerUnitController = TextEditingController();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  final _inventoryService = InventoryService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.costPerPack != null) {
      _costPerPackController.text = widget.item.costPerPack!.toStringAsFixed(0);
    } else if (widget.item.pricePerUnit != null) {
      _pricePerUnitController.text =
          widget.item.pricePerUnit!.toStringAsFixed(2);
    }
    _packsController.addListener(() => setState(() {}));
    _costPerPackController.addListener(() => setState(() {}));
    _quantityController.addListener(() => setState(() {}));
    _pricePerUnitController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _packsController.dispose();
    _costPerPackController.dispose();
    _quantityController.dispose();
    _pricePerUnitController.dispose();
    _supplierController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isPackMode => widget.item.hasPackTracking;

  double get _totalQuantity {
    if (_isPackMode) {
      final packs = double.tryParse(_packsController.text) ?? 0;
      return packs * (widget.item.packSize ?? 0);
    }
    return double.tryParse(_quantityController.text) ?? 0;
  }

  double get _totalCost {
    if (_isPackMode) {
      final packs = double.tryParse(_packsController.text) ?? 0;
      final cost = double.tryParse(_costPerPackController.text) ?? 0;
      return packs * cost;
    }
    final qty = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_pricePerUnitController.text) ?? 0;
    return qty * price;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isPackMode) {
        final packs = double.tryParse(_packsController.text) ?? 0;
        final costPerPack = double.tryParse(_costPerPackController.text) ?? 0;
        await _inventoryService.addStock(
          itemId: widget.item.id,
          packs: packs,
          costPerPack: costPerPack,
          purchaseDate: _selectedDate,
          supplierName: _emptyToNull(_supplierController.text),
          invoiceNumber: _emptyToNull(_invoiceController.text),
          notes: _emptyToNull(_notesController.text),
        );
      } else {
        final qty = double.tryParse(_quantityController.text) ?? 0;
        final price = double.tryParse(_pricePerUnitController.text) ?? 0;
        await _inventoryService.addStock(
          itemId: widget.item.id,
          quantity: qty,
          pricePerUnit: price,
          purchaseDate: _selectedDate,
          supplierName: _emptyToNull(_supplierController.text),
          invoiceNumber: _emptyToNull(_invoiceController.text),
          notes: _emptyToNull(_notesController.text),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock added to ${widget.item.name}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _emptyToNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Stock — ${widget.item.name}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isPackMode) _buildPackInputs() else _buildRawInputs(),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Purchase Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(
                  labelText: 'Supplier (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _invoiceController,
                decoration: const InputDecoration(
                  labelText: 'Invoice # (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _buildSummary(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add Stock', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackInputs() {
    final packSize = widget.item.packSize!;
    final unit = widget.item.unit;
    final label = widget.item.packLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1 $label = ${_fmt(packSize)} $unit',
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _packsController,
                decoration: InputDecoration(
                  labelText: 'Number of ${label}s',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumberValidator,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _costPerPackController,
                decoration: InputDecoration(
                  labelText: 'Cost per $label',
                  prefixText: '₹',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveNumberValidator,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRawInputs() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: widget.item.unit,
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _positiveNumberValidator,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _pricePerUnitController,
            decoration: const InputDecoration(
              labelText: 'Price per Unit',
              prefixText: '₹',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _positiveNumberValidator,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final qty = _totalQuantity;
    final cost = _totalCost;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _summaryRow('Total quantity', '${_fmt(qty)} ${widget.item.unit}'),
          const SizedBox(height: 6),
          _summaryRow(
            'Total cost',
            '₹${cost.toStringAsFixed(2)}',
            valueColor: Colors.green.shade700,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String? _positiveNumberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a number';
    if (n <= 0) return 'Must be > 0';
    return null;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
