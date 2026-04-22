import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/shrimp_pricing.dart';
import '../../core/services/app_config_service.dart';
import '../../core/utils/logger.dart';
import 'admin_view_model.dart';

class ShrimpPricingWidget extends ConsumerStatefulWidget {
  const ShrimpPricingWidget({super.key});

  @override
  ConsumerState<ShrimpPricingWidget> createState() =>
      _ShrimpPricingWidgetState();
}

class _ShrimpPricingWidgetState extends ConsumerState<ShrimpPricingWidget> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ShrimpPricingConfig? _currentConfig;
  bool _isLoading = false;
  bool _enabled = true;
  String _currency = 'INR';

  final Map<int, TextEditingController> _priceControllers = {};
  final List<int> _validCounts = [100, 90, 80, 70, 60, 50, 45, 40, 35, 30, 25];

  @override
  void initState() {
    super.initState();
    _loadCurrentPricing();
    _initializeControllers();
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final count in _validCounts) {
      _priceControllers[count] = TextEditingController();
    }
  }

  Future<void> _loadCurrentPricing() async {
    setState(() => _isLoading = true);

    try {
      final config = await AppConfigService.getShrimpPricingConfig();
      setState(() {
        _currentConfig = config;
        _enabled = config.enabled;
        _currency = config.currency;

        // Update controllers with current prices
        for (final tier in config.pricingTiers) {
          _priceControllers[tier.count]?.text = tier.price.toStringAsFixed(0);
        }
      });
    } catch (e) {
      AppLogger.error('Failed to load shrimp pricing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load pricing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePricing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Build pricing tiers from controllers
      final newPricingTiers = <ShrimpPricing>[];

      for (final count in _validCounts) {
        final controller = _priceControllers[count];
        final priceText = controller?.text.trim();

        if (priceText != null && priceText.isNotEmpty) {
          final priceValue = double.tryParse(priceText);
          if (priceValue != null && priceValue > 0) {
            newPricingTiers.add(ShrimpPricing(
              count: count,
              price: priceValue,
              lastUpdated: DateTime.now(),
            ));
          }
        }
      }

      // Validate pricing tiers
      final validationError =
          ShrimpPricingValidator.validatePricingTiers(newPricingTiers);
      if (validationError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validationError),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Create new config
      final newConfig = ShrimpPricingConfig(
        pricingTiers: newPricingTiers,
        enabled: _enabled,
        currency: _currency,
        lastUpdated: DateTime.now(),
      );

      // Save via Edge Function
      final adminViewModel = ref.read(adminViewModelProvider);
      final success = await adminViewModel.updateShrimpPricing(newConfig);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shrimp pricing updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() => _currentConfig = newConfig);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update shrimp pricing'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to save shrimp pricing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pricing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetToDefaults() {
    final defaultConfig = ShrimpPricingConfig.defaultConfig();
    setState(() {
      _enabled = defaultConfig.enabled;
      _currency = defaultConfig.currency;

      // Update controllers with default prices
      for (final tier in defaultConfig.pricingTiers) {
        _priceControllers[tier.count]?.text = tier.price.toStringAsFixed(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Shrimp Pricing Configuration',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  Text(_enabled ? 'Enabled' : 'Disabled'),
                ],
              ),
              const SizedBox(height: 16),

              // Currency selector
              Row(
                children: [
                  Text(
                    'Currency:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _currency,
                    items: ['INR', 'USD', 'EUR'].map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _currency = value);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Pricing table header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Count',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Today Price',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Pricing rows
              ..._validCounts.map((count) {
                return _buildPricingRow(count);
              }).toList(),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _savePricing,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Pricing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _resetToDefaults,
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Defaults'),
                  ),
                  const Spacer(),
                  if (_currentConfig != null)
                    Text(
                      'Last updated: ${_formatDateTime(_currentConfig!.lastUpdated)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingRow(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _priceControllers[count],
              enabled: _enabled,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter price',
                prefixText: '$_currency ',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              validator: (value) {
                if (!_enabled) return null;
                return ShrimpPricingValidator.validatePrice(value);
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
