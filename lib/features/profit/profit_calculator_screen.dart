import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profit_provider.dart';

class ProfitCalculatorScreen extends ConsumerStatefulWidget {
  final String cropId;
  final String farmId;

  const ProfitCalculatorScreen({
    super.key,
    required this.cropId,
    required this.farmId,
  });

  @override
  ConsumerState<ProfitCalculatorScreen> createState() =>
      _ProfitCalculatorScreenState();
}

class _ProfitCalculatorScreenState
    extends ConsumerState<ProfitCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _harvestWeightController = TextEditingController();
  final _sellingPriceController = TextEditingController();

  bool _isLoading = false;
  Map<String, double>? _calculationResult;

  @override
  void dispose() {
    _harvestWeightController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  Future<void> _calculateProfit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _calculationResult = null;
    });

    try {
      final harvestWeight = double.parse(_harvestWeightController.text);
      final sellingPrice = double.parse(_sellingPriceController.text);

      final result = await ref
          .read(profitProvider(widget.cropId).notifier)
          .calculateProfit(
            harvestWeight: harvestWeight,
            sellingPrice: sellingPrice,
          );

      setState(() {
        _calculationResult = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to calculate profit: $e'),
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
    final profitAsync = ref.watch(profitProvider(widget.cropId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Calculator'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        'Harvest Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Harvest Weight Field
                      TextFormField(
                        controller: _harvestWeightController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Harvest Weight (kg)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale),
                          helperText: 'Total harvest weight in kilograms',
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

                      // Selling Price Field
                      TextFormField(
                        controller: _sellingPriceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Selling Price (₹ per kg)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                          helperText: 'Price per kilogram',
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
                      const SizedBox(height: 24),

                      // Calculate Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _calculateProfit,
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
                                'Calculate Profit',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current Costs Summary
            profitAsync.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[400]),
                      const SizedBox(height: 8),
                      Text('Error loading cost data',
                          style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                ),
              ),
              data: (summary) {
                final todayCosts = summary['today'] as Map<String, dynamic>;
                final totalCosts = summary['total'] as Map<String, dynamic>;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Costs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Today's Costs
                        _buildCostRow('Today - Feed Cost',
                            todayCosts['feed_cost'] as double),
                        _buildCostRow('Today - Other Cost',
                            todayCosts['other_cost'] as double),
                        _buildCostRow('Today - Total Cost',
                            todayCosts['total_cost'] as double,
                            isBold: true),
                        const Divider(),

                        // Total Costs
                        _buildCostRow('Total - Feed Cost',
                            totalCosts['feed_cost'] as double),
                        _buildCostRow('Total - Other Cost',
                            totalCosts['other_cost'] as double),
                        _buildCostRow('Total - Total Cost',
                            totalCosts['total_cost'] as double,
                            isBold: true),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Profit Calculation Results
            if (_calculationResult != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profit Calculation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCostRow('Revenue', _calculationResult!['revenue']!),
                      _buildCostRow(
                          'Feed Cost', _calculationResult!['feed_cost']!),
                      _buildCostRow(
                          'Other Cost', _calculationResult!['other_cost']!),
                      _buildCostRow(
                          'Total Cost', _calculationResult!['total_cost']!),
                      const Divider(),
                      _buildCostRow(
                        'PROFIT',
                        _calculationResult!['profit']!,
                        isBold: true,
                        isProfit: true,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double amount,
      {bool isBold = false, bool isProfit = false}) {
    final isNegative = amount < 0;
    final textColor = isProfit
        ? (isNegative ? Colors.red[700] : Colors.green[700])
        : (isBold ? Colors.black : Colors.grey[700]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
