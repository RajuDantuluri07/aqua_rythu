import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplement_provider.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final Supplement? supplement;
  final String? pondId;
  const AddSupplementScreen({super.key, this.supplement, this.pondId});

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Toggle State
  SupplementType _selectedType = SupplementType.feedMix;
  String _applyTo = "This Pond";
  SupplementGoal _selectedGoal = SupplementGoal.growthBoost;

  // Common Fields
  final _nameController = TextEditingController();
  final _startDocController = TextEditingController();
  final _endDocController = TextEditingController();
  final _notesController = TextEditingController();

  // Water Mix Fields
  int _selectedFrequency = 7;
  DateTime _selectedDate = DateTime.now();
  final _customRepeatController = TextEditingController();

  // Selection Lists
  final List<String> _selectedFeedingTimes = [];
  WaterMixTime _selectedWaterTime = WaterMixTime.afterFeed;

  // Items
  final List<SupplementItem> _items = [];

  // Item Input Controllers (Temp) – no initial text
  final _itemNameController = TextEditingController();
  final _itemDoseController = TextEditingController();
  final _itemUnitController = TextEditingController();  // 🔧 removed 'ml' default

  @override
  void initState() {
    super.initState();

    // Set initial unit based on selected type (Feed Mix or Water Mix)
    _itemUnitController.text = _selectedType == SupplementType.feedMix ? 'g/kg' : 'kg/acre';

    if (widget.supplement != null) {
      final s = widget.supplement!;
      _selectedType = s.type;
      _selectedGoal = s.goal ?? SupplementGoal.growthBoost;
      _nameController.text = s.name;
      _startDocController.text = s.startDoc.toString();
      _endDocController.text = s.endDoc.toString();
      _items.addAll(s.items);
      _selectedFeedingTimes.addAll(s.feedingTimes);
      _notesController.text = s.notes;

      if (s.type == SupplementType.waterMix) {
        _selectedFrequency = s.frequencyDays ?? 7;
        _selectedWaterTime = s.preferredTime ?? WaterMixTime.afterFeed;
      }

      // For edit mode, set unit based on first item if available
      if (_items.isNotEmpty) {
        _itemUnitController.text = _items.first.unit;
      } else {
        _itemUnitController.text = _selectedType == SupplementType.feedMix ? 'g/kg' : 'kg/acre';
      }
    } else {
      // For new supplement, ensure unit is valid
      _itemUnitController.text = _selectedType == SupplementType.feedMix ? 'g/kg' : 'kg/acre';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDocController.dispose();
    _endDocController.dispose();
    _itemNameController.dispose();
    _notesController.dispose();
    _customRepeatController.dispose();
    _itemDoseController.dispose();
    _itemUnitController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final dose = double.tryParse(_itemDoseController.text);
    final unit = _itemUnitController.text.trim();

    if (name.isEmpty || dose == null || unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid item name and quantity")),
      );
      return;
    }

    setState(() {
      _items.add(SupplementItem(
        name: name,
        quantity: dose,
        unit: unit,
        type: _selectedType == SupplementType.feedMix ? 'feed' : 'water',
        isMandatory: true,
        dosePerKg: 0.0,
      ));
      _itemNameController.clear();
      _itemDoseController.clear();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one mix item")),
      );
      return;
    }

    if (_selectedType == SupplementType.feedMix && _selectedFeedingTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one feeding round")),
      );
      return;
    }

    final newSupplement = Supplement(
      id: widget.supplement?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      startDoc: int.tryParse(_startDocController.text) ?? 1,
      endDoc: int.tryParse(_endDocController.text) ?? 30,
      type: _selectedType,
      goal: _selectedGoal,
      items: List.from(_items),
      
      feedQty: _selectedType == SupplementType.feedMix ? 1.0 : 0.0, 
      feedingTimes: _selectedType == SupplementType.feedMix 
          ? List.from(_selectedFeedingTimes) 
          : [],

      frequencyDays: _selectedType == SupplementType.waterMix ? _selectedFrequency : null,
      preferredTime: _selectedType == SupplementType.waterMix ? _selectedWaterTime : null,
      pondIds: _applyTo == "All Ponds" 
          ? ['ALL'] 
          : (widget.pondId != null ? [widget.pondId!] : (widget.supplement?.pondIds ?? [])),
      date: _selectedType == SupplementType.waterMix ? _selectedDate : null,
      notes: _notesController.text.trim(),
    );

    if (widget.supplement != null) {
      ref.read(supplementProvider.notifier).editSupplement(newSupplement);
    } else {
      ref.read(supplementProvider.notifier).addSupplement(newSupplement);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplement != null ? "Edit Supplement" : "Add Supplement"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. TYPE TOGGLE
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTypeOption(SupplementType.feedMix, "Feed Mix"),
                  _buildTypeOption(SupplementType.waterMix, "Water Mix"),
                ],
              ),
            ),
            AppSpacing.hBase,

            // GOAL SELECTOR
            const Text("What problem are you solving?", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SupplementGoal.values.map((goal) {
                final isSelected = _selectedGoal == goal;
                return ChoiceChip(
                  label: Text(_formatGoal(goal), style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedGoal = goal),
                );
              }).toList(),
            ),
            AppSpacing.hBase,

            // 2. BASIC INFO
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Supplement Name",
                hintText: "e.g. Gut Health Mix / Mineral Mix",
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            AppSpacing.hBase,

            // Apply To selection
            const Text("Apply To", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: ["This Pond", "Multiple", "All Ponds"].map((opt) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(opt, style: const TextStyle(fontSize: 12)),
                    selected: _applyTo == opt,
                    onSelected: (val) => setState(() => _applyTo = opt),
                  ),
                ),
              )).toList(),
            ),
            AppSpacing.hBase,

            // 3. DOC RANGE (Feed Only)
            if (_selectedType == SupplementType.feedMix) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDocController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "DOC From", prefixIcon: Icon(Icons.play_arrow_outlined)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endDocController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "DOC To", prefixIcon: Icon(Icons.stop_outlined)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              AppSpacing.hBase,
              
              const Text("Select Feeding Rounds", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [1, 2, 3, 4].map((round) {
                  final label = "R$round";
                  final isSelected = _selectedFeedingTimes.contains(label);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedFeedingTimes.add(label);
                            } else {
                              _selectedFeedingTimes.remove(label);
                            }
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // 4. DATE & REPEAT (Water Only)
            if (_selectedType == SupplementType.waterMix) ...[
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Start Date", prefixIcon: Icon(Icons.calendar_month_outlined)),
                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                ),
              ),
              AppSpacing.hBase,

              const Text("Frequency", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  _frequencyChip(0, "No Repeat"),
                  _frequencyChip(7, "7 Days"),
                  _frequencyChip(15, "15 Days"),
                  FilterChip(
                    label: const Text("Custom"),
                    selected: ![0, 7, 15].contains(_selectedFrequency),
                    onSelected: (v) => setState(() => _selectedFrequency = 1),
                  ),
                ],
              ),
              if (![0, 7, 15].contains(_selectedFrequency)) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customRepeatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: "Every [__] days"),
                  onChanged: (v) => _selectedFrequency = int.tryParse(v) ?? 1,
                ),
              ],
              AppSpacing.hBase,

              const Text("Apply At Time Slots", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: ["Morning", "Afternoon", "Evening", "Midnight"].map((time) {
                  final isSelected = _selectedFeedingTimes.contains(time);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(time, style: const TextStyle(fontSize: 10)),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedFeedingTimes.add(time);
                            } else {
                              _selectedFeedingTimes.remove(time);
                            }
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              AppSpacing.hBase,

              const Text("Preferred Time", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: WaterMixTime.values.map((time) {
                  final isSelected = _selectedWaterTime == time;
                  return ChoiceChip(
                    label: Text(_formatTime(time)),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedWaterTime = time);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],

            AppSpacing.hBase,

            // 5. MIX ITEMS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mix Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_items.isNotEmpty)
                  Text("${_items.length} items", style: const TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Add Item Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    controller: _itemNameController,
                    decoration: const InputDecoration(hintText: "Mix Item", contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    style: const TextStyle(fontSize: 13),
                    controller: _itemDoseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Qty", contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _itemUnitController.text,
                    style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    items: (_selectedType == SupplementType.feedMix ? ["g/kg", "ml/kg"] : ["kg/acre", "ml/acre", "L/acre", "g/m3"])
                        .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => _itemUnitController.text = v ?? "ml",
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  onPressed: _addItem,
                )
              ],
            ),
            
            const SizedBox(height: 12),
            if (_items.isEmpty)
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 20),
                 child: Center(child: Text("At least 1 item required", style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
               ),

            // List Items
            ..._items.map<Widget>((item) => Card(
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

            AppSpacing.hBase,

            // 6. NOTES
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Notes (Optional)",
                hintText: "Add any special instructions...",
                alignLabelWithHint: true,
              ),
            ),

            AppSpacing.hXl,

            // 7. FOOTER
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rm),
                ),
                child: const Text("SAVE SUPPLEMENT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(SupplementType type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _itemUnitController.text = type == SupplementType.feedMix 
                ? 'g/kg' 
                : 'kg/acre';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
        ),
      ),
    );
  }

  String _formatGoal(SupplementGoal goal) {
    switch (goal) {
      case SupplementGoal.growthBoost: return "Growth Boost";
      case SupplementGoal.diseasePrevention: return "Disease Prevention";
      case SupplementGoal.waterCorrection: return "Water Correction";
      case SupplementGoal.stressRecovery: return "Stress Recovery";
    }
  }

  Widget _frequencyChip(int days, String label) {
    final isSelected = _selectedFrequency == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedFrequency = days),
      checkmarkColor: AppColors.primary,
    );
  }

  String _formatTime(WaterMixTime t) {
    switch (t) {
      case WaterMixTime.morning: return "Morning";
      case WaterMixTime.evening: return "Evening";
      case WaterMixTime.afterFeed: return "After Last Feed";
    }
  }
}