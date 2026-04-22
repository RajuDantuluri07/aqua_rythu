import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'package:intl/intl.dart';

class EditPondScreen extends ConsumerStatefulWidget {
  final String? pondId;
  const EditPondScreen({super.key, this.pondId});

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
        _seedCountController =
            TextEditingController(text: pond.seedCount.toString());
        _plSizeController = TextEditingController(text: pond.plSize.toString());
        _traysController =
            TextEditingController(text: pond.numTrays.toString());
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

  String? _validateArea(String? value) {
    if (value == null || value.isEmpty) {
      return "Area is required";
    }
    final area = double.tryParse(value);
    if (area == null) {
      return "Enter a valid number";
    }
    if (area <= 0) {
      return "Area must be greater than 0";
    }
    if (area > 100) {
      return "Area seems too large. Max: 100 acres";
    }
    return null;
  }

  String? _validateSeedCount(String? value) {
    if (value == null || value.isEmpty) {
      return "Seed count is required";
    }
    final count = int.tryParse(value);
    if (count == null) {
      return "Enter a valid whole number";
    }
    if (count <= 0) {
      return "Seed count must be greater than 0";
    }
    if (count > 10000000) {
      return "Seed count seems too large (max: 10M)";
    }
    return null;
  }

  String? _validatePlSize(String? value) {
    if (value == null || value.isEmpty) {
      return "PL size is required";
    }
    final size = int.tryParse(value);
    if (size == null) {
      return "Enter a valid whole number";
    }
    if (size <= 0) {
      return "PL size must be greater than 0";
    }
    if (size > 50) {
      return "PL size seems too large (typical: 5-30mm)";
    }
    return null;
  }

  String? _validateTrays(String? value) {
    if (value == null || value.isEmpty) {
      return "Number of trays is required";
    }
    final trays = int.tryParse(value);
    if (trays == null) {
      return "Enter a valid whole number";
    }
    if (trays <= 0) {
      return "Must have at least 1 tray";
    }
    if (trays > 100) {
      return "Number of trays seems too large (typical: 1-20)";
    }
    return null;
  }

  void _save(String pondId) {
    if (_formKey.currentState!.validate()) {
      try {
        final seedCount = int.parse(_seedCountController.text);
        final plSize = int.parse(_plSizeController.text);
        final numTrays = int.parse(_traysController.text);

        ref.read(farmProvider.notifier).updatePond(
              pondId: pondId,
              name: _nameController.text,
              area: double.parse(_areaController.text),
              seedCount: seedCount,
              plSize: plSize,
              stockingDate: _stockingDate ?? DateTime.now(),
              numTrays: numTrays,
            );

        // NOTE: Do NOT recreate feed plan on edit. The feed plan is created when the pond
        // is first created, and is updated via sampling data (recalculatePlan).
        // Editing pond details should not wipe out feed history.

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pond updated successfully")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating pond: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deletePond(String pondId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pond?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "This will permanently remove the pond and all its history. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () async {
              if (_farmId != null) {
                try {
                  await ref
                      .read(farmProvider.notifier)
                      .deletePond(_farmId!, pondId);
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Failed to delete pond. Please try again.")),
                    );
                  }
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pond deleted successfully")),
                  );
                }
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
        title: const Text("Edit Pond Details",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                decoration: const InputDecoration(
                    labelText: "Pond Name", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Pond name is required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                    labelText: "Area (Acres)", border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validateArea,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _seedCountController,
                decoration: const InputDecoration(
                    labelText: "Seed Count", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: _validateSeedCount,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _plSizeController,
                decoration: const InputDecoration(
                    labelText: "PL Size (mm)", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: _validatePlSize,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _traysController,
                decoration: const InputDecoration(
                    labelText: "Number of Trays", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: _validateTrays,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Stocking Date",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_stockingDate != null
                    ? DateFormat('dd MMM yyyy').format(_stockingDate!)
                    : "Select Date"),
                trailing: const Icon(Icons.calendar_today_rounded),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _stockingDate ?? DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("SAVE CHANGES",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _deletePond(pondId),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text("DELETE POND",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
