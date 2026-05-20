import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/product_master.dart';
import '../../../core/models/supplement_schedule.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/repositories/schedule_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../farm/farm_provider.dart';
import '../supplement_provider.dart';
import '../widgets/product_picker_sheet.dart';
import 'supplement_item.dart';

// Repeat options for water mix scheduling
const _kRepeatOptions = [
  (label: 'Only this time', days: 0),
  (label: 'Every 7 days',   days: 7),
  (label: 'Every 10 days',  days: 10),
  (label: 'Every 15 days',  days: 15),
  (label: 'Every 30 days',  days: 30),
];

// Quantity unit options for inventory hook
const _kQtyUnits = ['g', 'kg', 'ml', 'L'];

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

  String _selectedUnit = 'g/kg';
  ProductMaster? _selectedProduct;

  SupplementType _selectedType = SupplementType.feedMix;
  final List<String> _selectedRounds = [];
  final List<SupplementItem> _items = [];

  // Feed mix date range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Water mix: single application date + repeat + time
  DateTime _waterDate = DateTime.now();
  int _frequencyDays = 0; // 0 = one-time
  TimeOfDay? _scheduledTime;

  // Inventory hook: optional quantity metadata (T3)
  final _quantityController = TextEditingController();
  String _qtyUnit = 'kg';

  // Pond targeting (T4)
  String _targetType = 'current_pond'; // 'current_pond' | 'selected_ponds' | 'all_ponds'
  final Set<String> _selectedPondIds = {};

  bool _isSaving = false;

  bool get _isEditing => widget.supplement != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplement;
    if (s == null) return;

    _selectedType = s.type;
    _selectedRounds
      ..clear()
      ..addAll(s.feedingTimes);
    _items
      ..clear()
      ..addAll(s.items.map((item) => item.copyWith()));

    if (s.type == SupplementType.feedMix) {
      _startDate = s.startDate ?? _startDate;
      _endDate = s.endDate ?? _endDate;
    } else {
      _waterDate = s.date ?? s.startDate ?? _waterDate;
      _frequencyDays = s.frequencyDays ?? 0;
      if (s.waterTime != null && s.waterTime!.isNotEmpty) {
        final parts = s.waterTime!.split(':');
        if (parts.length == 2) {
          _scheduledTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }

    _selectedUnit =
        s.items.isNotEmpty ? s.items.first.unit : _selectedUnit;
    _notesController.text = s.notes;
  }

  @override
  void dispose() {
    _itemDoseController.dispose();
    _notesController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showProductPickerSheet(context);
    if (picked != null) {
      setState(() {
        _selectedProduct = picked;
        _selectedUnit =
            _selectedType == SupplementType.feedMix ? 'g/kg' : 'ml/liters';
      });
    }
  }

  void _addMixItem() {
    if (_items.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 mix items allowed')),
      );
      return;
    }
    final product = _selectedProduct;
    final dose = double.tryParse(_itemDoseController.text.trim());
    if (product == null || dose == null || dose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product and enter a dose')),
      );
      return;
    }
    setState(() {
      _items.add(SupplementItem(
        name: product.productName,
        quantity: dose,
        unit: _selectedUnit,
        type: _selectedType == SupplementType.feedMix ? 'feed' : 'water',
        productId: product.id,
      ));
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

  Future<void> _pickScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _computeEndDate() {
    // One-time: endDate == startDate.
    if (_frequencyDays == 0) return _waterDate;
    // Recurring: sentinel far-future date; stopDate field controls actual end.
    return DateTime(2099, 12, 31);
  }

  // T6: Compute upcoming occurrence dates for the preview strip.
  List<DateTime> _upcomingOccurrences() {
    if (_frequencyDays == 0) return [];
    // Build a temporary schedule purely for calculation — no DB round-trip.
    final temp = SupplementSchedule(
      id: '',
      pondId: '',
      applicationType: 'water_mix',
      startDate: _waterDate,
      endDate: _computeEndDate(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      frequencyDays: _frequencyDays,
    );
    return temp.getUpcomingOccurrences(fromDate: _waterDate, limit: 3);
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }

    if (_selectedType == SupplementType.feedMix && _selectedRounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one feed round')),
      );
      return;
    }

    if (_selectedType == SupplementType.feedMix &&
        _endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final existingId = widget.supplement?.id;
      final isUpdate = existingId != null && existingId.isNotEmpty;

      final isWater = _selectedType == SupplementType.waterMix;

      // Encode every item so all products survive the round-trip.
      // Legacy scalar fields (productId / productName / quantity / unit) keep
      // the first item for backward compatibility with older display code.
      final allProducts = _items
          .map((item) => {
                'productId': item.productId,
                'productName': item.name,
                'quantity': item.quantity,
                'unit': item.unit,
              })
          .toList();

      final schedule = SupplementSchedule(
        id: existingId ?? '',
        pondId: widget.pondId,
        farmId: widget.farmId,
        productId: _items.isNotEmpty ? _items.first.productId : null,
        productName: _items.isNotEmpty ? _items.first.name : null,
        categoryName:
            _items.isNotEmpty ? _selectedProduct?.category : null,
        categoryId: null,
        applicationType: isWater ? 'water_mix' : 'feed_mix',
        startDate: isWater ? _waterDate : _startDate,
        endDate: isWater ? _computeEndDate() : _endDate,
        selectedFeedRounds:
            isWater ? const [] : List<String>.from(_selectedRounds),
        notes:
            _notesController.text.isNotEmpty ? _notesController.text : null,
        status: 'active',
        createdBy: null,
        createdAt: now,
        updatedAt: now,
        scheduledTime:
            isWater && _scheduledTime != null
                ? _formatTimeOfDay(_scheduledTime!)
                : null,
        frequencyDays: isWater ? (_frequencyDays == 0 ? null : _frequencyDays) : null,
        quantity: isWater
            ? double.tryParse(_quantityController.text.trim())
            : null,
        unit: isWater && _quantityController.text.trim().isNotEmpty
            ? _qtyUnit
            : null,
        products: allProducts,
        targetType: _targetType,
        targetPondIds: _targetType == 'selected_ponds'
            ? _selectedPondIds.toList()
            : const [],
      );

      if (isUpdate) {
        await _scheduleRepo.updateSchedule(schedule);
      } else {
        await _scheduleRepo.insertSchedule(schedule);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      ref.invalidate(supplementSchedulesProvider((pondId: widget.pondId, farmId: widget.farmId ?? '')));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUpdate
              ? 'Schedule updated'
              : (isWater ? 'Water treatment saved' : 'Feed supplement saved')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Supplement' : 'Add Supplement'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            // ── Type toggle ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeOption(SupplementType.feedMix, 'Feed Supplement'),
                  _typeOption(SupplementType.waterMix, 'Water Treatment'),
                ],
              ),
            ),
            AppSpacing.hBase,

            // ── Product picker ─────────────────────────────────────────────
            const Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickProduct,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: 'Select product',
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                child: Text(
                  _selectedProduct?.productName ?? 'Tap to select product',
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Dose'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'g/kg', child: Text('g/kg')),
                      DropdownMenuItem(
                          value: 'ml/liters', child: Text('ml/liters')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedUnit = v);
                    },
                  ),
                ),
                IconButton(
                  onPressed: _addMixItem,
                  icon: const Icon(Icons.add_circle,
                      color: Colors.green, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._items.map((item) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(item.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.quantity} ${item.unit}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      onPressed: () =>
                          setState(() => _items.remove(item)),
                    ),
                  ),
                )),
            AppSpacing.hBase,

            // ── Date / schedule section (differs by type) ──────────────────
            if (_selectedType == SupplementType.feedMix) ...[
              const Text('Start Date & End Date',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(
                        current: _startDate,
                        onPicked: (d) =>
                            setState(() => _startDate = d),
                      ),
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Start Date'),
                        child: Text(
                            DateFormat('dd MMM yyyy').format(_startDate)),
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
                        decoration:
                            const InputDecoration(labelText: 'End Date'),
                        child: Text(
                            DateFormat('dd MMM yyyy').format(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── Water mix: date + frequency + time ─────────────────────
              const Text('Application Date',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _pickDate(
                  current: _waterDate,
                  onPicked: (d) => setState(() => _waterDate = d),
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_waterDate),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              AppSpacing.hBase,
              const Text('Repeat Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildFrequencySelector(),
              // T6: Upcoming dates preview (hidden for one-time)
              if (_frequencyDays > 0) _buildUpcomingPreview(),
              AppSpacing.hBase,
              const Text('Application Time',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickScheduledTime,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    hintText: 'Select time',
                    suffixIcon: const Icon(Icons.access_time),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  child: Text(
                    _scheduledTime != null
                        ? _scheduledTime!.format(context)
                        : 'Tap to set application time',
                    style: TextStyle(
                      color: _scheduledTime != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Card appears in the feed timeline at this time',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],

            // ── Quantity for inventory hook (water mix only, optional) ─────
            if (_selectedType == SupplementType.waterMix) ...[
              AppSpacing.hBase,
              const Text('Quantity per Application (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'e.g. 5',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _qtyUnit,
                      decoration: const InputDecoration(),
                      items: _kQtyUnits
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _qtyUnit = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Used for future inventory tracking',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],

            // ── Pond targeting ─────────────────────────────────────────────
            AppSpacing.hBase,
            _buildTargetingSection(),

            // ── Feed rounds (feed mix only) ────────────────────────────────
            if (_selectedType == SupplementType.feedMix) ...[
              AppSpacing.hBase,
              const Text('Feed Rounds',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['R1', 'R2', 'R3', 'R4'].map((round) {
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
            const Text('Notes (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any notes...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.rm),
                ),
                child: Text(
                  _isSaving
                      ? 'SAVING...'
                      : _selectedType == SupplementType.feedMix
                          ? 'SAVE SCHEDULE'
                          : 'SAVE TREATMENT',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // T6: Preview strip — shows next 3 repeat dates so farmer can confirm
  Widget _buildUpcomingPreview() {
    final dates = _upcomingOccurrences();
    if (dates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFF0D9488)),
            const SizedBox(width: 8),
            Text(
              'Will repeat on:  ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            Expanded(
              child: Text(
                dates.map((d) => DateFormat('d MMM').format(d)).join('  ·  '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D9488),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kRepeatOptions.map((opt) {
        final isSelected = _frequencyDays == opt.days;
        return GestureDetector(
          onTap: () => setState(() => _frequencyDays = opt.days),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0D9488)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0D9488)
                    : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTargetingSection() {
    final farmPonds = ref.read(farmProvider).currentFarm?.ponds ?? [];
    // Filter out the current pond — it's always included for current_pond/selected_ponds
    final otherPonds = farmPonds.where((p) => p.id != widget.pondId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Apply To', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Radio options
        _targetRadio('current_pond', 'This Pond Only'),
        if (farmPonds.length > 1) ...[
          _targetRadio('selected_ponds', 'Selected Ponds'),
          _targetRadio('all_ponds', 'All Ponds on Farm'),
        ],
        // Pond multi-select — shown only when 'selected_ponds' is active
        if (_targetType == 'selected_ponds' && otherPonds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select additional ponds:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: otherPonds.map((pond) {
                    final isChecked = _selectedPondIds.contains(pond.id);
                    return FilterChip(
                      label: Text(pond.name),
                      selected: isChecked,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPondIds.add(pond.id);
                          } else {
                            _selectedPondIds.remove(pond.id);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF0D9488).withOpacity(0.15),
                      checkmarkColor: const Color(0xFF0D9488),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isChecked
                            ? const Color(0xFF0D9488)
                            : Colors.grey.shade700,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _targetRadio(String value, String label) {
    return GestureDetector(
      onTap: () => setState(() {
        _targetType = value;
        if (value != 'selected_ponds') _selectedPondIds.clear();
      }),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _targetType,
            activeColor: const Color(0xFF0D9488),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _targetType = v;
                  if (v != 'selected_ponds') _selectedPondIds.clear();
                });
              }
            },
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _targetType == value
                  ? const Color(0xFF0D9488)
                  : Colors.grey.shade700,
              fontWeight: _targetType == value
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
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
            _selectedUnit = 'g/kg';
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
