import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/inventory_service.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String unit;
  final String packLabel;

  const PurchaseHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.unit,
    this.packLabel = 'pack',
  });

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  final _inventoryService = InventoryService();
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchaseHistory();
  }

  Future<void> _loadPurchaseHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final purchases = await _inventoryService.getPurchaseHistory(widget.itemId);
      if (mounted) {
        setState(() {
          _purchases = purchases;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load purchase history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase History - ${widget.itemName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? _buildEmptyState()
              : _buildPurchaseList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'No purchases yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add stock to see purchase history here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseList() {
    return RefreshIndicator(
      onRefresh: _loadPurchaseHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _purchases.length,
        itemBuilder: (context, index) {
          final purchase = _purchases[index];
          return _buildPurchaseCard(purchase);
        },
      ),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> purchase) {
    final quantity = (purchase['quantity'] as num?)?.toDouble() ?? 0.0;
    final pricePerUnit = (purchase['price_per_unit'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (purchase['total_cost'] as num?)?.toDouble() ?? 0.0;
    final purchaseDate = DateTime.tryParse(purchase['purchase_date'] as String? ?? '');
    final supplierName = purchase['supplier_name'] as String?;
    final invoiceNumber = purchase['invoice_number'] as String?;
    final notes = purchase['notes'] as String?;
    final packs = (purchase['packs'] as num?)?.toDouble();
    final packSizeAtPurchase = (purchase['pack_size_at_purchase'] as num?)?.toDouble();
    final costPerPack = (purchase['cost_per_pack'] as num?)?.toDouble();

    final hasPacks = packs != null && packs > 0 && packSizeAtPurchase != null;
    final packWord = packs == 1.0 ? widget.packLabel : '${widget.packLabel}s';
    final quantityLabel = hasPacks
        ? '${_fmt(packs)} $packWord (${_fmt(quantity)} ${widget.unit})'
        : '${_fmt(quantity)} ${widget.unit}';
    final priceLabel = hasPacks && costPerPack != null
        ? '₹${costPerPack.toStringAsFixed(0)}/${widget.packLabel}'
        : '₹${pricePerUnit.toStringAsFixed(2)}/${widget.unit}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and total cost
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchaseDate != null
                          ? DateFormat('MMM dd, yyyy').format(purchaseDate)
                          : 'Unknown Date',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (supplierName != null && supplierName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        supplierName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${totalCost.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity and price details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Quantity',
                    quantityLabel,
                    Icons.inventory_2,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDetailItem(
                    'Price',
                    priceLabel,
                    Icons.price_check,
                  ),
                ),
              ],
            ),

            // Optional details
            if (invoiceNumber != null && invoiceNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Invoice: $invoiceNumber',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
