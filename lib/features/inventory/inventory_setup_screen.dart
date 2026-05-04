import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import 'inventory_provider.dart';

class InventorySetupScreen extends ConsumerStatefulWidget {
  const InventorySetupScreen({super.key});

  @override
  ConsumerState<InventorySetupScreen> createState() =>
      _InventorySetupScreenState();
}

class _InventorySetupScreenState extends ConsumerState<InventorySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = InventoryService();
  final List<_ItemForm> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items.add(_ItemForm.feed());
  }

  void _addItem() {
    setState(() => _items.add(_ItemForm.other()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  bool get _hasFeedItem => _items.any((i) => i.category == 'feed');

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final feedCount = _items.where((i) => i.category == 'feed').length;
    if (feedCount == 0) {
      _toast('A feed item is required', Colors.red);
      return;
    }
    if (feedCount > 1) {
      _toast('Only one feed item per pond', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final farm = ref.read(farmProvider).currentFarm;

      if (user == null || farm == null) {
        throw Exception('User or farm not found');
      }

      final rows = _items.map((i) => i.toMap(user.id, farm.id)).toList();
      await _inventoryService.createInventoryItems(rows);

      if (!mounted) return;
      ref.invalidate(inventoryProvider(farm.id));
      _toast('Inventory ready', Colors.green);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to save inventory: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
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
                  Text(
                    'Add the feed and supplies you have on hand. Feed deducts automatically as you log feeding.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map((e) =>
                      _buildItemCard(e.key, e.value, _hasFeedItem)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another item'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save inventory'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _ItemForm item, bool hasFeed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Item ${index + 1}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.name,
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'e.g., Avanti Starter Feed',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: item.category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categoryOptions(item, hasFeed),
              onChanged: (v) {
                if (v == null) return;
                if (v == 'feed' && hasFeed && item.category != 'feed') {
                  _toast('Only one feed item per pond', Colors.orange);
                  return;
                }
                setState(() => item.setCategory(v));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.packSize,
                    decoration: InputDecoration(
                      labelText: 'Pack size',
                      hintText: '25',
                      suffixText: item.unit.text.isEmpty ? null : item.unit.text,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'kg / liter',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.packLabel,
                    decoration: const InputDecoration(
                      labelText: 'Pack name',
                      hintText: 'bag',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.packs,
                    decoration: InputDecoration(
                      labelText: 'Number of ${item.packLabel.text.isEmpty ? 'packs' : '${item.packLabel.text}s'}',
                      hintText: '8',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item.costPerPack,
                    decoration: InputDecoration(
                      labelText: 'Cost per ${item.packLabel.text.isEmpty ? 'pack' : item.packLabel.text}',
                      prefixText: '₹',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            if (item.category == 'feed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.autorenew, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Auto-deducts when you log feeding',
                      style: TextStyle(
                          color: Colors.green.shade800, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _categoryOptions(_ItemForm item, bool hasFeed) {
    final options = <DropdownMenuItem<String>>[];
    if (!hasFeed || item.category == 'feed') {
      options.add(const DropdownMenuItem(value: 'feed', child: Text('Feed')));
    }
    options.addAll(const [
      DropdownMenuItem(value: 'medicine', child: Text('Medicine')),
      DropdownMenuItem(value: 'probiotic', child: Text('Probiotic')),
      DropdownMenuItem(value: 'mineral', child: Text('Mineral')),
      DropdownMenuItem(value: 'other', child: Text('Other')),
    ]);
    return options;
  }
}

class _ItemForm {
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController packLabel;
  final TextEditingController packSize;
  final TextEditingController packs;
  final TextEditingController costPerPack;
  String category;
  bool isAutoTracked;

  _ItemForm({
    required this.name,
    required this.unit,
    required this.packLabel,
    required this.packSize,
    required this.packs,
    required this.costPerPack,
    required this.category,
    required this.isAutoTracked,
  });

  factory _ItemForm.feed() => _ItemForm(
        name: TextEditingController(),
        unit: TextEditingController(text: 'kg'),
        packLabel: TextEditingController(text: 'bag'),
        packSize: TextEditingController(text: '25'),
        packs: TextEditingController(),
        costPerPack: TextEditingController(),
        category: 'feed',
        isAutoTracked: true,
      );

  factory _ItemForm.other() => _ItemForm(
        name: TextEditingController(),
        unit: TextEditingController(text: 'liter'),
        packLabel: TextEditingController(text: 'bottle'),
        packSize: TextEditingController(text: '1'),
        packs: TextEditingController(),
        costPerPack: TextEditingController(),
        category: 'medicine',
        isAutoTracked: false,
      );

  void setCategory(String value) {
    category = value;
    isAutoTracked = value == 'feed';
    if (value == 'feed') {
      if (unit.text.isEmpty) unit.text = 'kg';
      if (packLabel.text.isEmpty) packLabel.text = 'bag';
    } else {
      if (unit.text.isEmpty) unit.text = 'liter';
      if (packLabel.text.isEmpty) packLabel.text = 'bottle';
    }
  }

  Map<String, dynamic> toMap(String userId, String farmId) {
    final pSize = double.tryParse(packSize.text) ?? 0;
    final pCount = double.tryParse(packs.text) ?? 0;
    final opening = pSize * pCount;
    final cost = double.tryParse(costPerPack.text);
    return {
      'user_id': userId,
      'farm_id': farmId,
      'name': name.text.trim(),
      'category': category,
      'unit': unit.text.trim(),
      'opening_quantity': opening,
      'price_per_unit':
          (cost != null && pSize > 0) ? cost / pSize : null,
      'is_auto_tracked': isAutoTracked,
      'pack_size': pSize,
      'pack_label': packLabel.text.trim(),
      'cost_per_pack': cost,
    };
  }

  void dispose() {
    name.dispose();
    unit.dispose();
    packLabel.dispose();
    packSize.dispose();
    packs.dispose();
    costPerPack.dispose();
  }
}
