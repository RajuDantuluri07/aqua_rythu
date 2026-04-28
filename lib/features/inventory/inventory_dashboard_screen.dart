import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import 'add_stock_screen.dart';
import 'adjust_stock_screen.dart';
import 'purchase_history_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInventory();
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

  void _navigateToSetup() {
    Navigator.of(context).pushReplacementNamed('/inventory_setup');
  }

  Future<void> _navigateToAddStock(InventoryItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddStockScreen(item: item)),
    );
    if (result == true && mounted) _loadInventory();
  }

  Future<void> _navigateToAdjustStock(InventoryItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdjustStockScreen(
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          currentStock: item.remainingQuantity,
        ),
      ),
    );
    if (result == true && mounted) _loadInventory();
  }

  void _navigateToHistory(InventoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseHistoryScreen(
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          packLabel: item.packLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadInventory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : _buildList(),
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
                size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            const Text(
              'Set up your inventory',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Track feed and supplies. Feed deducts automatically when you log feeding.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Setup inventory'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final summary = _buildCategorySummary();
    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...summary,
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('All items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ..._items.map(_buildItemCard),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySummary() {
    final byCategory = <String, List<InventoryItem>>{};
    for (final item in _items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }
    const order = ['feed', 'medicine', 'mineral', 'probiotic'];
    final keys = [
      ...order.where(byCategory.containsKey),
      ...byCategory.keys.where((k) => !order.contains(k)),
    ];
    return keys.map((k) => _buildSummaryCard(k, byCategory[k]!)).toList();
  }

  Widget _buildSummaryCard(String category, List<InventoryItem> items) {
    final totalRemaining =
        items.fold<double>(0, (a, b) => a + b.remainingQuantity);
    final totalPacks = items
        .where((i) => i.hasPackTracking && i.remainingPacks != null)
        .fold<double>(0, (a, b) => a + b.remainingPacks!);
    final hasPacks = items.any((i) => i.hasPackTracking);
    final unit = items.first.unit;
    final worst = _worstStatus(items);

    String packsLine;
    if (hasPacks) {
      final label = items.first.packLabel;
      packsLine =
          '${_fmt(totalPacks)} ${totalPacks == 1.0 ? label : '${label}s'} · ${_fmt(totalRemaining)} $unit';
    } else {
      packsLine = '${_fmt(totalRemaining)} $unit';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _categoryColor(category).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_categoryIcon(category),
                  color: _categoryColor(category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryTitle(category),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(packsLine,
                      style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            _statusChip(worst),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final isAutoTrackedFeed = item.category == 'feed' && item.isAutoTracked;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _statusChip(item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.displayRemaining(),
              style: TextStyle(
                fontSize: 15,
                color: _statusColor(item.status),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isAutoTrackedFeed) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.autorenew, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('Auto-deducts on feeding',
                      style: TextStyle(
                          color: Colors.green.shade800, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToAddStock(item),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add stock'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToAdjustStock(item),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Adjust'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _navigateToHistory(item),
                  icon: const Icon(Icons.history),
                  tooltip: 'Purchase history',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(PackStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _statusColor(PackStatus status) {
    switch (status) {
      case PackStatus.good:
        return Colors.green.shade700;
      case PackStatus.low:
        return Colors.orange.shade700;
      case PackStatus.critical:
        return Colors.deepOrange.shade700;
      case PackStatus.negative:
        return Colors.red.shade700;
    }
  }

  PackStatus _worstStatus(List<InventoryItem> items) {
    PackStatus worst = PackStatus.good;
    for (final item in items) {
      if (_severity(item.status) > _severity(worst)) worst = item.status;
    }
    return worst;
  }

  int _severity(PackStatus s) => switch (s) {
        PackStatus.good => 0,
        PackStatus.low => 1,
        PackStatus.critical => 2,
        PackStatus.negative => 3,
      };

  Color _categoryColor(String category) {
    switch (category) {
      case 'feed':
        return Colors.green;
      case 'medicine':
        return Colors.red;
      case 'mineral':
        return Colors.blue;
      case 'probiotic':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'feed':
        return Icons.grass;
      case 'medicine':
        return Icons.medical_services;
      case 'mineral':
        return Icons.science;
      case 'probiotic':
        return Icons.biotech;
      default:
        return Icons.inventory;
    }
  }

  String _categoryTitle(String category) {
    if (category.isEmpty) return 'Other';
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
