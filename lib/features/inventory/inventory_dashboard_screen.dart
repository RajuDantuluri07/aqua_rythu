import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import 'add_stock_screen.dart';
import 'inventory_provider.dart';
import 'inventory_setup_screen.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState
    extends ConsumerState<InventoryDashboardScreen> {
  String _selectedCategory = 'all';

  static const _categories = [
    ('all', 'All'),
    ('feed', 'Feed'),
    ('medicine', 'Supplements'),
    ('probiotic', 'Probiotic'),
    ('mineral', 'Mineral'),
  ];

  static const _green = Color(0xFF1B5E20);
  static const _bg = Color(0xFFF2F4F0);

  List<InventoryItem> _filtered(List<InventoryItem> items) {
    if (_selectedCategory == 'all') return items;
    return items.where((i) => i.category == _selectedCategory).toList();
  }

  void _navigateToSetup(String farmId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const InventorySetupScreen()))
        .then((_) => ref.invalidate(inventoryProvider(farmId)));
  }

  void _navigateToAddStock(InventoryItem item, String farmId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AddStockScreen(item: item)))
        .then((updated) {
      if (updated == true) ref.invalidate(inventoryProvider(farmId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final farm = ref.watch(farmProvider).currentFarm;
    if (farm == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar(null),
        body: const Center(child: Text('No farm selected')),
      );
    }

    final inventoryAsync = ref.watch(inventoryProvider(farm.id));

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(farm.id),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(e.toString(), farm.id),
        data: (items) => Column(
          children: [
            _buildCategoryFilter(),
            Expanded(child: _buildBody(items, farm.id)),
          ],
        ),
      ),
      bottomNavigationBar: _buildAddButton(farm.id),
    );
  }

  PreferredSizeWidget _appBar(String? farmId) {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      title: const Text(
        'Inventory Ledger',
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      actions: [
        if (farmId != null)
          IconButton(
            onPressed: () => ref.invalidate(inventoryProvider(farmId)),
            icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
          ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? _green : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _green : const Color(0xFFDDDDDD),
                  ),
                ),
                child: Text(
                  cat.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF555555),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(List<InventoryItem> items, String farmId) {
    if (items.isEmpty) return _buildEmptyState();

    final filtered = _filtered(items);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No items in this category',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inventoryProvider(farmId)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _buildItemCard(filtered[i], farmId),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, String farmId) {
    final purchased = item.openingQuantity;
    final used = item.totalUsed;
    final left = item.remainingQuantity.clamp(0.0, double.infinity);

    return GestureDetector(
      onTap: () => _navigateToAddStock(item, farmId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFF777777), size: 20),
                    onSelected: (value) {
                      if (value == 'edit') _showEditDialog(item, farmId);
                      if (value == 'delete') _showDeleteDialog(item, farmId);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF333333)),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Color(0xFFC62828)),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(color: Color(0xFFC62828))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: _statusBadge(item.status),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _statColumn('Purchased', _fmt(purchased)),
                    _verticalDivider(),
                    _statColumn('Used', _fmt(used)),
                    _verticalDivider(),
                    _statColumn('Left', _fmt(left), isLeft: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(InventoryItem item, String farmId) {
    final nameCtrl = TextEditingController(text: item.name);
    final unitCtrl = TextEditingController(text: item.unit);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Unit (e.g. kg, L)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              Navigator.pop(ctx);
              if (name.isEmpty) return;
              try {
                await InventoryService().updateInventoryItem(
                  item.id,
                  name: name != item.name ? name : null,
                  unit: unit != item.unit ? unit : null,
                );
                ref.invalidate(inventoryProvider(farmId));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            },
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(InventoryItem item, String farmId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
            'Delete "${item.name}" and all its stock history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await InventoryService().deleteInventoryItem(item.id);
                ref.invalidate(inventoryProvider(farmId));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {bool isLeft = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isLeft
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, color: const Color(0xFFEEEEEE));
  }

  Widget _statusBadge(PackStatus status) {
    final (label, color) = switch (status) {
      PackStatus.good => ('In Sync', const Color(0xFF2E7D32)),
      PackStatus.low => ('Low Stock', const Color(0xFFE65100)),
      PackStatus.critical => ('Critical', const Color(0xFFBF360C)),
      PackStatus.negative => ('No Stock', const Color(0xFFC62828)),
    };
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAddButton(String farmId) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToSetup(farmId),
            icon: const Icon(Icons.add_box_outlined, color: Colors.white),
            label: const Text(
              'Add Inventory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No inventory yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Track feed and supplies. Feed deducts automatically when you log feeding.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, String farmId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Failed to load inventory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(inventoryProvider(farmId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
