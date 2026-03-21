import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';

class AddPondScreen extends ConsumerStatefulWidget {
  const AddPondScreen({super.key});

  @override
  ConsumerState<AddPondScreen> createState() => _AddPondScreenState();
}

class _AddPondScreenState extends ConsumerState<AddPondScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _seedCountController = TextEditingController();
  final _plSizeController = TextEditingController();
  
  DateTime _stockingDate = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _seedCountController.dispose();
    _plSizeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _stockingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _stockingDate) {
      setState(() {
        _stockingDate = picked;
      });
    }
  }

  void _savePond() {
    if (_formKey.currentState?.validate() ?? false) {
      final farmState = ref.read(farmProvider);
      final currentFarm = farmState.currentFarm;

      if (currentFarm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No Farm Selected")),
        );
        return;
      }

      final area = double.tryParse(_areaController.text) ?? 0.0;
      final seedCount = int.tryParse(_seedCountController.text) ?? 100000;
      final plSize = int.tryParse(_plSizeController.text) ?? 10;

      // 1. Add Pond to Farm
      ref.read(farmProvider.notifier).addPond(
            currentFarm.id,
            _nameController.text.trim(),
            area,
            seedCount: seedCount,
            plSize: plSize,
            stockingDate: _stockingDate,
          );

      // 2. Generate Initial Feed Plan (Optional but good UX)
      // We need the ID of the pond we just created. Since addPond generates ID internally,
      // in a real app we'd return it. For now, we rely on the provider updating.
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pond Added Successfully")),
      );
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Pond")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Pond Name",
                  border: OutlineInputBorder(),
                  hintText: "e.g. Pond 5",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _areaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Area (Acres)",
                  border: OutlineInputBorder(),
                  hintText: "e.g. 2.5",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _seedCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Seed Count",
                  border: OutlineInputBorder(),
                  hintText: "e.g. 100000",
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                title: const Text("Stocking Date"),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_stockingDate)),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () => _selectDate(context),
              ),

              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePond,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1F9D55),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Create Pond"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}