import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../supplement_provider.dart';
import 'supplement_item.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final String pondId;
  final Supplement? supplement;

  const AddSupplementScreen({
    super.key,
    required this.pondId,
    this.supplement,
  });

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itemDoseController = TextEditingController();
  String _selectedUnit = "g/kg";

  SupplementType _selectedType = SupplementType.feedMix;
  SupplementGoal? _selectedGoal;
  String _applyTo = "This Pond";
  final List<String> _selectedRounds = [];
  final List<SupplementItem> _items = [];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateTime _waterDate = DateTime.now();
  TimeOfDay _waterTime = TimeOfDay.now();
  int _waterFrequency = 0;
  final _customRepeatController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.supplement != null;

  @override
  void initState() {
    super.initState();
    final supplement = widget.supplement;
    if (supplement == null) {
      return;
    }

    _selectedType = supplement.type;
    _selectedGoal = supplement.goal;
    _applyTo = supplement.pondIds.contains('ALL') ? "All Ponds" : "This Pond";
    _selectedRounds
      ..clear()
      ..addAll(supplement.feedingTimes);
    _items
      ..clear()
      ..addAll(supplement.items.map((item) => item.copyWith()));
    _startDate = supplement.startDate ?? _startDate;
    _endDate = supplement.endDate ?? _endDate;
    _waterDate = supplement.date ?? _waterDate;
    _waterFrequency = supplement.frequencyDays ?? 0;
    _selectedUnit =
        supplement.items.isNotEmpty ? supplement.items.first.unit : _selectedUnit;

    final waterTime = supplement.effectiveWaterTime;
    if (waterTime != null && waterTime.contains(':')) {
      final parts = waterTime.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          _waterTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }

    if (_waterFrequency != 0 && _waterFrequency != 7) {
      _customRepeatController.text = _waterFrequency.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemDoseController.dispose();
    _customRepeatController.dispose();
    super.dispose();
  }

  void _addMixItem() {
    if (_items.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 3 mix items allowed")),
      );
      return;
    }

    final name = _nameController.text.trim();
    final dose = double.tryParse(_itemDoseController.text.trim());
    if (name.isEmpty || dose == null || dose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Problem, mix product, and dose are mandatory")),
      );
      return;
    }

    final unit = _selectedUnit;
    setState(() {
      _items.add(
        SupplementItem(
          name: name,
          quantity: dose,
          unit: unit,
          type: _selectedType == SupplementType.feedMix ? 'feed' : 'water',
        ),
      );
      _nameController.clear();
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
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _waterTime,
    );
    if (picked != null) {
      setState(() => _waterTime = picked);
    }
  }

  void _savePlan() {
    if (_isSaving) {
      return;
    }
    if (_selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Problem is mandatory")),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mix details are mandatory")),
      );
      return;
    }
    if (_selectedType == SupplementType.feedMix && _selectedRounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one feed time")),
      );
      return;
    }
    if (_selectedType == SupplementType.feedMix && _endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End date must be after start date")),
      );
      return;
    }
    if (_selectedType == SupplementType.waterMix && _waterFrequency == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid custom repeat days")),
      );
      return;
    }

    final waterTimeString =
        "${_waterTime.hour.toString().padLeft(2, '0')}:${_waterTime.minute.toString().padLeft(2, '0')}";
    setState(() => _isSaving = true);
    final supplement = Supplement(
      id: widget.supplement?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _selectedGoal == null ? "Supplement Mix" : _goalLabel(_selectedGoal!),
      startDoc: widget.supplement?.startDoc ?? 1,
      endDoc: widget.supplement?.endDoc ?? 999,
      startDate: _selectedType == SupplementType.feedMix ? _startDate : null,
      endDate: _selectedType == SupplementType.feedMix ? _endDate : null,
      type: _selectedType,
      goal: _selectedGoal,
      pondIds: _applyTo == "All Ponds" ? ['ALL'] : [widget.pondId],
      feedQty: widget.supplement?.feedQty ?? 1.0,
      feedingTimes: _selectedType == SupplementType.feedMix
          ? List<String>.from(_selectedRounds)
          : const [],
      frequencyDays: _selectedType == SupplementType.waterMix ? _waterFrequency : null,
      date: _selectedType == SupplementType.waterMix ? _waterDate : null,
      waterTime: _selectedType == SupplementType.waterMix ? waterTimeString : null,
      items: List<SupplementItem>.from(_items),
      isPaused: widget.supplement?.isPaused ?? false,
    );

    if (_isEditing) {
      ref.read(supplementProvider.notifier).editSupplement(supplement);
    } else {
      ref.read(supplementProvider.notifier).addSupplement(supplement);
    }
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? "Supplement plan updated"
              : _selectedType == SupplementType.feedMix
                  ? "Feed supplement saved"
                  : "Water mix saved",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBg,
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Supplement" : "Add Supplement"),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeOption(SupplementType.feedMix, "Feed Mix"),
                  _typeOption(SupplementType.waterMix, "Water Mix"),
                ],
              ),
            ),
            AppSpacing.hBase,
            const Text("Problem", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _problemOptions().map((goal) {
                return ChoiceChip(
                  label: Text(_goalLabel(goal)),
                  selected: _selectedGoal == goal,
                  onSelected: (_) => setState(() => _selectedGoal = goal),
                );
              }).toList(),
            ),
            AppSpacing.hBase,
            const Text("Mix Details", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: "Product"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _itemDoseController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: "Dose",
                    ),
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
                      DropdownMenuItem(
                          value: "ml/liters", child: Text("ml/liters")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedUnit = value);
                      }
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
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${item.quantity} ${item.unit}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _items.remove(item)),
                    ),
                  ),
                )),
            if (_selectedType == SupplementType.feedMix) ...[
              AppSpacing.hBase,
              const Text("Start Date & End Date", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(
                        current: _startDate,
                        onPicked: (date) => setState(() => _startDate = date),
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
                        onPicked: (date) => setState(() => _endDate = date),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "End Date"),
                        child: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.hBase,
              const Text("Feed Time", style: TextStyle(fontWeight: FontWeight.bold)),
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
              AppSpacing.hBase,
              const Text("Apply To", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ["This Pond", "All Ponds"].map((opt) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(opt),
                        selected: _applyTo == opt,
                        onSelected: (_) => setState(() => _applyTo = opt),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              AppSpacing.hBase,
              const Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(
                        current: _waterDate,
                        onPicked: (date) => setState(() => _waterDate = date),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "Date"),
                        child: Text(DateFormat('dd MMM yyyy').format(_waterDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: "Time"),
                        child: Text(_waterTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.hBase,
              const Text("Repeat", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _repeatChip(0, "Today only"),
                  _repeatChip(7, "Every 7 days"),
                  _repeatChip(-1, "Custom"),
                ],
              ),
              if (_waterFrequency == -1) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customRepeatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: "Every __ days"),
                  onChanged: (value) {
                    final days = int.tryParse(value);
                    setState(() {
                      _waterFrequency = (days != null && days > 0) ? days : -1;
                    });
                  },
                ),
              ],
              AppSpacing.hBase,
              const Text("Apply To", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ["This Pond", "All Ponds"].map((opt) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(opt),
                        selected: _applyTo == opt,
                        onSelected: (_) => setState(() => _applyTo = opt),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
                      : _isEditing
                          ? "UPDATE PLAN"
                          : _selectedType == SupplementType.feedMix
                              ? "APPLY TO FEED"
                              : "SAVE WATER MIX",
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
            _nameController.clear();
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

  List<SupplementGoal> _problemOptions() {
    return _selectedType == SupplementType.feedMix
        ? const [
            SupplementGoal.growthBoost,
            SupplementGoal.diseasePrevention,
            SupplementGoal.stressRecovery,
          ]
        : const [
            SupplementGoal.waterCorrection,
            SupplementGoal.stressRecovery,
            SupplementGoal.growthBoost,
          ];
  }

  String _goalLabel(SupplementGoal goal) {
    switch (goal) {
      case SupplementGoal.growthBoost:
        return _selectedType == SupplementType.waterMix ? "Mineral" : "Growth";
      case SupplementGoal.diseasePrevention:
        return "Immunity";
      case SupplementGoal.waterCorrection:
        return "Water Quality";
      case SupplementGoal.stressRecovery:
        return "Stress";
    }
  }

  Widget _repeatChip(int days, String label) {
    final selected = (days == -1 && _waterFrequency != 0 && _waterFrequency != 7) ||
        _waterFrequency == days;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _waterFrequency = days;
          if (days != -1) {
            _customRepeatController.clear();
          }
        });
      },
    );
  }
}
