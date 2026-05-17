import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product_master.dart';
import '../../../core/models/supplement_schedule.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/repositories/schedule_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../supplement_provider.dart';
import '../widgets/product_picker_sheet.dart';
import 'supplement_item.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final String pondId;
  final String? farmId;
  final Supplement? supplement;

  const AddSupplementScreen({
    super.key,
    required this.pondId,
    this.farmId,
    this.supplement,
  });

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemDoseController = TextEditingController();
  final _notesController = TextEditingController();
  final _scheduleRepo = ScheduleRepository();

  String _selectedUnit = "g/kg";
  ProductMaster? _selectedProduct;

  SupplementType _selectedType = SupplementType.feedMix;
  final List<String> _selectedRounds = [];
  final List<SupplementItem> _items = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.supplement != null;

  @override
  void initState() {
    super.initState();
    final supplement = widget.supplement;
    if (supplement == null) return;

    _selectedType = supplement.type;
    _selectedRounds
      ..clear()
      ..addAll(supplement.feedingTimes);
    _items
      ..clear()
      ..addAll(supplement.items.map((item) => item.copyWith()));
    _startDate = supplement.startDate ?? _startDate;
    _endDate = supplement.endDate ?? _endDate;
    _selectedUnit =
        supplement.items.isNotEmpty ? supplement.items.first.unit : _selectedUnit;
    _notesController.text = supplement.notes;
  }

  @override
  void dispose() {
    _itemDoseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showProductPickerSheet(context);
    if (picked != null) {
      setState(() {
        _selectedProduct = picked;
        _selectedUnit = _selectedType == SupplementType.feedMix ? 'g/kg' : 'ml/liters';
      });
    }
  }

  void _addMixItem() {
    if (_items.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 3 mix items allowed")),
      );
      return;
    }

    final product = _selectedProduct;
    final dose = double.tryParse(_itemDoseController.text.trim());
    if (product == null || dose == null || dose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a product and enter a dose")),
      );
      return;
    }

    setState(() {
      _items.add(
        SupplementItem(
          name: product.productName,
          quantity: dose,
          unit: _selectedUnit,
          type: _selectedType == SupplementType.feedMix ? 'feed' : 'water',
          productId: product.id,
        ),
      );
      _selectedProduct = null;
      _itemDoseController.clear();
    });
  }

  Future<void> _pickDate({
    required DateTime current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one product")),
      );
      return;
    }

    if (_selectedType == SupplementType.feedMix && _selectedRounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one feed round")),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End date must be after start date")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final existingId = widget.supplement?.id;
      final isUpdate = existingId != null && existingId.isNotEmpty;

      final schedule = SupplementSchedule(
        id: existingId ?? '',
        pondId: widget.pondId,
        farmId: widget.farmId,
        productId: _items.isNotEmpty ? _items.first.productId : null,
        productName: _items.isNotEmpty ? _items.first.name : null,
        categoryName: _items.isNotEmpty ? _selectedProduct?.category : null,
        categoryId: null,
        applicationType: _selectedType == SupplementType.feedMix ? 'feed_mix' : 'water_mix',
        startDate: _startDate,
        endDate: _endDate,
        selectedFeedRounds: _selectedType == SupplementType.feedMix
            ? List<String>.from(_selectedRounds)
            : const [],
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        status: 'active',
        createdBy: null,
        createdAt: now,
        updatedAt: now,
      );

      // Edit mode → UPDATE, Create mode → INSERT
      if (isUpdate) {
        await _scheduleRepo.updateSchedule(schedule);
      } else {
        await _scheduleRepo.insertSchedule(schedule);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ref.invalidate(supplementSchedulesProvider(widget.pondId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? "Schedule updated"
                : (_selectedType == SupplementType.feedMix
                    ? "Feed supplement saved"
                    : "Water treatment saved"),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Supplement" : "Add Supplement"),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            // Type toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeOption(SupplementType.feedMix, "Feed Supplement"),
                  _typeOption(SupplementType.waterMix, "Water Treatment"),
                ],
              ),
            ),
            AppSpacing.hBase,
            // Product picker
            const Text("Product", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickProduct,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: "Select product",
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                child: Text(
                  _selectedProduct?.productName ?? "Tap to select product",
                  style: TextStyle(
                    color: _selectedProduct != null
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _itemDoseController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: "Dose"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: "g/kg", child: Text("g/kg")),
                      DropdownMenuItem(value: "ml/liters", child: Text("ml/liters")),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedUnit = value);
                    },
                  ),
                ),
                IconButton(
                  onPressed: _addMixItem,
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._items.map((item) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${item.quantity} ${item.unit}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _items.remove(item)),
                    ),
                  ),
                )),
            AppSpacing.hBase,
            // Date range
            const Text("Start Date & End Date",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(
                      current: _startDate,
                      onPicked: (d) => setState(() => _startDate = d),
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "Start Date"),
                      child: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(
                      current: _endDate,
                      onPicked: (d) => setState(() => _endDate = d),
                    ),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "End Date"),
                      child: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            // Feed rounds (feed mix only)
            if (_selectedType == SupplementType.feedMix) ...[
              AppSpacing.hBase,
              const Text("Feed Rounds",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ["R1", "R2", "R3", "R4"].map((round) {
                  final isSelected = _selectedRounds.contains(round);
                  return FilterChip(
                    label: Text(round),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRounds.add(round);
                        } else {
                          _selectedRounds.remove(round);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            AppSpacing.hBase,
            const Text("Notes (Optional)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Any notes...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            AppSpacing.hXl,
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rm),
                ),
                child: Text(
                  _isSaving
                      ? "SAVING..."
                      : _selectedType == SupplementType.feedMix
                          ? "SAVE SCHEDULE"
                          : "SAVE TREATMENT",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption(SupplementType type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _items.clear();
            _selectedRounds.clear();
            _selectedProduct = null;
            _itemDoseController.clear();
            _selectedUnit = "g/kg";
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
