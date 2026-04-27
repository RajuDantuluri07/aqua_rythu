import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import '../../features/pond/pond_dashboard_provider.dart';

class InventorySetupScreen extends ConsumerStatefulWidget {
  const InventorySetupScreen({super.key});

  @override
  ConsumerState<InventorySetupScreen> createState() =>
      _InventorySetupScreenState();
}

class _InventorySetupScreenState extends ConsumerState<InventorySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = InventoryService();
  final List<InventoryItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addInitialItems();
  }

  void _addInitialItems() {
    // Add one feed item by default
    _items.add(InventoryItem(
      nameController: TextEditingController(),
      category: 'feed',
      quantityController: TextEditingController(),
      unitController: TextEditingController(text: 'kg'),
      priceController: TextEditingController(),
      isAutoTracked: true,
    ));
  }

  void _addItem() {
    if (!mounted) return;
    setState(() {
      _items.add(InventoryItem(
        nameController: TextEditingController(),
        category: 'other',
        quantityController: TextEditingController(),
        unitController: TextEditingController(),
        priceController: TextEditingController(),
        isAutoTracked: false,
      ));
    });
  }

  bool _hasFeedItem() {
    return _items.any((item) => item.category == 'feed');
  }

  List<DropdownMenuItem<String>> _getCategoryOptions(int currentIndex) {
    final hasFeed = _hasFeedItem();
    final currentItem = _items[currentIndex];

    final options = <DropdownMenuItem<String>>[];

    // Add feed option only if no feed exists or this is the current feed item
    if (!hasFeed || currentItem.category == 'feed') {
      options.add(const DropdownMenuItem(value: 'feed', child: Text('Feed')));
    }

    // Always add other options
    options.addAll(const [
      DropdownMenuItem(value: 'medicine', child: Text('Medicine')),
      DropdownMenuItem(value: 'equipment', child: Text('Equipment')),
      DropdownMenuItem(value: 'other', child: Text('Other')),
    ]);

    return options;
  }

  void _removeItem(int index) {
    if (!mounted) return;
    setState(() {
      if (_items.length > 1) {
        _items[index].nameController.dispose();
        _items[index].quantityController.dispose();
        _items[index].unitController.dispose();
        _items[index].priceController.dispose();
        _items.removeAt(index);
      }
    });
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) return;

    // CRITICAL VALIDATION: Must have exactly one feed item
    final feedItems = _items.where((item) => item.category == 'feed').toList();
    if (feedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A feed item is required for inventory tracking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (feedItems.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only one feed item is allowed per crop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final farmState = ref.read(farmProvider);
      final pondState = ref.read(pondDashboardProvider);

      final selectedFarm = farmState.currentFarm;
      final selectedPondId = pondState.selectedPond;

      if (user == null || selectedFarm == null || selectedPondId.isEmpty) {
        throw Exception('User, farm, or pond not selected');
      }

      final inventoryItems = _items
          .map((item) => {
                'user_id': user.id,
                'farm_id': selectedFarm.id,
                'crop_id': selectedPondId,
                'name': item.nameController.text.trim(),
                'category': item.category,
                'unit': item.unitController.text.trim(),
                'opening_quantity':
                    double.tryParse(item.quantityController.text) ?? 0,
                'price_per_unit': item.priceController.text.isNotEmpty
                    ? double.tryParse(item.priceController.text)
                    : null,
                'is_auto_tracked': item.isAutoTracked,
              })
          .toList();

      await _inventoryService.createInventoryItems(inventoryItems);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory setup completed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to inventory dashboard
      Navigator.of(context).pushReplacementNamed('/inventory_dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save inventory'),
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
  void dispose() {
    for (final item in _items) {
      item.nameController.dispose();
      item.quantityController.dispose();
      item.unitController.dispose();
      item.priceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Setup'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Setup your inventory items. Only one feed item is required for automatic tracking.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildItemCard(index, item);
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, InventoryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: item.nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Item name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: item.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _getCategoryOptions(index),
              onChanged: (value) {
                if (value == 'feed' &&
                    _hasFeedItem() &&
                    item.category != 'feed') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only one feed item is allowed'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (!mounted) return;
                setState(() {
                  item.category = value!;
                  item.isAutoTracked = value == 'feed';
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Quantity is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Unit is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: item.priceController,
              decoration: const InputDecoration(
                labelText: 'Price per Unit (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            if (item.isAutoTracked)
              const Text(
                'This item will be automatically tracked when you record feeding',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveInventory,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Save Inventory', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class InventoryItem {
  TextEditingController nameController;
  TextEditingController quantityController;
  TextEditingController unitController;
  TextEditingController priceController;
  String category;
  bool isAutoTracked;

  InventoryItem({
    required this.nameController,
    required this.category,
    required this.quantityController,
    required this.unitController,
    required this.priceController,
    required this.isAutoTracked,
  });
}
