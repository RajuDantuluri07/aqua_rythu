import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farm/farm_provider.dart';
import '../supplement_provider.dart';

class AddSupplementScreen extends ConsumerStatefulWidget {
  final Supplement? supplement;
  final String? initialPondId;

  const AddSupplementScreen({super.key, this.supplement, this.initialPondId});

  @override
  ConsumerState<AddSupplementScreen> createState() => _AddSupplementScreenState();
}

class _AddSupplementScreenState extends ConsumerState<AddSupplementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Toggle State (Always Feed Mix now)
  final SupplementType _selectedType = SupplementType.feedMix;

  // Common Fields
  final _nameController = TextEditingController();
  final _startDocController = TextEditingController();
  final _endDocController = TextEditingController();

  // Items
  final List<MixItem> _items = [];

  // Pond Selection State
  List<String> _selectedPondIds = ['ALL'];
  String _pondSelectionMode = 'ALL'; // 'THIS', 'MULTIPLE', 'ALL'

  // Item Input Controllers (Temp)
  final _itemNameController = TextEditingController();
  final _itemDoseController = TextEditingController();
  final _itemUnitController = TextEditingController(text: 'ml');

  @override
  void initState() {
    super.initState();
    if (widget.supplement != null) {
      final s = widget.supplement!;
      _nameController.text = s.name;
      _startDocController.text = s.startDoc.toString();
      _endDocController.text = s.endDoc.toString();
      _items.addAll(s.items);
      _selectedPondIds = List.from(s.pondIds);
      
      if (_selectedPondIds.contains('ALL')) {
        _pondSelectionMode = 'ALL';
      } else if (_selectedPondIds.length == 1 && _selectedPondIds.first == widget.initialPondId) {
        _pondSelectionMode = 'THIS';
      } else {
        _pondSelectionMode = 'MULTIPLE';
      }
    } else {
      if (widget.initialPondId != null) {
        _pondSelectionMode = 'THIS';
        _selectedPondIds = [widget.initialPondId!];
      } else {
        _pondSelectionMode = 'ALL';
        _selectedPondIds = ['ALL'];
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
      _items.add(MixItem(name: name, dosePerKg: dose, unit: unit));
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
      feedQty: 1.0,
      feedingTimes: ['6 AM', '10 AM', '2 PM', '6 PM'], 
      
      // Pond Selection
      pondIds: _pondSelectionMode == 'ALL' 
          ? ['ALL'] 
          : (_pondSelectionMode == 'THIS' 
              ? [widget.initialPondId ?? 'Pond 1'] 
              : _selectedPondIds),
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
            const SizedBox(height: 8),

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
            const Text("Apply to Ponds", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _pondModeChip('THIS', "This Pond"),
                const SizedBox(width: 8),
                _pondModeChip('MULTIPLE', "Multiple"),
                const SizedBox(width: 8),
                _pondModeChip('ALL', "All Ponds"),
              ],
            ),
            
            if (_pondSelectionMode == 'MULTIPLE') ...[
              const SizedBox(height: 12),
              _buildPondSelector(),
            ],

            const SizedBox(height: 24),

            const SizedBox(height: 12),

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



  Widget _pondModeChip(String mode, String label) {
    final isSelected = _pondSelectionMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _pondSelectionMode = mode);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPondSelector() {
    final farmState = ref.watch(farmProvider);
    final ponds = farmState.currentFarm?.ponds ?? [];

    return Wrap(
      spacing: 8,
      children: ponds.map((p) {
        final isSelected = _selectedPondIds.contains(p.id);
        return FilterChip(
          label: Text(p.name),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedPondIds.add(p.id);
              } else {
                _selectedPondIds.remove(p.id);
              }
            });
          },
        );
      }).toList(),
    );
  }
}