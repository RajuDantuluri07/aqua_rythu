import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/inventory_service.dart';
import '../../features/farm/farm_provider.dart';
import '../../features/pond/pond_dashboard_provider.dart';
import 'add_stock_screen.dart';
import 'purchase_history_screen.dart';
import 'adjust_stock_screen.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState
    extends ConsumerState<InventoryDashboardScreen> {
  final _inventoryService = InventoryService();
  List<Map<String, dynamic>> _inventoryItems = [];
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
      final farmState = ref.read(farmProvider);
      final pondState = ref.read(pondDashboardProvider);

      final selectedFarm = farmState.currentFarm;
      final selectedPondId = pondState.selectedPond;

      if (selectedFarm != null && selectedPondId.isNotEmpty) {
        final items = await _inventoryService.getInventoryStock(
            selectedPondId, selectedFarm.id);
        if (mounted) {
          setState(() {
            _inventoryItems = items;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inventory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToVerifyStock(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => VerifyStockScreen(item: item),
      ),
    )
        .then((_) {
      if (mounted) {
        _loadInventory(); // Reload after verification
      }
    });
  }

  void _navigateToSetup() {
    Navigator.of(context).pushReplacementNamed('/inventory_setup');
  }

  void _navigateToAddStock(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddStockScreen(
          itemId: item['id'],
          itemName: item['name'],
          unit: item['unit'],
        ),
      ),
    )
        .then((result) {
      if (result == true && mounted) {
        _loadInventory(); // Reload after adding stock
      }
    });
  }

  void _navigateToPurchaseHistory(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PurchaseHistoryScreen(
          itemId: item['id'],
          itemName: item['name'],
          unit: item['unit'],
        ),
      ),
    );
  }

  void _navigateToAdjustStock(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AdjustStockScreen(
          itemId: item['id'],
          itemName: item['name'],
          unit: item['unit'],
          currentStock: (item['expected_stock'] as num?)?.toDouble() ?? 0.0,
        ),
      ),
    )
        .then((result) {
      if (result == true && mounted) {
        _loadInventory(); // Reload after adjustment
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Dashboard'),
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
          : _inventoryItems.isEmpty
              ? _buildEmptyState()
              : _buildInventoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber,
              size: 60,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Setup inventory first',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Inventory tracking is required for feed management',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _navigateToSetup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Setup Inventory'),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    return RefreshIndicator(
      onRefresh: _loadInventory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _inventoryItems.length,
        itemBuilder: (context, index) {
          final item = _inventoryItems[index];
          return _buildInventoryCard(item);
        },
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final isFeed = item['category'] == 'feed';
    final isAutoTracked = item['is_auto_tracked'] == true;
    final expectedStock = (item['expected_stock'] as num?)?.toDouble() ?? 0.0;
    final stockStatus = item['stock_status'] as String? ?? 'OK';

    Color statusColor = Colors.green;
    if (stockStatus == 'NEGATIVE') {
      statusColor = Colors.red;
    } else if (stockStatus == 'LOW') {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] as String? ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(item['category'] as String?),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (item['category'] as String? ?? '').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isFeed && isAutoTracked) ...[
              _buildFeedInfo(item, expectedStock, statusColor),
            ] else ...[
              _buildOtherItemInfo(item),
            ],
            const SizedBox(height: 16),
            // Action buttons for feed items
            if (isFeed && isAutoTracked) ...[
              // Primary actions row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToAddStock(item),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add Stock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToAdjustStock(item),
                      icon: const Icon(Icons.tune),
                      label: const Text('Adjust'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Secondary actions row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToPurchaseHistory(item),
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToVerifyStock(item),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Non-feed items
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No tracking available',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedInfo(
      Map<String, dynamic> item, double expectedStock, Color statusColor) {
    final openingQuantity =
        (item['opening_quantity'] as num?)?.toDouble() ?? 0.0;
    final totalUsed = (item['total_used'] as num?)?.toDouble() ?? 0.0;
    final isNegative = item['is_negative'] == true;
    final verificationOverdue = item['verification_overdue'] == true;
    final latestVerification = item['latest_verification'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Low stock alert
        if (expectedStock <= 20.0) ...[
          _buildStatusAlert(
            expectedStock <= 0
                ? '⚠️ NO STOCK — inventory mismatch'
                : '⚠️ Low feed stock — refill soon',
            expectedStock <= 0 ? Colors.red : Colors.orange,
            expectedStock <= 0 ? Icons.error : Icons.warning,
          ),
          const SizedBox(height: 8),
        ],

        // Stock info cards
        Row(
          children: [
            _buildInfoCard(
                'Current Stock', expectedStock.toStringAsFixed(1), statusColor),
            const SizedBox(width: 8),
            _buildInfoCard('Today Usage', 'Loading...', Colors.blue),
            const SizedBox(width: 8),
            _buildInfoCard('Last Added', 'Loading...', Colors.green),
          ],
        ),
        const SizedBox(height: 8),

        // Additional info row
        Row(
          children: [
            Expanded(
              child: _buildDetailCard('Total Used',
                  '${totalUsed.toStringAsFixed(1)} ${item['unit']}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDetailCard('Opening Stock',
                  '${openingQuantity.toStringAsFixed(1)} ${item['unit']}'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Status indicators
        if (isNegative) ...[
          _buildStatusAlert('NEGATIVE STOCK', Colors.red, Icons.warning),
        ] else if (verificationOverdue) ...[
          _buildStatusAlert(
              'Please verify stock', Colors.orange, Icons.schedule),
        ] else if (latestVerification == null) ...[
          _buildStatusAlert(
              'Please verify stock', Colors.blue, Icons.check_circle_outline),
        ],

        // Auto-tracking indicator
        Row(
          children: [
            Icon(Icons.info_outline, color: statusColor, size: 16),
            const SizedBox(width: 4),
            Text(
              'Auto-tracked via feeding',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Stock mismatch visibility
        if (item['last_verified_quantity'] != null) ...[
          _buildStockMismatchInfo(item),
          const SizedBox(height: 8),
        ],

        // Feed cost display
        _buildFeedCostInfo(item['id']),
        const SizedBox(height: 8),

        // Last action tracking
        _buildLastActionInfo(item),
        const SizedBox(height: 8),

        // Load additional data asynchronously
        _loadAdditionalInfo(item['id']),
      ],
    );
  }

  Widget _loadAdditionalInfo(String itemId) {
    return FutureBuilder(
      future: Future.wait([
        _inventoryService.getTodayUsage(itemId),
        _inventoryService.getLastPurchase(itemId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final todayUsage = snapshot.data![0] as double;
          final lastPurchase = snapshot.data![1] as Map<String, dynamic>?;

          return Column(
            children: [
              if (lastPurchase != null) ...[
                _buildLastPurchaseInfo(lastPurchase),
                const SizedBox(height: 8),
              ],
              // Today's usage info
              if (todayUsage > 0) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Today used: ${todayUsage.toStringAsFixed(1)}kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastPurchaseInfo(Map<String, dynamic> purchase) {
    final quantity = (purchase['quantity'] as num?)?.toDouble() ?? 0.0;
    final pricePerUnit =
        (purchase['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final purchaseDate =
        DateTime.tryParse(purchase['purchase_date'] as String? ?? '');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last: Bought ${quantity.toStringAsFixed(1)}kg @ ₹${pricePerUnit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (purchaseDate != null)
            Text(
              '${purchaseDate.day}/${purchaseDate.month}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusAlert(String message, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherItemInfo(Map<String, dynamic> item) {
    final openingQuantity =
        (item['opening_quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = item['unit'] as String? ?? '';

    return Row(
      children: [
        Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
        const SizedBox(width: 4),
        Text(
          'Available: ${openingQuantity.toStringAsFixed(1)} $unit',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, [Color? valueColor]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'feed':
        return Colors.green;
      case 'medicine':
        return Colors.red;
      case 'equipment':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStockMismatchInfo(Map<String, dynamic> item) {
    final expectedStock = (item['expected_stock'] as num?)?.toDouble() ?? 0.0;
    final lastVerified = (item['last_verified_quantity'] as num?)?.toDouble();
    final difference = (item['stock_difference'] as num?)?.toDouble() ?? 0.0;

    if (lastVerified == null) return const SizedBox.shrink();

    Color diffColor = Colors.black;
    if (difference.abs() > 2) {
      diffColor = difference > 0 ? Colors.green : Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Mismatch',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected: ${expectedStock.toStringAsFixed(1)}'),
              Text('Actual: ${lastVerified.toStringAsFixed(1)}'),
              Text(
                'Diff: ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)}',
                style: TextStyle(color: diffColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCostInfo(String itemId) {
    return FutureBuilder(
      future: _inventoryService.calculateDailyFeedCost(itemId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data! > 0) {
          final cost = snapshot.data!;
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.currency_rupee,
                    color: Colors.green.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Today Cost: ₹${cost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLastActionInfo(Map<String, dynamic> item) {
    final lastActionType = item['last_action_type'] as String?;
    final lastActionDate = item['last_action_date'] as String?;
    final lastActionDetails = item['last_action_details'] as String?;

    if (lastActionType == null || lastActionDate == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 8),
            Text(
              'No recent actions',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    Color actionColor = Colors.blue;
    IconData actionIcon = Icons.history;

    switch (lastActionType) {
      case 'purchase':
        actionColor = Colors.green;
        actionIcon = Icons.shopping_cart;
        break;
      case 'adjustment':
        actionColor = Colors.purple;
        actionIcon = Icons.tune;
        break;
      case 'verification':
        actionColor = Colors.orange;
        actionIcon = Icons.check_circle;
        break;
    }

    final date = DateTime.tryParse(lastActionDate);
    final dateText = date != null
        ? '${date.day}/${date.month}/${date.year % 100}'
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: actionColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(actionIcon, color: actionColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last: ${lastActionType?.toUpperCase() ?? 'ACTION'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: actionColor.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (lastActionDetails != null)
                  Text(
                    lastActionDetails,
                    style: TextStyle(
                      fontSize: 11,
                      color: actionColor.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            dateText,
            style: TextStyle(
              fontSize: 10,
              color: actionColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class VerifyStockScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const VerifyStockScreen({super.key, required this.item});

  @override
  State<VerifyStockScreen> createState() => _VerifyStockScreenState();
}

class _VerifyStockScreenState extends State<VerifyStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualQuantityController = TextEditingController();
  final _inventoryService = InventoryService();
  bool _isLoading = false;

  @override
  void dispose() {
    _actualQuantityController.dispose();
    super.dispose();
  }

  Future<void> _verifyStock() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final actualQuantity =
          double.tryParse(_actualQuantityController.text) ?? 0.0;
      if (actualQuantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid quantity'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      await _inventoryService.verifyInventory(
          widget.item['id'], actualQuantity);

      if (!mounted) return;

      // Calculate and show verification result
      final expectedStock =
          (widget.item['expected_stock'] as num?)?.toDouble() ?? 0.0;
      final difference = actualQuantity - expectedStock;

      String status;
      Color statusColor;
      if (difference < -2) {
        status = 'LOSS';
        statusColor = Colors.red;
      } else if (difference > 2) {
        status = 'EXTRA';
        statusColor = Colors.orange;
      } else {
        status = 'OK';
        statusColor = Colors.green;
      }

      // Show detailed verification result
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Verification Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Expected: ${expectedStock.toStringAsFixed(1)} ${widget.item['unit']}'),
              Text(
                  'Actual: ${actualQuantity.toStringAsFixed(1)} ${widget.item['unit']}'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  border: Border.all(color: statusColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'OK'
                          ? Icons.check_circle
                          : status == 'LOSS'
                              ? Icons.trending_down
                              : Icons.trending_up,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status == 'OK'
                            ? 'Stock matches expected'
                            : status == 'LOSS'
                                ? 'LOSS: ${difference.abs().toStringAsFixed(1)}'
                                : 'EXTRA: ${difference.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close verify screen
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify stock: $e'),
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
  Widget build(BuildContext context) {
    final expectedStock =
        (widget.item['expected_stock'] as num?)?.toDouble() ?? 0.0;
    final unit = widget.item['unit'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify ${widget.item['name']}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected Stock',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${expectedStock.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _actualQuantityController,
                decoration: InputDecoration(
                  labelText: 'Enter actual stock',
                  suffixText: unit,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Actual stock is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify Stock',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
