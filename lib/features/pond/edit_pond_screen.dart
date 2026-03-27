import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class EditPondScreen extends ConsumerStatefulWidget {
  const EditPondScreen({super.key});

  @override
  ConsumerState<EditPondScreen> createState() => _EditPondScreenState();
}

class _EditPondScreenState extends ConsumerState<EditPondScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _areaController;
  late TextEditingController _seedCountController;
  late TextEditingController _plSizeController;
  late TextEditingController _traysController;
  DateTime? _stockingDate;
  String? _farmId;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final pondId = ModalRoute.of(context)!.settings.arguments as String?;
      if (pondId == null) {
        Navigator.pop(context);
        return;
      }

      final farmState = ref.read(farmProvider);
      Pond? pond;
      
      // Search for the pond across all farms
      for (var farm in farmState.farms) {
        for (var p in farm.ponds) {
          if (p.id == pondId) {
            pond = p;
            _farmId = farm.id;
            break;
          }
        }
      }

      if (pond != null) {
        _nameController = TextEditingController(text: pond.name);
        _areaController = TextEditingController(text: pond.area.toString());
        _seedCountController = TextEditingController(text: pond.seedCount.toString());
        _plSizeController = TextEditingController(text: pond.plSize.toString());
        _traysController = TextEditingController(text: pond.numTrays.toString());
        _stockingDate = pond.stockingDate;
      } else {
        Navigator.pop(context);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _seedCountController.dispose();
    _plSizeController.dispose();
    _traysController.dispose();
    super.dispose();
  }

  void _save(String pondId) {
    if (_formKey.currentState!.validate()) {
      final seedCount = int.parse(_seedCountController.text);
      final plSize = int.parse(_plSizeController.text);

      ref.read(farmProvider.notifier).updatePond(
        pondId: pondId,
        name: _nameController.text,
        area: double.parse(_areaController.text),
        seedCount: seedCount,
        plSize: plSize,
        stockingDate: _stockingDate ?? DateTime.now(),
        numTrays: int.parse(_traysController.text),
      );

      // Trigger feed plan recalculation based on new seed count/PL size
      ref.read(feedPlanProvider.notifier).createPlan(
        pondId: pondId,
        seedCount: seedCount,
        plSize: plSize,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pond updated successfully")),
      );
      Navigator.pop(context);
    }
  }

  void _deletePond(String pondId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pond?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove the pond and all its history. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              if (_farmId != null) {
                ref.read(farmProvider.notifier).deletePond(_farmId!, pondId);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to dashboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Pond deleted successfully")),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pondId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Edit Pond Details", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Pond Name", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: "Area (Acres)", border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _seedCountController,
                decoration: const InputDecoration(labelText: "Seed Count", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _plSizeController,
                decoration: const InputDecoration(labelText: "PL Size", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _traysController,
                decoration: const InputDecoration(labelText: "Number of Trays", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Stocking Date", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_stockingDate != null ? DateFormat('dd MMM yyyy').format(_stockingDate!) : "Select Date"),
                trailing: const Icon(Icons.calendar_today_rounded),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _stockingDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _stockingDate = date);
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _save(pondId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deletePond(pondId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text("DELETE POND", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}