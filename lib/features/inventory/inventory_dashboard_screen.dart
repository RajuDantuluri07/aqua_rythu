import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import 'inventory_setup_screen.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState
    extends ConsumerState<InventoryDashboardScreen> {
  final _inventoryService = InventoryService();
  List<InventoryItem> _items = [];
  bool _isLoading = true;
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

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  List<InventoryItem> get _filteredItems {
    if (_selectedCategory == 'all') return _items;
    return _items.where((i) => i.category == _selectedCategory).toList();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final farm = ref.read(farmProvider).currentFarm;
      if (farm == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final rows = await _inventoryService.getInventoryStock(farm.id);
      if (!mounted) return;
      setState(() {
        _items = rows.map(InventoryItem.fromView).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAddInventory() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const InventorySetupScreen()))
        .then((_) => _loadInventory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
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
          IconButton(
            onPressed: _loadInventory,
            icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCategoryFilter(),
                Expanded(child: _buildBody()),
              ],
            ),
      bottomNavigationBar: _buildAddButton(),
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
                    color:
                        isSelected ? _green : const Color(0xFFDDDDDD),
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

  Widget _buildBody() {
    if (_items.isEmpty) return _buildEmptyState();

    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No items in this category',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _buildItemCard(filtered[i]),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final purchased = item.openingQuantity;
    final used = item.totalUsed;
    final left = item.remainingQuantity.clamp(0.0, double.infinity);

    return Container(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
    return Container(
      width: 1,
      color: const Color(0xFFEEEEEE),
    );
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

  Widget _buildAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _navigateToAddInventory,
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

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
