import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/harvest_service.dart';
import '../profit/profit_provider.dart';

class HarvestRecordScreen extends ConsumerStatefulWidget {
  final String cropId;
  final String farmId;

  const HarvestRecordScreen({
    super.key,
    required this.cropId,
    required this.farmId,
  });

  @override
  ConsumerState<HarvestRecordScreen> createState() =>
      _HarvestRecordScreenState();
}

class _HarvestRecordScreenState extends ConsumerState<HarvestRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalWeightController = TextEditingController();
  final _pricePerKgController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _totalWeightController.dispose();
    _pricePerKgController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  Future<void> _recordHarvest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final totalWeight = double.parse(_totalWeightController.text);
      final pricePerKg = double.parse(_pricePerKgController.text);

      final harvestService = HarvestService();
      await harvestService.createHarvest(
        cropId: widget.cropId,
        totalWeight: totalWeight,
        pricePerKg: pricePerKg,
        date: _selectedDate,
      );

      // Refresh profit data
      await ref.read(profitProvider(widget.cropId).notifier).refresh();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Harvest recorded successfully! Revenue: ${_formatCurrency(totalWeight * pricePerKg)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record harvest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Harvest'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Revenue Preview Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[600], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Final Profit Calculation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Record your harvest to calculate final profit',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Input Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Harvest Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Weight Field
                      TextFormField(
                        controller: _totalWeightController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Total Harvest Weight (kg)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale),
                          helperText: 'Total weight harvested in kilograms',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter harvest weight';
                          }
                          final weight = double.tryParse(value);
                          if (weight == null || weight <= 0) {
                            return 'Please enter a valid weight greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price per kg Field
                      TextFormField(
                        controller: _pricePerKgController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Selling Price (₹ per kg)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                          helperText: 'Final selling price per kilogram',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter selling price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date Field
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Harvest Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Revenue Preview
                      if (_totalWeightController.text.isNotEmpty &&
                          _pricePerKgController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expected Revenue:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                ),
                              ),
                              Text(
                                _formatCurrency((double.tryParse(
                                            _totalWeightController.text) ??
                                        0.0) *
                                    (double.tryParse(
                                            _pricePerKgController.text) ??
                                        0.0)),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Record Harvest Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _recordHarvest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Record Harvest',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
