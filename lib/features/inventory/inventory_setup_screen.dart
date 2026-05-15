import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/product_master.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import '../../features/supplements/widgets/product_picker_sheet.dart';
import 'inventory_provider.dart';

// Inventory category descriptor
class _Cat {
  final String stored;   // value written to inventory_items.category
  final String label;    // shown to user in chip
  final String? filter;  // product_master.category filter; null = all products
  final bool isManual;   // true = name typed by user, no product picker

  const _Cat(this.stored, this.label,
      {this.filter, this.isManual = false});

  bool get isAutoTracked => stored == 'feed';
}

const _kCats = [
  _Cat('feed',      'Feed',       isManual: true),
  _Cat('probiotic', 'Probiotic',  filter: 'Probiotic'),
  _Cat('mineral',   'Mineral',    filter: 'Mineral'),
  _Cat('medicine',  'Supplement'),               // null filter → all products
  _Cat('other',     'Other',      isManual: true),
];

class InventorySetupScreen extends ConsumerStatefulWidget {
  const InventorySetupScreen({super.key});

  @override
  ConsumerState<InventorySetupScreen> createState() =>
      _InventorySetupScreenState();
}

class _InventorySetupScreenState
    extends ConsumerState<InventorySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inventoryService = InventoryService();
  final List<_ItemForm> _items = [];
  bool _isLoading = false;

  static const _green = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _items.add(_ItemForm.feed());
  }

  void _addItem() => setState(() => _items.add(_ItemForm.empty()));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  bool get _hasFeedItem => _items.any((i) => i.cat.stored == 'feed');

  Future<void> _save() async {
    // Validate product selection for non-manual items
    final missingProduct =
        _items.where((i) => !i.cat.isManual && i.selectedProduct == null);
    if (missingProduct.isNotEmpty) {
      _toast('Select a product for all items', Colors.red);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final feedCount = _items.where((i) => i.cat.stored == 'feed').length;
    if (feedCount == 0) {
      _toast('A feed item is required', Colors.red);
      return;
    }
    if (feedCount > 1) {
      _toast('Only one feed item per farm', Colors.red);
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
      _toast('Inventory saved', Colors.green);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to save: $e', Colors.red);
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
      backgroundColor: const Color(0xFFF2F4F0),
      appBar: AppBar(
        title: const Text('Add Inventory'),
        backgroundColor: _green,
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
                    'Select products you have on hand. Feed stock deducts automatically as you log feeding.',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map(
                        (e) => _buildItemCard(e.key, e.value),
                      ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another item'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save inventory',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _ItemForm item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_items.length > 1)
                  GestureDetector(
                    onTap: () => _removeItem(index),
                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Category',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            _buildCategoryChips(item),
            const SizedBox(height: 14),
            _buildProductSelector(item),
            const SizedBox(height: 12),
            _buildPackFields(item),
            if (item.cat.isAutoTracked) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.autorenew, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Auto-deducts when you log feeding',
                      style:
                          TextStyle(color: Colors.green.shade800, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(_ItemForm item) {
    final hasFeed = _hasFeedItem;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kCats.map((cat) {
          final isSelected = item.cat.stored == cat.stored;
          final disabled =
              cat.stored == 'feed' && hasFeed && !isSelected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: disabled
                  ? () => _toast(
                      'Only one feed item per farm', Colors.orange)
                  : () => setState(() => item.setCategory(cat)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? _green : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? _green : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    color: disabled
                        ? Colors.grey.shade400
                        : isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductSelector(_ItemForm item) {
    if (item.cat.isManual) {
      return TextFormField(
        controller: item.name,
        decoration: InputDecoration(
          labelText: 'Product name',
          hintText: item.cat.stored == 'feed'
              ? 'e.g., Avanti Starter Feed'
              : 'e.g., Water clarifier',
          border: const OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
      );
    }

    if (item.selectedProduct == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _pickProduct(item),
          icon: const Icon(Icons.search),
          label: const Text('Select product'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: const BorderSide(color: _green),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.selectedProduct!.displayName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => _pickProduct(item),
            style: TextButton.styleFrom(
              foregroundColor: _green,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProduct(_ItemForm item) async {
    final picked = await showProductPickerSheet(
      context,
      categoryFilter: item.cat.filter,
    );
    if (picked != null && mounted) {
      setState(() => item.applyProduct(picked));
    }
  }

  Widget _buildPackFields(_ItemForm item) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.packSize,
                decoration: InputDecoration(
                  labelText: 'Pack size',
                  hintText: '25',
                  suffixText:
                      item.unit.text.isEmpty ? null : item.unit.text,
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
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: item.unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'kg / L / g',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: item.packLabel,
                decoration: const InputDecoration(
                  labelText: 'Pack type',
                  hintText: 'bag',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: item.packs,
                decoration: InputDecoration(
                  labelText: 'Qty on hand',
                  hintText: '8',
                  suffixText: item.packLabel.text.isEmpty
                      ? 'packs'
                      : '${item.packLabel.text}s',
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
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: item.costPerPack,
                decoration: InputDecoration(
                  labelText:
                      'Cost / ${item.packLabel.text.isEmpty ? 'pack' : item.packLabel.text}',
                  prefixText: '₹',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemForm {
  final TextEditingController name;
  final TextEditingController unit;
  final TextEditingController packLabel;
  final TextEditingController packSize;
  final TextEditingController packs;
  final TextEditingController costPerPack;
  _Cat cat;
  ProductMaster? selectedProduct;

  _ItemForm({
    required this.name,
    required this.unit,
    required this.packLabel,
    required this.packSize,
    required this.packs,
    required this.costPerPack,
    required this.cat,
  });

  factory _ItemForm.feed() => _ItemForm(
        name: TextEditingController(),
        unit: TextEditingController(text: 'kg'),
        packLabel: TextEditingController(text: 'bag'),
        packSize: TextEditingController(text: '25'),
        packs: TextEditingController(),
        costPerPack: TextEditingController(),
        cat: _kCats[0],
      );

  factory _ItemForm.empty() => _ItemForm(
        name: TextEditingController(),
        unit: TextEditingController(),
        packLabel: TextEditingController(text: 'bottle'),
        packSize: TextEditingController(text: '1'),
        packs: TextEditingController(),
        costPerPack: TextEditingController(),
        cat: _kCats[3], // Supplement
      );

  void setCategory(_Cat newCat) {
    cat = newCat;
    selectedProduct = null;
    name.text = '';
    if (newCat.stored == 'feed') {
      unit.text = 'kg';
      packLabel.text = 'bag';
      packSize.text = '25';
    } else if (newCat.stored == 'other') {
      if (unit.text.isEmpty) unit.text = 'L';
      if (packLabel.text.isEmpty) packLabel.text = 'bottle';
    }
  }

  void applyProduct(ProductMaster product) {
    selectedProduct = product;
    name.text = product.displayName;
    if (product.unitType != null && product.unitType!.isNotEmpty) {
      unit.text = product.unitType!;
    }
    packLabel.text = _formToPackLabel(product.form);
    if (product.packageSize != null && product.packageSize! > 0) {
      final ps = product.packageSize!;
      packSize.text =
          ps == ps.roundToDouble() ? ps.toInt().toString() : ps.toString();
    }
  }

  static String _formToPackLabel(String? form) => switch (form?.toLowerCase()) {
        'liquid' => 'bottle',
        'powder' => 'bag',
        'granule' => 'bag',
        'tablet' => 'strip',
        _ => 'pack',
      };

  Map<String, dynamic> toMap(String userId, String farmId) {
    final pSize = double.tryParse(packSize.text) ?? 0;
    final pCount = double.tryParse(packs.text) ?? 0;
    final opening = pSize * pCount;
    final cost = double.tryParse(costPerPack.text);
    return {
      'user_id': userId,
      'farm_id': farmId,
      'name': name.text.trim(),
      'category': cat.stored,
      'unit': unit.text.trim(),
      'opening_quantity': opening,
      'price_per_unit':
          (cost != null && pSize > 0) ? cost / pSize : null,
      'is_auto_tracked': cat.isAutoTracked,
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
