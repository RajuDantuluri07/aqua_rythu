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
import '../../core/utils/uuid_generator.dart';
import '../farm/farm_provider.dart';

const _green = Color(0xFF1B5E20);
const _greenLight = Color(0xFFE8F5E9);
const _bg = Color(0xFFF5F6F3);

String _fmtRupees(double amount) {
  final n = amount.round();
  if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
  // Indian comma: XX,XX,XXX
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

// ── Draft item ────────────────────────────────────────────────────────────────

class _DraftItem {
  final int key;
  FeedMasterProduct? feedProduct;
  ProductMaster? supplementProduct;
  int qty;
  double? unitCost;

  _DraftItem(this.key) : qty = 1;

  bool get hasProduct => feedProduct != null || supplementProduct != null;

  double? get totalCost => unitCost != null ? qty * unitCost! : null;

  String get displayName =>
      feedProduct?.displayName ?? supplementProduct?.displayName ?? '';

  String get productId => feedProduct?.id ?? supplementProduct?.id ?? '';
  String get productType => feedProduct != null ? 'feed' : 'supplement';

  String get packageUnit {
    if (feedProduct != null) return 'kg';
    final sp = supplementProduct;
    if (sp != null) {
      if (sp.unitType?.isNotEmpty == true) return sp.unitType!;
      if (sp.baseUnit?.isNotEmpty == true) return sp.baseUnit!;
    }
    return 'unit';
  }

  double? get packageSize {
    if (feedProduct != null) return feedProduct!.bagWeightKg;
    return supplementProduct?.packageSize;
  }

  double get addedStock {
    final pSize = packageSize;
    return pSize != null ? qty * pSize : qty.toDouble();
  }

  String get unitLabel {
    final form = feedProduct != null ? 'bag' : supplementProduct?.form;
    return switch (form?.toLowerCase()) {
      'bottle' || 'liquid' => qty == 1 ? 'Bottle' : 'Bottles',
      'packet' || 'powder' || 'granule' => qty == 1 ? 'Packet' : 'Packets',
      'bag' => qty == 1 ? 'Bag' : 'Bags',
      'box' => qty == 1 ? 'Box' : 'Boxes',
      'tablet' || 'strip' => qty == 1 ? 'Strip' : 'Strips',
      'bucket' => qty == 1 ? 'Bucket' : 'Buckets',
      _ => qty == 1 ? 'Unit' : 'Units',
    };
  }

  String get subtitle {
    if (feedProduct != null) {
      final f = feedProduct!;
      final parts = <String>[];
      if (f.stage?.isNotEmpty == true) parts.add(f.stage!);
      if (f.bagWeightKg != null) parts.add('${f.bagWeightKg}kg bag');
      return parts.join(' • ');
    }
    if (supplementProduct != null) {
      final s = supplementProduct!;
      final parts = <String>[s.category];
      if (s.packageSize != null) {
        final unit = s.unitType?.isNotEmpty == true
            ? s.unitType!
            : (s.baseUnit?.isNotEmpty == true ? s.baseUnit! : '');
        if (unit.isNotEmpty) {
          final form = s.form?.isNotEmpty == true ? ' ${s.form}' : '';
          parts.add('${s.packageSize}$unit$form');
        }
      }
      return parts.join(' • ');
    }
    return '';
  }

  void setFeedProduct(FeedMasterProduct p) {
    feedProduct = p;
    supplementProduct = null;
    unitCost = p.bagPrice;
  }

  void setSupplementProduct(ProductMaster p) {
    supplementProduct = p;
    feedProduct = null;
    unitCost = p.actualPrice;
  }

  Map<String, dynamic> toEntry(
      String farmId, String userId, DateTime purchaseDate, String batchId) {
    final pSize = packageSize;
    final actualStock = pSize != null ? qty * pSize : qty.toDouble();
    return {
      'farm_id': farmId,
      'user_id': userId,
      'product_id': productId,
      'product_type': productType,
      'quantity_purchased': qty,
      'package_size': pSize,
      'package_unit': packageUnit,
      'actual_stock': actualStock,
      'quantity_unit': packageUnit,
      'purchase_date': DateFormat('yyyy-MM-dd').format(purchaseDate),
      'bag_price': unitCost,
      'total_cost': totalCost,
      'batch_id': batchId,
      'product_name': displayName,
    };
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AddInventoryScreen extends ConsumerStatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  ConsumerState<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends ConsumerState<AddInventoryScreen> {
  final _service = InventoryService();
  final List<_DraftItem> _items = [];
  int _nextKey = 0;
  bool _saving = false;
  DateTime _purchaseDate = DateTime.now();

  bool get _canAdd => _items.isEmpty || _items.last.hasProduct;
  bool get _canSave =>
      !_saving && _items.isNotEmpty && _items.every((i) => i.hasProduct);

  Future<void> _pickAndAdd() async {
    if (!_canAdd) return;
    final result = await showUnifiedProductPickerSheet(context);
    if (result == null || !mounted) return;
    setState(() {
      final item = _DraftItem(_nextKey++);
      if (result is FeedMasterProduct) {
        item.setFeedProduct(result);
      } else if (result is ProductMaster) {
        item.setSupplementProduct(result);
      }
      _items.add(item);
    });
  }

  void _remove(int index) => setState(() => _items.removeAt(index));

  void _setQty(int index, int qty) {
    if (qty < 1) return;
    setState(() => _items[index].qty = qty);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  double? get _totalCost {
    double total = 0;
    bool any = false;
    for (final item in _items) {
      final c = item.totalCost;
      if (c != null) {
        total += c;
        any = true;
      }
    }
    return any ? total : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final farm = ref.read(farmProvider).currentFarm;
      if (user == null || farm == null) throw Exception('Session error');

      final batchId = generateUuidV4();

      final entries = _items
          .map((i) => i.toEntry(farm.id, user.id, _purchaseDate, batchId))
          .toList();

      // 1. Save batch header
      await _service.saveBatch(
        batchId: batchId,
        farmId: farm.id,
        userId: user.id,
        purchaseDate: _purchaseDate,
        totalProducts: _items.length,
        totalCost: _totalCost,
      );

      // 2. Save line items with snapshotted costs
      await _service.createInventoryEntries(entries);

      // 3. Post to expenses for crop cost tracking (best-effort)
      final feedCost = _items
          .where((i) => i.feedProduct != null && i.totalCost != null)
          .fold<double>(0, (s, i) => s + i.totalCost!);
      final suppCost = _items
          .where((i) => i.supplementProduct != null && i.totalCost != null)
          .fold<double>(0, (s, i) => s + i.totalCost!);
      if (feedCost > 0 || suppCost > 0) {
        await _service.recordInventoryExpenses(
          farmId: farm.id,
          userId: user.id,
          purchaseDate: _purchaseDate,
          feedCost: feedCost > 0 ? feedCost : null,
          supplementCost: suppCost > 0 ? suppCost : null,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Inventory Added Successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Inventory save error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Unable to save inventory. Please try again.'),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _summaryText() {
    final count = _items.length;
    if (count == 0) return 'No products added';
    final label = '$count Product${count == 1 ? '' : 's'}';
    final cost = _totalCost;
    if (cost != null && cost > 0) return '$label • ${_fmtRupees(cost)}';
    final feedKg = _items
        .where((i) => i.feedProduct != null)
        .fold<double>(0, (s, i) => s + i.addedStock);
    if (feedKg > 0) {
      final kg = feedKg == feedKg.roundToDouble()
          ? '${feedKg.round()} kg'
          : '${feedKg.toStringAsFixed(1)} kg';
      return '$label • $kg feed';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Add Inventory'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _DateRow(date: _purchaseDate, onTap: _pickDate),
          Expanded(
            child: _items.isEmpty
                ? _EmptyState(onAdd: _pickAndAdd)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (_, i) => _CompactProductRow(
                      key: ValueKey(_items[i].key),
                      item: _items[i],
                      onRemove: () => _remove(i),
                      onQtyChanged: (q) => _setQty(i, q),
                    ),
                  ),
          ),
          if (_items.isNotEmpty)
            _AddMoreButton(enabled: _canAdd, onTap: _pickAndAdd),
          _BottomBar(
            summary: _summaryText(),
            canSave: _canSave,
            saving: _saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

// ── Date Row ──────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('Purchase Date: ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              DateFormat('d MMM yyyy').format(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _green,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No products added yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Search and add inventory items to begin.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add More Button ───────────────────────────────────────────────────────────

class _AddMoreButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _AddMoreButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Another Product'),
        style: TextButton.styleFrom(
          foregroundColor: _green,
          disabledForegroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final String summary;
  final bool canSave;
  final bool saving;
  final VoidCallback onSave;

  const _BottomBar({
    required this.summary,
    required this.canSave,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: canSave ? onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: saving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Saving...',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      )
                    : const Text(
                        'Save Inventory',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact Product Row ───────────────────────────────────────────────────────

class _CompactProductRow extends StatefulWidget {
  final _DraftItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;

  const _CompactProductRow({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
  });

  @override
  State<_CompactProductRow> createState() => _CompactProductRowState();
}

class _CompactProductRowState extends State<_CompactProductRow> {
  String get _stockStr {
    final stock = widget.item.addedStock;
    final unit = widget.item.packageUnit;
    final val = stock == stock.roundToDouble()
        ? '${stock.round()}'
        : stock.toStringAsFixed(1);
    return '$val $unit';
  }

  Future<void> _editQty() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _QtyEditDialog(
        initial: widget.item.qty,
        unitLabel: widget.item.unitLabel,
      ),
    );
    if (!mounted) return;
    if (result != null) widget.onQtyChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name + remove
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.close,
                      size: 16, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          // Subtitle: stage • package size
          if (widget.item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              widget.item.subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          // Stepper + added stock
          Row(
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: widget.item.qty > 1
                    ? () => widget.onQtyChanged(widget.item.qty - 1)
                    : null,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _editQty,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 80),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${widget.item.qty} ${widget.item.unitLabel}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _StepBtn(
                icon: Icons.add,
                onTap: () => widget.onQtyChanged(widget.item.qty + 1),
              ),
              const Spacer(),
              Text(
                'Stock: $_stockStr',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Cost display
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.item.totalCost != null)
                Text(
                  _fmtRupees(widget.item.totalCost!),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                )
              else
                Text(
                  'Price unavailable',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Qty Edit Dialog ───────────────────────────────────────────────────────────

class _QtyEditDialog extends StatefulWidget {
  final int initial;
  final String unitLabel;

  const _QtyEditDialog({required this.initial, required this.unitLabel});

  @override
  State<_QtyEditDialog> createState() => _QtyEditDialogState();
}

class _QtyEditDialogState extends State<_QtyEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v != null && v >= 1) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter ${widget.unitLabel}',
          style: const TextStyle(fontSize: 16)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: 'Quantity',
          suffixText: widget.unitLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
              backgroundColor: _green, foregroundColor: Colors.white),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ── Step Button ───────────────────────────────────────────────────────────────

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? _greenLight : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? _green : Colors.grey.shade400,
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
    _tabCtrl.addListener(() => setState(() {
          _query = '';
          _searchCtrl.clear();
        }));
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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              Tab(text: 'Feed'),
              Tab(text: 'Supplements'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _tabCtrl.index == 0
                    ? 'Search feed products…'
                    : 'Search supplements…',
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
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16),
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
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 16),
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
    final sub = <String>[p.brand];
    if (p.stage?.isNotEmpty == true) sub.add(p.stage!);
    if (p.bagWeightKg != null) sub.add('${p.bagWeightKg}kg/bag');

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        sub.join(' · '),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => Navigator.pop(context, p),
    );
  }

  Widget _suppTile(ProductMaster p) {
    final unit = p.unitType?.isNotEmpty == true
        ? p.unitType!
        : (p.baseUnit?.isNotEmpty == true ? p.baseUnit! : null);
    final sub = <String>[p.category];
    if (p.form?.isNotEmpty == true) sub.add(p.form!);
    if (p.packageSize != null && unit != null) {
      sub.add('${p.packageSize}$unit');
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science_outlined,
            size: 20, color: Colors.blue),
      ),
      title: Text(p.productName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        sub.join(' · '),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: () => Navigator.pop(context, p),
    );
  }
}
