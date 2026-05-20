import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import 'add_inventory_screen.dart';
import 'add_stock_screen.dart';
import 'inventory_provider.dart';

String _fmtRupees(double amount) {
  final n = amount.round();
  if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final buf = StringBuffer();
  for (var i = 0; i < rest.length; i++) {
    if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
    buf.write(rest[i]);
  }
  return '₹$buf,$last3';
}

String _formatPurchaseDate(String dateStr) {
  try {
    final d = DateTime.parse(dateStr);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return dateStr;
  }
}

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState
    extends ConsumerState<InventoryDashboardScreen> {
  static const _green = Color(0xFF1B5E20);
  static const _bg = Color(0xFFF2F4F0);

  void _navigateToSetup(String farmId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddInventoryScreen()))
        .then((_) {
      ref.invalidate(inventoryProvider(farmId));
      ref.invalidate(inventoryBatchesProvider(farmId));
    });
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
    final batchesAsync = ref.watch(inventoryBatchesProvider(farm.id));

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(farm.id),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(e.toString(), farm.id),
        data: (items) => _buildBody(
          items,
          batchesAsync.valueOrNull ?? [],
          farm.id,
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

  Widget _buildBody(
    List<InventoryItem> items,
    List<Map<String, dynamic>> batches,
    String farmId,
  ) {
    if (items.isEmpty && batches.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inventoryProvider(farmId));
        ref.invalidate(inventoryBatchesProvider(farmId));
      },
      child: CustomScrollView(
        slivers: [
          if (items.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Stock Levels',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildItemCard(items[i], farmId),
                  childCount: items.length,
                ),
              ),
            ),
          ],
          if (batches.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Purchase History',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildBatchCard(batches[i], farmId),
                  childCount: batches.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch, String farmId) {
    final dateStr = batch['purchase_date'] as String? ?? '';
    final totalProducts = (batch['total_products'] as num?)?.toInt() ?? 0;
    final totalCost = (batch['total_cost'] as num?)?.toDouble();
    final entries = (batch['entries'] as List).cast<Map<String, dynamic>>();

    // Sum actual bags purchased across all entries for display
    final totalBags = entries.fold<int>(
      0, (sum, e) => sum + ((e['quantity_purchased'] as num?)?.toInt() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // ── Batch header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 15, color: Color(0xFF777777)),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatPurchaseDate(dateStr),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalProducts ${totalProducts == 1 ? 'product' : 'products'} • $totalBags ${totalBags == 1 ? 'bag' : 'bags'} purchased',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (totalCost != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtRupees(totalCost),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _green,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'total cost',
                        style: TextStyle(fontSize: 10, color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Color(0xFF777777), size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _showEditBatchSheet(batch, farmId);
                    if (value == 'delete') _showDeleteBatchDialog(batch, farmId);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: Color(0xFF333333)),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFC62828)),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Color(0xFFC62828))),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            // ── Column header row ────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      'Product',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAAAAAA),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      'Qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAAAAAA),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      'Per Bag',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAAAAAA),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Total',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAAAAAA),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Divider ──────────────────────────────────────────────────────
            const Divider(height: 1, indent: 14, endIndent: 14,
                color: Color(0xFFEEEEEE)),
            const SizedBox(height: 2),
            // ── Product rows ─────────────────────────────────────────────────
            ...entries.asMap().entries.map((e) =>
                _buildEntryRow(e.value, isLast: e.key == entries.length - 1)),
            const SizedBox(height: 4),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEntryRow(Map<String, dynamic> entry, {bool isLast = false}) {
    final name = (entry['product_name'] as String?)?.isNotEmpty == true
        ? entry['product_name'] as String
        : (entry['product_type'] as String? ?? 'Product');
    final qty = (entry['quantity_purchased'] as num?)?.toInt() ?? 0;
    final bagPrice = (entry['bag_price'] as num?)?.toDouble();
    final totalCost = (entry['total_cost'] as num?)?.toDouble();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$qty',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  bagPrice != null ? _fmtRupees(bagPrice) : '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  totalCost != null ? _fmtRupees(totalCost) : '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 14, endIndent: 14,
              color: Color(0xFFF2F2F2)),
      ],
    );
  }

  // ── Batch delete ────────────────────────────────────────────────────────────

  void _showDeleteBatchDialog(Map<String, dynamic> batch, String farmId) {
    final date = _formatPurchaseDate(batch['purchase_date'] as String? ?? '');
    final totalProducts = (batch['total_products'] as num?)?.toInt() ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Batch'),
        content: Text(
          'Delete the $date batch ($totalProducts ${totalProducts == 1 ? 'product' : 'products'})? '
          'This cannot be undone.',
        ),
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
                await InventoryService().deleteBatch(batch['id'] as String);
                ref.invalidate(inventoryBatchesProvider(farmId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch deleted')),
                  );
                }
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

  // ── Batch edit ──────────────────────────────────────────────────────────────

  void _showEditBatchSheet(Map<String, dynamic> batch, String farmId) {
    final entries =
        List<Map<String, dynamic>>.from(batch['entries'] as List);
    DateTime purchaseDate =
        DateTime.tryParse(batch['purchase_date'] as String? ?? '') ??
            DateTime.now();

    // Mutable local state per entry: qty and bag_price
    final qtys = <String, int>{
      for (final e in entries)
        e['id'] as String: (e['quantity_purchased'] as num?)?.toInt() ?? 1,
    };
    final prices = <String, String>{
      for (final e in entries)
        e['id'] as String:
            (e['bag_price'] as num?)?.toStringAsFixed(0) ?? '',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Handle ──────────────────────────────────────────────
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // ── Title + date picker ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        const Text(
                          'Edit Batch',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: purchaseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setSheetState(() => purchaseDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 13, color: Color(0xFF3A5A3A)),
                                const SizedBox(width: 5),
                                Text(
                                  _formatPurchaseDate(purchaseDate
                                      .toIso8601String()
                                      .split('T')[0]),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  // ── Column headers ───────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text('Product',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFAAAAAA),
                                  letterSpacing: 0.4)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text('Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFAAAAAA),
                                  letterSpacing: 0.4)),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text('Price/Bag (₹)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFAAAAAA),
                                  letterSpacing: 0.4)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  // ── Entry rows ───────────────────────────────────────────
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: Color(0xFFF2F2F2)),
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        final id = e['id'] as String;
                        final name =
                            (e['product_name'] as String?)?.isNotEmpty == true
                                ? e['product_name'] as String
                                : (e['product_type'] as String? ?? 'Product');

                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Row(
                            children: [
                              // Product name
                              Expanded(
                                flex: 5,
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF222222),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Qty stepper
                              SizedBox(
                                width: 90,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final cur = qtys[id] ?? 1;
                                        if (cur > 1) {
                                          setSheetState(
                                              () => qtys[id] = cur - 1);
                                        }
                                      },
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color:
                                                  const Color(0xFFDDDDDD)),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.remove,
                                            size: 14,
                                            color: Color(0xFF555555)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${qtys[id] ?? 1}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        final cur = qtys[id] ?? 1;
                                        setSheetState(
                                            () => qtys[id] = cur + 1);
                                      },
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color:
                                                  const Color(0xFFDDDDDD)),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.add,
                                            size: 14,
                                            color: Color(0xFF555555)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Price field
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 6),
                                    border: OutlineInputBorder(),
                                    hintText: '—',
                                  ),
                                  controller: TextEditingController(
                                      text: prices[id] ?? '')
                                    ..selection =
                                        TextSelection.collapsed(
                                            offset:
                                                (prices[id] ?? '').length),
                                  onChanged: (v) => prices[id] = v,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  // ── Save button ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final updatedEntries = entries.map((e) {
                              final id = e['id'] as String;
                              final qty = qtys[id] ?? 1;
                              final priceStr = (prices[id] ?? '').trim();
                              final bagPrice = priceStr.isNotEmpty
                                  ? double.tryParse(priceStr)
                                  : (e['bag_price'] as num?)?.toDouble();
                              final packageSize =
                                  (e['package_size'] as num?)?.toDouble();
                              return {
                                'id': id,
                                'qty': qty,
                                'bag_price': bagPrice,
                                'actual_stock': packageSize != null
                                    ? qty * packageSize
                                    : qty.toDouble(),
                              };
                            }).toList();

                            await InventoryService().updateBatch(
                              batchId: batch['id'] as String,
                              purchaseDate: purchaseDate,
                              entries: updatedEntries,
                            );
                            ref.invalidate(
                                inventoryBatchesProvider(farmId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Batch updated successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to update: $e')),
                              );
                            }
                          }
                        },
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: _statusBadge(item.status),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _infoChip(Icons.straighten_rounded, 'Unit: ${item.unit.isNotEmpty ? item.unit : '—'}'),
                  if (item.hasPackTracking)
                    _infoChip(
                      Icons.inventory_2_outlined,
                      '1 ${item.packLabel} = ${_fmtNum(item.packSize!)} ${item.unit}',
                    ),
                ],
              ),
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

  String _fmtNum(double v) => _fmt(v);

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF4A7A4A)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF3A5A3A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
