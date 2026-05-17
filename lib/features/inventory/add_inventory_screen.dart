import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/feed_master_product.dart';
import '../../core/models/product_master.dart';
import '../../core/providers/product_provider.dart';
import '../../core/services/inventory_service.dart';
import '../../core/theme/app_theme.dart';
import '../farm/farm_provider.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _green = Color(0xFF1B5E20);
const _bg = Color(0xFFF2F4F0);

// ── Application type label derived from ProductMaster category ────────────────

String _appTypeLabel(String category) => switch (category) {
      'Feed Supplement' => 'Feed Mix',
      'Water Supplement' => 'Water Mix',
      'Probiotic' => 'Water Mix',
      'Mineral' => 'Water Mix',
      'Water Treatment' => 'Water Mix',
      'Disinfectant' => 'Water Mix',
      'Pond Preparation' => 'Water Mix',
      _ => 'Both',
    };

// ── Draft item state ──────────────────────────────────────────────────────────

class _DraftItem {
  final int key;
  FeedMasterProduct? feedProduct;
  ProductMaster? supplementProduct;
  final TextEditingController qtyCtrl = TextEditingController();

  _DraftItem(this.key);

  bool get hasProduct => feedProduct != null || supplementProduct != null;

  String get displayName =>
      feedProduct?.displayName ?? supplementProduct?.displayName ?? '';

  String get productId => feedProduct?.id ?? supplementProduct?.id ?? '';

  String get productType => feedProduct != null ? 'feed' : 'supplement';

  /// Physical unit (kg, L, g, etc.) for one package of this product.
  String get packageUnit {
    if (feedProduct != null) return 'kg';
    final sp = supplementProduct;
    if (sp != null) {
      if (sp.unitType != null && sp.unitType!.isNotEmpty) return sp.unitType!;
      if (sp.baseUnit != null && sp.baseUnit!.isNotEmpty) return sp.baseUnit!;
    }
    return 'unit';
  }

  /// Weight/volume of one package in [packageUnit]. Null if unknown.
  double? get packageSize {
    if (feedProduct != null) return feedProduct!.bagWeightKg;
    return supplementProduct?.packageSize;
  }

  /// Dynamic label shown above the quantity input (e.g. "No. of Bags Purchased").
  String get qtyLabel {
    if (feedProduct != null) return 'No. of Bags Purchased';
    final form = supplementProduct?.form?.toLowerCase();
    return switch (form) {
      'bottle' || 'liquid' => 'No. of Bottles Purchased',
      'packet' || 'powder' || 'granule' => 'No. of Packets Purchased',
      'bag' => 'No. of Bags Purchased',
      'box' => 'No. of Boxes Purchased',
      'tablet' || 'strip' => 'No. of Strips Purchased',
      _ => 'No. of Units Purchased',
    };
  }

  void setFeedProduct(FeedMasterProduct p) {
    feedProduct = p;
    supplementProduct = null;
  }

  void setSupplementProduct(ProductMaster p) {
    supplementProduct = p;
    feedProduct = null;
  }

  void clearProduct() {
    feedProduct = null;
    supplementProduct = null;
  }

  Map<String, dynamic> toEntry(String farmId, String userId, DateTime purchaseDate) {
    final packageCount = int.parse(qtyCtrl.text.trim());
    final pSize = packageSize;
    final actualStock =
        pSize != null ? packageCount * pSize : packageCount.toDouble();
    return {
      'farm_id': farmId,
      'user_id': userId,
      'product_id': productId,
      'product_type': productType,
      'quantity_purchased': packageCount,
      'package_size': pSize,
      'package_unit': packageUnit,
      'actual_stock': actualStock,
      'quantity_unit': packageUnit,
      'purchase_date': DateFormat('yyyy-MM-dd').format(purchaseDate),
    };
  }

  void dispose() {
    qtyCtrl.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AddInventoryScreen extends ConsumerStatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  ConsumerState<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends ConsumerState<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = InventoryService();
  final List<_DraftItem> _items = [];
  int _nextKey = 0;
  bool _saving = false;
  DateTime _sharedPurchaseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_DraftItem(_nextKey++)));

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    final missing = _items.where((i) => !i.hasProduct).toList();
    if (missing.isNotEmpty) {
      _toast('Select a product for every item', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final farm = ref.read(farmProvider).currentFarm;
      if (user == null || farm == null) throw Exception('Session error');

      final entries = _items
          .map((i) => i.toEntry(farm.id, user.id, _sharedPurchaseDate))
          .toList();
      await _service.createInventoryEntries(entries);

      if (!mounted) return;
      _toast('${entries.length} item${entries.length == 1 ? '' : 's'} saved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _items.length;
    return Scaffold(
      backgroundColor: _bg,
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
                    'Select products you purchased and enter the number of packages. '
                    'Stock calculates automatically from package size.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map(
                        (e) => _ItemCard(
                          key: ValueKey(e.value.key),
                          item: e.value,
                          index: e.key,
                          total: itemCount,
                          onRemove: () => _removeItem(e.key),
                          onProductPick: () => _pickProduct(e.value),
                          onChanged: () => setState(() {}),
                        ),
                      ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Item'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DateField(
                    label: 'Purchase Date',
                    date: _sharedPurchaseDate,
                    onChanged: (d) => setState(() => _sharedPurchaseDate = d),
                  ),
                  const SizedBox(height: 8),
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
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Save $itemCount Item${itemCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProduct(_DraftItem item) async {
    final result = await showUnifiedProductPickerSheet(context);
    if (result == null || !mounted) return;
    setState(() {
      if (result is FeedMasterProduct) {
        item.setFeedProduct(result);
      } else if (result is ProductMaster) {
        item.setSupplementProduct(result);
      }
    });
  }
}

// ── Item card widget ──────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final _DraftItem item;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback onProductPick;
  final VoidCallback onChanged;

  const _ItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.onRemove,
    required this.onProductPick,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                if (total > 1)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (!item.hasProduct)
              _pickButton()
            else ...[
              _selectedTile(),
              const SizedBox(height: 14),
              _metadataSection(),
            ],

            const SizedBox(height: 14),

            TextFormField(
              controller: item.qtyCtrl,
              decoration: InputDecoration(
                labelText: item.hasProduct ? item.qtyLabel : 'No. of Units Purchased',
                hintText: '10',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChanged(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Enter at least 1';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onProductPick,
        icon: const Icon(Icons.search),
        label: const Text('Select Product'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _green,
          side: const BorderSide(color: _green),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _selectedTile() {
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
              item.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: onProductPick,
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

  Widget _metadataSection() {
    final feed = item.feedProduct;
    final supp = item.supplementProduct;
    final rows = <_MetaRow>[];

    if (feed != null) {
      rows.addAll([
        _MetaRow('Brand', feed.brand),
        if (feed.productCode != null) _MetaRow('Code', feed.productCode!),
        if (feed.stage != null) _MetaRow('Stage', feed.stage!),
        if (feed.proteinPercent != null)
          _MetaRow('Protein', '${feed.proteinPercent}%'),
        if (feed.pelletSizeMm != null)
          _MetaRow('Pellet Size', feed.pelletSizeMm!),
        if (feed.bagWeightKg != null)
          _MetaRow('Bag Weight', '${feed.bagWeightKg} kg'),
        if (feed.cultureType != null) _MetaRow('Culture', feed.cultureType!),
      ]);
    } else if (supp != null) {
      final effectiveUnit = supp.unitType?.isNotEmpty == true
          ? supp.unitType!
          : (supp.baseUnit?.isNotEmpty == true ? supp.baseUnit! : '');
      rows.addAll([
        _MetaRow('Category', supp.category),
        if (supp.brand != null && supp.brand!.isNotEmpty)
          _MetaRow('Company', supp.brand!),
        if (supp.form != null) _MetaRow('Form', supp.form!),
        if (effectiveUnit.isNotEmpty) _MetaRow('Unit', effectiveUnit),
        if (supp.packageSize != null)
          _MetaRow(
            'Package Size',
            effectiveUnit.isNotEmpty
                ? '${supp.packageSize} $effectiveUnit'
                : '${supp.packageSize}',
          ),
      ]);
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: rows.map((r) => _MetaChip(r)).toList(),
      ),
    );
  }
}

// ── Metadata helpers ──────────────────────────────────────────────────────────

class _MetaRow {
  final String label;
  final String value;
  const _MetaRow(this.label, this.value);
}

class _MetaChip extends StatelessWidget {
  final _MetaRow row;
  const _MetaChip(this.row);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(row.label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(row.value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          DateFormat('d MMM yyyy').format(date),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

// ── Unified product picker ────────────────────────────────────────────────────

/// Returns either a [FeedMasterProduct] or [ProductMaster], or null if dismissed.
Future<Object?> showUnifiedProductPickerSheet(BuildContext context) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _UnifiedProductPickerSheet(),
  );
}

class _UnifiedProductPickerSheet extends ConsumerStatefulWidget {
  const _UnifiedProductPickerSheet();

  @override
  ConsumerState<_UnifiedProductPickerSheet> createState() =>
      _UnifiedProductPickerSheetState();
}

class _UnifiedProductPickerSheetState
    extends ConsumerState<_UnifiedProductPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _query = ''));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProductsProvider);
    final suppAsync = ref.watch(allProductsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Select Product',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            labelColor: _green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _green,
            tabs: const [
              Tab(text: 'Feed Products'),
              Tab(text: 'Supplements & Medicines'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _tabCtrl.index == 0
                    ? 'Search by name, brand or code…'
                    : 'Search by name or category…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildFeedList(feedAsync),
                _buildSuppList(suppAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(AsyncValue<List<FeedMasterProduct>> feedAsync) {
    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('Failed to load products',
            style: TextStyle(color: Colors.red.shade400)),
      ),
      data: (all) {
        final items = _filterFeeds(all);
        if (items.isEmpty) return _empty();
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) => _feedTile(items[i]),
        );
      },
    );
  }

  Widget _buildSuppList(AsyncValue<List<ProductMaster>> suppAsync) {
    return suppAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text('Failed to load products',
            style: TextStyle(color: Colors.red.shade400)),
      ),
      data: (all) {
        final items = _filterSupps(all);
        if (items.isEmpty) return _empty();
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) => _suppTile(items[i]),
        );
      },
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No products found',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );

  List<FeedMasterProduct> _filterFeeds(List<FeedMasterProduct> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((p) =>
            p.brand.toLowerCase().contains(q) ||
            p.productName.toLowerCase().contains(q) ||
            (p.productCode?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<ProductMaster> _filterSupps(List<ProductMaster> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((p) =>
            p.productName.toLowerCase().contains(q) ||
            (p.brand?.toLowerCase().contains(q) ?? false) ||
            p.category.toLowerCase().contains(q))
        .toList();
  }

  Widget _feedTile(FeedMasterProduct p) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.grain, size: 20, color: Colors.amber),
      ),
      title: Text(p.productName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          p.brand,
          if (p.productCode != null) 'Code: ${p.productCode}',
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => Navigator.pop(context, p),
    );
  }

  Widget _suppTile(ProductMaster p) {
    final unit = p.unitType?.isNotEmpty == true
        ? p.unitType!
        : (p.baseUnit?.isNotEmpty == true ? p.baseUnit! : null);
    final sub = [
      p.category,
      if (unit != null) unit,
      if (p.form != null) p.form!,
      if (p.packageSize != null && unit != null) '${p.packageSize} $unit',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science_outlined, size: 20, color: Colors.blue),
      ),
      title: Text(p.productName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => Navigator.pop(context, p),
    );
  }
}
