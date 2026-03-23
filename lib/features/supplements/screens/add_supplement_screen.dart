import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplement_provider.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final Supplement? supplement;
  const AddSupplementScreen({super.key, this.supplement});

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Toggle State
  SupplementType _selectedType = SupplementType.feedMix;

  // Common Fields
  final _nameController = TextEditingController();
  final _startDocController = TextEditingController();
  final _endDocController = TextEditingController();

  // Water Mix Fields
  int _selectedFrequency = 7;
  WaterMixTime _selectedWaterTime = WaterMixTime.afterFeed;

  // Items
  final List<SupplementItem> _items = [];

  // Item Input Controllers (Temp)
  final _itemNameController = TextEditingController();
  final _itemDoseController = TextEditingController();
  final _itemUnitController = TextEditingController(text: 'ml');

  @override
  void initState() {
    super.initState();
    if (widget.supplement != null) {
      final s = widget.supplement!;
      _selectedType = s.type;
      _nameController.text = s.name;
      _startDocController.text = s.startDoc.toString();
      _endDocController.text = s.endDoc.toString();
      _items.addAll(s.items);

      if (s.type == SupplementType.waterMix) {
        _selectedFrequency = s.frequencyDays ?? 7;
        _selectedWaterTime = s.preferredTime ?? WaterMixTime.afterFeed;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDocController.dispose();
    _endDocController.dispose();
    _itemNameController.dispose();
    _itemDoseController.dispose();
    _itemUnitController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final dose = double.tryParse(_itemDoseController.text);
    final unit = _itemUnitController.text.trim();

    if (name.isEmpty || dose == null || unit.isEmpty) return;

    setState(() {
      _items.add(SupplementItem(name: name, dosePerKg: dose, unit: unit));
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

    final newSupplement = Supplement(
      id: widget.supplement?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      startDoc: int.parse(_startDocController.text),
      endDoc: int.parse(_endDocController.text),
      type: _selectedType,
      items: List.from(_items),
      
      // Feed Mix defaults
      feedQty: _selectedType == SupplementType.feedMix ? 1.0 : 0.0,
      feedingTimes: _selectedType == SupplementType.feedMix 
          ? ['6 AM', '10 AM', '2 PM', '6 PM'] 
          : [],

      // Water Mix Data
      frequencyDays: _selectedType == SupplementType.waterMix ? _selectedFrequency : null,
      preferredTime: _selectedType == SupplementType.waterMix ? _selectedWaterTime : null,
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
    final primaryColor = Theme.of(context).primaryColor;

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
            const SizedBox(height: 24),

            // 2. BASIC INFO
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Supplement Name"),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDocController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Start DOC"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endDocController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "End DOC"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. WATER MIX SPECIFIC
            if (_selectedType == SupplementType.waterMix) ...[
              const Text("Frequency", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _frequencyChip(7, "Every 7 days"),
                  const SizedBox(width: 12),
                  _frequencyChip(15, "Every 15 days"),
                ],
              ),
              const SizedBox(height: 24),

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
                    selectedColor: primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? primaryColor : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // 4. MIX ITEMS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mix Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_items.isNotEmpty)
                  Text("${_items.length} items", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Add Item Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(hintText: "Item Name", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _itemDoseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Dose", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _itemUnitController,
                    decoration: const InputDecoration(hintText: "Unit", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  onPressed: _addItem,
                )
              ],
            ),
            
            const SizedBox(height: 16),
            
            // List Items
            ..._items.map((item) => Card(
              child: ListTile(
                dense: true,
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${item.dosePerKg} ${item.unit}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _items.remove(item)),
                ),
              ),
            )),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text("Save Supplement"),
              ),
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
        onTap: () => setState(() => _selectedType = type),
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

  Widget _frequencyChip(int days, String label) {
    final isSelected = _selectedFrequency == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedFrequency = days),
      checkmarkColor: Theme.of(context).primaryColor,
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