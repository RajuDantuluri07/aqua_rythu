import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/inventory_service.dart';

class AdjustStockScreen extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final String unit;
  final double currentStock;

  const AdjustStockScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.currentStock,
  });

  @override
  ConsumerState<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends ConsumerState<AdjustStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newQuantityController = TextEditingController();
  final _reasonController = TextEditingController();

  String _selectedAdjustmentType = 'correction';
  final _inventoryService = InventoryService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newQuantityController.text = widget.currentStock.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _newQuantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _adjustStock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newQuantity = double.tryParse(_newQuantityController.text) ?? 0.0;
      final reason = _reasonController.text.trim();

      if (reason.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reason is required for stock adjustment'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _inventoryService.adjustStock(
        itemId: widget.itemId,
        newQuantity: newQuantity,
        reason: reason,
        adjustmentType: _selectedAdjustmentType,
      );

      if (!mounted) return;

      final difference = newQuantity - widget.currentStock;
      String actionText;
      if (difference > 0) {
        actionText =
            'increased by ${difference.toStringAsFixed(1)} ${widget.unit}';
      } else if (difference < 0) {
        actionText =
            'decreased by ${difference.abs().toStringAsFixed(1)} ${widget.unit}';
      } else {
        actionText = 'no change';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock $_selectedAdjustmentType: $actionText'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to adjust stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newQuantity =
        double.tryParse(_newQuantityController.text) ?? widget.currentStock;
    final difference = newQuantity - widget.currentStock;

    Color differenceColor = Colors.black;
    String differenceText = '${difference.toStringAsFixed(1)} ${widget.unit}';

    if (difference > 0) {
      differenceColor = Colors.green;
      differenceText = '+${difference.toStringAsFixed(1)} ${widget.unit}';
    } else if (difference < 0) {
      differenceColor = Colors.red;
      differenceText = '${difference.toStringAsFixed(1)} ${widget.unit}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Adjust Stock - ${widget.itemName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current stock info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Stock',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currentStock.toStringAsFixed(1)} ${widget.unit}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // New quantity input
              TextFormField(
                controller: _newQuantityController,
                decoration: InputDecoration(
                  labelText: 'New Stock Quantity',
                  suffixText: widget.unit,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'New quantity is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  if (double.tryParse(value) != null &&
                      double.tryParse(value)! < 0) {
                    return 'Quantity cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Difference display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: differenceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: differenceColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Difference',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      differenceText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: differenceColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Adjustment type
              DropdownButtonFormField<String>(
                value: _selectedAdjustmentType,
                decoration: const InputDecoration(
                  labelText: 'Adjustment Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'correction', child: Text('Correction')),
                  DropdownMenuItem(value: 'loss', child: Text('Loss')),
                  DropdownMenuItem(value: 'gain', child: Text('Gain')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedAdjustmentType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Reason input
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (Required)',
                  hintText: 'e.g., Spillage, counting error, theft found',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Reason must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Warning message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will permanently adjust the stock quantity. This action is logged and cannot be undone.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Adjust button
              ElevatedButton(
                onPressed: _isLoading ? null : _adjustStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Adjust Stock',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
